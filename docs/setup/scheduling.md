# Scheduling the Retry Jobs

The framework's reliability guarantee depends on the three scheduled
jobs being running. Without them, any event that fails its first
synchronous attempt will stay in `ERROR` forever.

See [../reference/scheduling.md](../reference/scheduling.md) for the
mechanics of how cron expressions are generated. This page is the
admin / ops checklist.

## One-time bootstrap

Open **Setup → Developer Console → Debug → Execute Anonymous**, paste:

```apex
JobPendingEvents.start();
JobOldQueuedEvents.start();
JobRetryEventProcessor.start();
```

Run once. Afterwards, verify at **Setup → Scheduled Jobs** — you
should see around 27 new jobs named `JobPendingEvents…`,
`JobOldQueuedEvents…`, `JobRetryEventProcessor…`.

## Running user

The scheduled jobs need **Apex class access** to every class in the
package. Assign the shipped permission set `Event_Queue_Running_User`
to the user who owns the scheduled jobs (the running user is the one
who executed `start()`).

Best practice: create an integration / automation user (licence =
Salesforce Integration if available) and run `start()` while
impersonating them.

## When to re-run `start()`

Call `start()` again if:

- You upgraded the package and the class bodies changed.
- You want to change the interval — first call `abort()` then
  `start()` with a custom interval (see below).
- The scheduled-jobs list is missing entries.

`start()` is idempotent in the sense that each cron-name slot is
unique, but running it twice will create 12 more jobs for
`JobPendingEvents` (they'll fire at the same minute, so you end up
double-processing). **Always `abort()` before re-running `start()`.**

## Changing the interval

`start()` hard-codes the interval. To change it, call the helper
directly:

```apex
// Retry every 3 minutes instead of 8
JobRetryEventProcessor.abort();
new ScheduleHelper()
    .scheduleIntoMinutesInterval(new JobRetryEventProcessor(), 3);
```

Beware: shorter intervals create more cron jobs (60/N), eating into
the org's **100 scheduled Apex** limit.

## Tearing it all down

```apex
JobPendingEvents.abort();
JobOldQueuedEvents.abort();
JobRetryEventProcessor.abort();
```

Each `abort()` uses a `LIKE '<JobName>%'` query, so it matches every
per-minute sibling.

## Monitoring

Query `CronTrigger` for live state:

```apex
for (CronTrigger ct : [
    SELECT CronJobDetail.Name, State, NextFireTime, PreviousFireTime, TimesTriggered
    FROM CronTrigger
    WHERE CronJobDetail.Name LIKE 'Job%'
    ORDER BY NextFireTime ASC
]) {
    System.debug(ct.CronJobDetail.Name + ' | next=' + ct.NextFireTime
              + ' | prev=' + ct.PreviousFireTime
              + ' | runs=' + ct.TimesTriggered);
}
```

Or visit **Setup → Scheduled Jobs**.

## Common setup errors

| Symptom | Likely cause | Fix |
| --- | --- | --- |
| `"You have exceeded the maximum number of scheduled jobs."` | Org at the 100-limit. | `abort()` unused jobs, or schedule at a longer interval. |
| Jobs exist but no events are retried. | `IsRetryDisabled = true` on every errored event. | Inspect the error; business exceptions freeze retries intentionally. |
| Jobs fire but throw `System.UnexpectedException` | Running user missing permission-set assignment. | Assign `Event_Queue_Running_User`. |
| `Unable to abort scheduled job` during package uninstall. | Scheduled jobs still exist. | Run all three `abort()` calls, then retry uninstall. |
