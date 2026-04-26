# Retention — Architecture

Purge engine for `Queue__c`, admin console, and cross-cutting Notifier + Logger infrastructure. Everything ships in three isolated source folders:

```
notifier/    ← AbstractNotifier + NotifierFactory + Notifier_Setting__c     (zero deps)
logger/      ← AbstractLogger + DebugLogger + LoggerFactory + Logger_Setting__c (zero deps)
retention/   ← engine, data model, Admin Console LWCs                       (deps on both)
```

## Flow

```
JobQueueRetention (Schedulable, daily 02:00)
  │
  │ 1. Check Queue_Admin_Setting__c.IsRetentionEnabled__c — else no-op.
  │ 2. QueueRetentionPolicyProvider.getActive() → [policies]
  │ 3. executeBatch(QueueRetentionBatch(first, rest, SCHEDULED, user, 0))
  ▼
QueueRetentionBatch (Batchable, Stateful) — one policy, one log.
  ├─ start(bc):
  │    · open Queue_Purge_Log__c (PARTIAL)
  │    · QueryLocator over Queue__c bounded by policy.RetentionDays__c + MaxDeletePerRun__c
  │    · global-cap check → SKIPPED_GLOBAL_CAP and empty locator if cap reached
  ├─ execute(bc, scope):
  │    · Database.delete(scope, false)                ← Extension seam (§6.7)
  │    · accumulate deleted/skipped counters
  └─ finish(bc):
       · close log with final status (SUCCESS / PARTIAL / ERROR / DRY_RUN / SKIPPED_GLOBAL_CAP)
       · emptyRecycleBin if configured
       · NotifierFactory.createInstance()?.notify(event)
       · chain next policy via executeBatch
```

## Key properties

- **Serial policy execution.** One batch alive at a time. Never contends with the Apex 5-concurrent-batch ceiling regardless of policy count.
- **Per-status uniqueness.** At most one active policy per `Queue__c.Status__c`. Enforced at upsert via `QueueRetentionPolicyProvider.hasActiveConflict(...)`.
- **Default off.** `IsRetentionEnabled__c = false` on deploy. Zero behavior change until the admin explicitly enables.
- **Safe by default.** `EmptyRecycleBin__c = false` — 15-day recovery via Setup → Recycle Bin. `GlobalDryRun__c` freezes the whole purge cycle org-wide.
- **Extensible.**
  - Delete strategy: one well-marked line in `QueueRetentionBatch.execute()` — Phase 2 archive is a single substitution.
  - Notifier: `AbstractNotifier` + `NotificationEvent` — any subsystem (retention today, retry/dispatch tomorrow) emits events to one configured transport.
  - Logger: `AbstractLogger` with shipped `DebugLogger` default; plug in Nebula Logger via `Logger_Setting__c.ClassName__c`.

## Data model

- `Queue_Retention_Policy__mdt` — 6 custom fields (Status, RetentionDays, IsActive, MaxDeletePerRun, DryRun, Notes).
- `Queue_Purge_Log__c` — 14 custom fields + auto-number Name. Snapshot-immutable per run.
- `Queue_Admin_Setting__c` — 5 fields (master switch, global dry-run, global cap, chunk, log retention, recycle-bin toggle).
- `Notifier_Setting__c` / `Logger_Setting__c` — 1 field each (`ClassName__c`), self-contained per their folders.

## Why Batchable (not Queueable chain)

Native chunking via `Database.QueryLocator`. `AsyncApexJob` visibility. No governor gymnastics for policies that match millions of rows. Serial execution sidesteps the 5-concurrent-batch limit; chained `finish()` keeps one policy log per cycle and is an easier mental model than a multi-policy aggregator.

## Why unmanaged / bare names

Retention is shipped in `retention/` as a source-only directory (no `package` key in `sfdx-project.json`). No `async_queue__` prefix is used anywhere — the framework is moving toward unmanaged delivery. `notifier/` and `logger/` are similarly self-contained and can be lifted as drop-ins into other Salesforce projects.
