# Persona: Salesforce Administrator

You're responsible for keeping the Event Queue installed, configured,
and running. You don't typically read Apex, but you control the org's
metadata, permission sets, scheduled jobs, named credentials, and you
are the first port of call when someone says "my transaction didn't
go through".

## Daily / weekly checklist

- [ ] **Scheduled Jobs** (Setup → Scheduled Jobs): confirm you still
      see `JobPendingEvents…`, `JobOldQueuedEvents…`,
      `JobRetryEventProcessor…` running. Missing = no retries happen.
- [ ] **List view `AllToday`** on the Event Queue tab: scan for
      rows in `ERROR` or `UNHANDLED`. Triage via
      [../debugging.md](../debugging.md).
- [ ] **Scheduled job count** (Setup → Scheduled Jobs): stay well
      under the 100-job org limit.

## Things only you can do

### Install / upgrade the package

→ [../setup/installation.md](../setup/installation.md)

Always:

1. Abort scheduled jobs before upgrade.
2. Install / deploy.
3. Assign permission sets to new users.
4. Re-run `start()` for the three jobs.

### Grant access

→ [../setup/permissions.md](../setup/permissions.md)

- Humans: `Event_Queue_Admin`.
- Integration users / running user for the scheduled jobs:
  `Event_Queue_Running_User`.

### Configure a new event type

You won't write the Apex, but you'll often create the
`Event_Configuration__mdt` row once the developer hands you a class
name.

→ [../setup/configuration.md](../setup/configuration.md)

In the UI:

1. **Setup → Custom Metadata Types → Event Configuration →
   Manage Records → New**.
2. Label = DeveloperName = the event type key (e.g.
   `SMS_OUTBOUND_SERVICE`).
3. Fill `CommandClassName__c`, `Method__c`, `NamedCredencial__c`.
4. Save.

Verify by asking someone with Apex access to run:

```apex
EventQueue evt = new EventBuilder().createEventFor('YOUR_TYPE').withPayload('{}').buildAndSave();
```

…and re-query the record after 30 seconds. Status should be
`DELIVERED` (or `ERROR` with a useful message).

### Create Named Credentials

→ [../setup/named-credentials.md](../setup/named-credentials.md)

- One Named Credential per external endpoint.
- DeveloperName must match `Event_Configuration__mdt.NamedCredencial__c`.
- OAuth flows are user-initiated: log in as the running user at
  least once to complete the flow.

### Schedule / unschedule retry jobs

→ [../setup/scheduling.md](../setup/scheduling.md)

From the Developer Console (Execute Anonymous):

```apex
// bootstrap
JobPendingEvents.start();
JobOldQueuedEvents.start();
JobRetryEventProcessor.start();

// teardown (before package uninstall)
JobPendingEvents.abort();
JobOldQueuedEvents.abort();
JobRetryEventProcessor.abort();
```

### Triage failing events

→ [../debugging.md](../debugging.md)

Rule of thumb:

- **`ERROR` + retryable** → let the scheduler handle it; check back
  in 10 minutes.
- **`ERROR` + `IsRetryDisabled=true`** → business failure. Read the
  status message, get it to the right team (usually a developer),
  manually retry once the data is fixed.
- **`UNHANDLED`** → missing / misnamed `Event_Configuration__mdt`
  row. Usually a deploy gap.

### Bulk manual retry

In the **Event Queue → All list view**, select failed rows and use
the `Delete` web link… no, that deletes them. Use this Execute
Anonymous instead:

```apex
List<Queue__c> rows = [SELECT Id FROM Queue__c WHERE Status__c='ERROR' AND CreatedDate=YESTERDAY];
EventExecutor.reprocess(rows);
```

## Things you shouldn't do

- ❌ Delete scheduled jobs manually through the Scheduled Jobs UI —
  use `abort()`. The helper's `LIKE '<name>%'` query makes sure all
  per-minute siblings go too.
- ❌ Edit `Queue__c.Status__c` picklist values without coordinating
  with a developer — Apex code depends on literal strings.
- ❌ Disable history tracking on `Queue__c` fields — support loses
  visibility into retry attempts.
- ❌ Delete the packaged `Event_Configuration__mdt` rows
  (`EventUnitTest`, `EventUnitTestThrowsException`) — they back the
  test suite.

## When to escalate

- Stack trace mentions `NullPointerException` at
  `CommandFactory.createInstanceFor` → developer. The class named in
  configuration doesn't exist.
- `UNHANDLED` events after a deploy that included new event types →
  developer. Missing custom metadata in the deploy package.
- `System.LimitException: Too many future calls` → developer /
  architect. Producer needs to batch differently or use the platform
  event path.
- Scheduled jobs keep disappearing → developer. Something in the org
  is calling `abort()` unexpectedly.
