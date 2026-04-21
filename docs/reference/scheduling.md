# Scheduling Reference

## The three shipped jobs

| Class | Delegate | Default interval | Safety net role |
| --- | --- | --- | --- |
| `JobPendingEvents` | `EventExecutor.processPendingEvents()` | every **5 min** | Re-queues events in `SCHEDULED` status older than 120s. |
| `JobOldQueuedEvents` | `EventExecutor.processOldQueuedEvents()` | every **9 min** | Re-queues events still in `QUEUED` status older than 600s (stuck triggers, governor limits). |
| `JobRetryEventProcessor` | `EventExecutor.processErrorEvents()` | every **8 min** | Re-queues events in `ERROR` status older than 60s, with `RetryCount > 0` and `IsRetryDisabled = false`. |

All three share the same lifecycle:

```apex
ClassName.start();  // schedule every N minutes
ClassName.abort();  // remove all jobs whose name starts with 'ClassName'
```

## What "every N minutes" actually means

`ScheduleHelper.scheduleIntoMinutesInterval(Schedulable, Integer)`
creates **multiple** cron jobs — one per minute slot — rather than
one job that fires every N minutes. For a 5-minute interval, 12 cron
expressions are created:

```
0 00 * * * ?
0 05 * * * ?
0 10 * * * ?
...
0 55 * * * ?
```

This is necessary because Salesforce's cron parser doesn't support
`"*/5"` in the minutes field (outside batch). Each cron expression is
scheduled as a separate `CronTrigger` with a unique job name of the
form:

```
JobClassName + jobCountForTest + <two-digit minute>
```

e.g. `JobRetryEventProcessor008`, `JobRetryEventProcessor016`,
`JobRetryEventProcessor024`, … — **12** jobs in total for a 5-minute
interval (`60 / 5`).

> `jobCountForTest` is a `public static Integer` on each `Job*` class
> that tests bump to avoid name collisions.

## Bootstrapping all three in one go

From the Developer Console (Execute Anonymous):

```apex
JobPendingEvents.start();
JobOldQueuedEvents.start();
JobRetryEventProcessor.start();
```

To tear them all down:

```apex
JobPendingEvents.abort();
JobOldQueuedEvents.abort();
JobRetryEventProcessor.abort();
```

`abort()` uses a `LIKE '<JobName>%'` query, so it removes every cron
whose name starts with the job class name — including the per-minute
siblings.

## Scheduled-Apex org limit

Salesforce limits concurrent scheduled Apex to **100** jobs per org.
The three packaged jobs consume:

- `JobPendingEvents` @ 5 min → 12 jobs
- `JobOldQueuedEvents` @ 9 min → `60 / 9 = 6.67` → 7 jobs
  (actually 7: the helper stops the loop when `i < 60`, so slots 0,
  9, 18, 27, 36, 45, 54)
- `JobRetryEventProcessor` @ 8 min → slots 0, 8, 16, 24, 32, 40,
  48, 56 → 8 jobs

Total: **27 cron triggers** from the packaged scheduler alone. Keep
this in mind when combining with other scheduled classes.

## Custom intervals

`start()` hard-codes the interval per class. To run at a different
cadence, call `ScheduleHelper` directly:

```apex
new ScheduleHelper()
    .scheduleIntoMinutesInterval(new JobRetryEventProcessor(), 15);
```

This creates 4 cron jobs firing at `*:00`, `*:15`, `*:30`, `*:45`.

## Time cutoffs vs. job intervals

There is a subtle interaction between a job's interval and the "age"
cutoff passed to its query:

| Job | Interval | Age cutoff | Practical meaning |
| --- | --- | --- | --- |
| `JobPendingEvents` | 5 min | 120s | Events scheduled >2 min ago are eligible. At 5-min cadence, worst-case delay = 7 min. |
| `JobOldQueuedEvents` | 9 min | 600s | Events queued >10 min ago are eligible. Worst-case delay = 19 min. |
| `JobRetryEventProcessor` | 8 min | 60s | Errored events >1 min old are eligible. Worst-case delay = 9 min. |

All three also cap the batch size at **80** per invocation.

## Observing the schedule

```apex
List<CronTrigger> jobs = [
    SELECT Id, CronJobDetail.Name, NextFireTime
    FROM CronTrigger
    WHERE CronJobDetail.Name LIKE 'Job%'
    ORDER BY CronJobDetail.Name
];
for (CronTrigger ct : jobs) {
    System.debug(ct.CronJobDetail.Name + ' -> ' + ct.NextFireTime);
}
```

Or navigate to **Setup → Scheduled Jobs** in the org.

## Adding a new scheduled job

Mirror the existing pattern:

```apex
global class JobMyMaintenance implements Schedulable {

    public static Integer jobCountForTest = 0;

    global void execute(SchedulableContext sc) {
        // your work
    }

    public static void start() {
        new ScheduleHelper().scheduleIntoMinutesInterval(new JobMyMaintenance(), 15);
    }

    public static void abort() {
        new ScheduleHelper().abort('JobMyMaintenance');
    }
}
```

Guidelines:

- Keep `execute(SchedulableContext)` tiny — delegate to a separate
  class so the logic is unit-testable without invoking the
  scheduler.
- Add CRUD-/FLS-enforced SOQL in the delegated logic, not in the
  Schedulable.
- Don't make callouts directly from a `Schedulable` — enqueue a
  `Queueable` or call `@future`. (All three shipped jobs already do
  this, via `EventExecutor`.)
