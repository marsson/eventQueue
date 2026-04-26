# Proposal: Queue Retention Engine + Queue Admin Console

**Status:** Design complete — 14 decisions locked in. Ready for implementation.
**Author:** (you, drafted with Claude)
**Scope:** Retention engine + Admin Console + framework-wide Notifier/Logger infrastructure for the `async_queue` framework. API 63.0.

## Decisions locked in

| # | Decision | Value |
|---|---|---|
| **D1** | Purge engine | `Database.Batchable`; policies run **serially** (one batch at a time, chained via `finish()`) |
| **D2** | Policy storage | Custom Metadata Type `Queue_Retention_Policy__mdt`; admin edits via `Metadata.Operations.enqueueDeployment` (async) |
| **D3** | Retention granularity | Per-`Status__c` only; at most **one active policy per status** (uniqueness enforced at upsert) |
| **D4** | Delete strategy | **Hard delete** in Phase 1; minimal extension seam (`DeleteStrategy__c` field on log + single-line delete step) for Phase 2 archive |
| **Q2** | Packaging | **Unmanaged / source-only, no namespace prefix anywhere**. Three new isolated source directories — `notifier/`, `logger/`, `retention/` — each a separate non-default entry in `sfdx-project.json` (same shape as the existing `demo/`). Bare names (`Queue__c`, `Event_Queue_Admin`) throughout. Each folder is self-contained (own classes, own custom setting for its config). |
| **D5** | UI surface | New App Page + Tab `Queue_Admin_Console`, added to the `Event_Queue` application's navigation; tab visibility gated by `Event_Queue_Admin` |
| **D6** | Frontend framework | **LWC**. No Aura. |
| **D8** | Permission model | Extend existing `Event_Queue_Admin` + `Event_Queue_Running_User`. No third admin role. |
| **Q3** | Restore action | **None in Phase 1.** Admins use standard Salesforce recycle bin UI during the 15-day window. |
| **D7** | Schedule cadence | **Daily at 02:00** (`0 0 2 * * ?`). Admin can override from the Scheduling tab. |
| **D9** | Notifications | **Pluggable, framework-wide** via `AbstractNotifier` virtual class + `NotifierFactory` (mirrors `AbstractCommand` / `CommandFactory`). Generic — not purge-specific; any subsystem can emit `NotificationEvent` to the one configured notifier. No concrete implementation shipped. Configured via `Queue_Admin_Setting__c.NotifierClassName__c`; blank = silent. |
| **D11** | Logging | **Pluggable, framework-wide** via `AbstractLogger` virtual class + `LoggerFactory`. Ships with `DebugLogger` (wraps `System.debug` with level prefix) as the default when no class is configured. Admin points to `NebulaLogger`-style implementations (user-supplied) via `Queue_Admin_Setting__c.LoggerClassName__c`. |
| **D10** | Recycle bin | **Default OFF.** `EmptyRecycleBin__c = false` — deleted rows retained in recycle bin for the standard 15-day window. Admin flips ON if org's 15M recycle-bin cap becomes a concern. |
| **Q4** | Compliance | No floors, no ceilings, no PII in `EventName__c`, no internal policy doc. Pure operational hygiene. |
| **Q5** | Rollout | **Single PR** shipping everything: engine + Admin Console UI + polish. No phased split. |
**Related:** `docs/improvements.md` #26 (dead-letter / purge concept)

---

## 1. Problem

`Queue__c` is retained forever. Support relies on that for audit, but in orgs with high event volume the table grows without bound and eventually becomes expensive (storage) and slow (list views, reports). There is currently:

- No `Schedulable` that deletes records.
- No metadata/setting that configures retention.
- No UI for admins to manage the framework.
- No separation between "keep for 30 days" (success) and "keep for 1 year" (errors for audit).

## 2. Goals

1. **Configurable retention per `Status__c`** — one active policy per status.
2. **Scalable** — must handle millions of rows without hitting Apex governor limits.
3. **Follows existing patterns** — `Job*` schedulable naming, `ScheduleHelper` registration, `EventQueueActiveRecord`-style caching, `AbstractCommand` / `CommandFactory` plugin pattern, doc placement in `docs/reference/` + `docs/setup/`.
4. **Admin UI** — one SLDS Lightning page (`Queue Admin Console`), tabbed, gated by `Event_Queue_Admin`, that centralizes retention, scheduling, purge history, and framework health.
5. **Safe by default** — feature is **opt-in**. Zero behavior change until an admin enables it. Dry-run supported.
6. **Extensible** — pluggable notifier (D9) + documented delete-strategy seam (D4) so Phase 2 archive / email / Slack / platform-event integrations are clean additive changes, not rewrites.

## 3. Non-goals (this phase)

- Big Object archival (flagged for Phase 2; seam documented in §6.7).
- Real-time streaming dashboards (Phase 2 candidate).
- Concrete notification transport — `AbstractPurgeNotifier` ships with no concrete implementation (implementers provide their own).
- Replacing the Salesforce Setup UI for editing custom metadata — admins can edit `Queue_Retention_Policy__mdt` there or in the Admin Console; both paths go through the same deploy API.

---

## 4. High-level architecture

```
 ┌─────────────────────────────┐        ┌─────────────────────────────┐
 │  Queue Admin Console (LWC)  │───────▶│ QueueAdminController (Apex) │  @AuraEnabled(cacheable=false)
 │  tabs: Overview · Policies  │        │ with-sharing, permission-   │
 │        Scheduling · History │        │ check at entry              │
 │        Settings             │        └──────────────┬──────────────┘
 └─────────────────────────────┘                       │
                                                       ▼
                                       ┌──────────────────────────────┐
                                       │ QueueAdminService (Apex)     │  business logic; no web tier
                                       └──────┬─────────────┬─────────┘
                                              │             │
                                              ▼             ▼
                               ┌──────────────────────┐  ┌──────────────────────┐
                               │ JobQueueRetention    │  │ Queue_Retention_     │
                               │ (Schedulable)        │  │  Policy__mdt         │
                               │  ─ start()/abort()   │  │ Queue_Purge_Log__c   │
                               │  ─ kicks off first   │  │ Queue_Admin_Setting__c│
                               │    batch; chains     │  │                      │
                               │    remaining via     │  │                      │
                               │    finish()          │  │                      │
                               └──────────┬───────────┘  └──────────────────────┘
                                          ▼
                               ┌──────────────────────────┐
                               │ QueueRetentionBatch      │ Database.Batchable
                               │  ─ start(): QueryLocator │  one batch execution
                               │     for one policy       │  per active policy;
                               │  ─ execute(): delete     │  tracked via
                               │  ─ finish(): close log,  │  AsyncApexJob +
                               │    notify(), log(),      │  Queue_Purge_Log__c
                               │    chain next            │
                               └───────┬────────────┬─────┘
                                       │            │
                                       ▼            ▼
                        ┌──────────────────────┐  ┌──────────────────────┐
                        │ NotifierFactory      │  │ LoggerFactory        │
                        │  → AbstractNotifier  │  │  → AbstractLogger    │
                        │  (null if blank)     │  │  (DebugLogger default)│
                        └──────────────────────┘  └──────────────────────┘
                            ▲ framework-wide cross-cutting infra (§6.6)
                            │ implementer-supplied concrete classes
                            │ plug in via Queue_Admin_Setting__c
```

**Three isolated source directories (Q2):**

```
notifier/     ← AbstractNotifier + NotifierFactory + Notifier_Setting__c          (zero dependencies)
logger/       ← AbstractLogger + DebugLogger + LoggerFactory + Logger_Setting__c  (zero dependencies)
retention/    ← engine, data model, Admin Console                                 (depends on notifier, logger, core Queue__c)
```

Each folder is self-contained (classes + custom setting + tests). Deploy order: `notifier/` and `logger/` first (either order), then `retention/`. `force-app/` modifications (perm sets, app nav) happen independently. The folders are listed as separate `packageDirectories` entries in `sfdx-project.json` with no `package` key — same shape as the existing `demo/` directory.

Two guiding principles:

- **Schedulable is the trigger, Batchable is the worker, policies run serially.** `JobQueueRetention.execute()` enqueues the first active policy via `Database.executeBatch(new QueueRetentionBatch(policy), chunkSize)`. When that batch's `finish()` completes, it enqueues the next active policy. One batch alive at a time, one `Queue_Purge_Log__c` per policy per cycle, staying comfortably under the Apex 5-concurrent-batch limit regardless of policy count. Batch handles chunking natively (no governor gymnastics), survives partial failures per chunk, and every run is visible in standard `AsyncApexJob` list alongside the logs we write. This is a new pattern for the codebase — documented in `docs/architecture/retention.md` and cross-linked from `docs/architecture/design-patterns.md`.
- **Policies ship as developer-owned metadata.** Retention rules live in `Queue_Retention_Policy__mdt` alongside `Event_Configuration__mdt`, which means (a) rules are version-controlled and part of the deploy pipeline, (b) admins can still edit them at runtime — either via Setup → Custom Metadata Types or via the Admin Console (both go through `Metadata.Operations.enqueueDeployment`, an async deploy taking 10–60s per save). Runtime state (last-run timestamp, last-run counts) is **not** stored on the MDT (MDT is read-only from Apex DML); it is derived at read time from the most-recent `Queue_Purge_Log__c` per policy.

---

## 5. Data model

### 5.1 `Queue_Retention_Policy__mdt` (new Custom Metadata Type)

One record = one retention rule. Follows the same DeveloperName-keyed pattern as `Event_Configuration__mdt`. Loaded + cached at batch startup (see `EventQueueActiveRecord` cache pattern).

| Field | Type | Required | Purpose |
|-------|------|----------|---------|
| `Label` (standard) | Text(40) | Yes | Human label for Setup UI, e.g. "Delivered events — 30 days" |
| `DeveloperName` (standard) | Text(40) | Yes | Stable key (e.g. `Delivered_30d`) used in logs |
| `Status__c` | Picklist (mirrors `Queue__c.Status__c`) | Yes | Status this rule targets. **Uniqueness:** at most one active policy per status (enforced at upsert — see §6.2). |
| `RetentionDays__c` | Number(4,0) | Yes | Records older than this (based on `CreatedDate`) are eligible for delete |
| `IsActive__c` | Checkbox, default `false` | Yes | Opt-in toggle per rule |
| `MaxDeletePerRun__c` | Number(7,0), default `10000` | Yes | Hard cap per batch execution for this rule (safety) |
| `DryRun__c` | Checkbox, default `false` | Yes | When true, evaluate + log counts but don't DML |
| `Notes__c` | LongTextArea(32000) | No | Free-form admin notes |

**Not stored on the MDT** (MDT is read-only from Apex DML):
- **last-run timestamp / counts / message** — derived on read from `MAX(RunStartedAt__c)` group-by `PolicyDeveloperName__c` in `Queue_Purge_Log__c`.
- **field manageability** is `DeveloperControlled` on every field, matching the `Event_Configuration__mdt` convention. This means admins edit via Setup UI or via the Admin Console (which wraps `Metadata.Operations.enqueueDeployment`) rather than via a list view on the MDT itself.

**Edit path in production:**
1. Admin saves a change in the Admin Console.
2. `QueueAdminController.upsertPolicy(dto)` wraps the change in a `Metadata.CustomMetadata` record, calls `Metadata.Operations.enqueueDeployment(container, callback)` and returns the deployment ID.
3. LWC shows a "deployment queued" state and polls (`getDeploymentStatus(deploymentId)` → wraps `Metadata.DeployResult`) every ~3s.
4. On callback success (typically 15–45s), LWC refreshes the table.

### 5.2 `Queue_Purge_Log__c` (new Custom Object)

Append-only audit of each purge run. Self-retaining (see `Queue_Admin_Setting__c.LogRetentionDays__c`).

| Field | Type | Purpose |
|-------|------|---------|
| `Name` (auto-number) | `PURGE-{00000000}` | — |
| `RunStartedAt__c` | DateTime | — |
| `RunCompletedAt__c` | DateTime | — |
| `DurationSeconds__c` | Number(6,0) | — |
| `PolicyDeveloperName__c` | Text(40), indexed | MDT `DeveloperName` reference (can't be a lookup — MDT isn't lookupable). Used for "group by policy" aggregates. |
| `PolicyLabel__c` | Text(40) | Snapshot of MDT label at run time (MDT may change; log is immutable) |
| `Status__c` | Picklist: SUCCESS, PARTIAL, ERROR, DRY_RUN, SKIPPED_GLOBAL_CAP | — |
| `RecordsEvaluated__c` | Number(9,0) | — |
| `RecordsDeleted__c` | Number(9,0) | — |
| `RecordsSkipped__c` | Number(9,0) | — |
| `ChunkCount__c` | Number(4,0) | How many Queueable chunks fired |
| `ErrorMessage__c` | LongText(32000) | — |
| `TriggeredBy__c` | Picklist: SCHEDULED, MANUAL, DRY_RUN_MANUAL | — |
| `RunByUser__c` | Lookup(User) | — |
| `DeleteStrategy__c` | Text(20), default `HARD_DELETE` | Snapshot of the strategy that ran. Phase 1 is always `HARD_DELETE`. Added now so Phase 2 archive strategies (e.g. `ARCHIVE_AND_DELETE`) can be introduced without a log-schema migration. |

### 5.3 `Queue_Admin_Setting__c` (new Hierarchy Custom Setting)

Runtime toggles — no deploy needed.

| Field | Type | Default | Purpose |
|-------|------|---------|---------|
| `IsRetentionEnabled__c` | Checkbox | `false` | Master kill-switch. When false, `JobQueueRetention.execute()` is a no-op. |
| `GlobalDryRun__c` | Checkbox | `false` | Overrides per-policy `DryRun__c` when true. |
| `MaxRecordsPerRun__c` | Number(7,0) | `50000` | Global cap across all policies per job execution |
| `ChunkSize__c` | Number(5,0) | `2000` | Scope size passed to `Database.executeBatch(...)` — rows per `execute(bc, scope)` call. 2000 is the Apex batch upper limit; lowering reduces per-chunk governor pressure at cost of more `execute` calls. |
| `LogRetentionDays__c` | Number(4,0) | `90` | `Queue_Purge_Log__c` self-prunes after this window |
| `EmptyRecycleBin__c` | Checkbox | `false` | When `false` (default), deleted rows remain in the recycle bin for the standard 15-day window, preserving the ability to recover via Setup → Recycle Bin. When `true`, `Database.emptyRecycleBin()` is called after each chunk to preserve the org-wide 15M recycle-bin limit. Flip ON only at scale. |

Hierarchy means org default + per-user override, useful for a dev enabling dry-run just for themselves in a sandbox.

Notifier and Logger class-name config do **not** live here — they live on their own folder-local custom settings so `notifier/` and `logger/` stay fully self-contained (see §5.5 and §5.6).

### 5.5 `Notifier_Setting__c` (new Hierarchy Custom Setting, lives in `notifier/`)

Self-contained config for the notifier framework. Keeps `notifier/` droppable into any other project.

| Field | Type | Default | Purpose |
|-------|------|---------|---------|
| `ClassName__c` | Text(80) | (blank) | Optional. Fully-qualified Apex class name extending `AbstractNotifier`. Blank = silent. |

### 5.6 `Logger_Setting__c` (new Hierarchy Custom Setting, lives in `logger/`)

Self-contained config for the logger framework.

| Field | Type | Default | Purpose |
|-------|------|---------|---------|
| `ClassName__c` | Text(80) | (blank) | Optional. Fully-qualified Apex class name extending `AbstractLogger`. Blank = fallback to shipped `DebugLogger`. |

### 5.4 No changes to `Queue__c`

We deliberately don't add a `RetentionEligible__c` or similar field. Eligibility is computed by the batch from `Status__c + CreatedDate` against the policy's `RetentionDays__c`. Keeping `Queue__c` untouched means no migration and no formula-field recalc cost.

---

## 6. Retention engine

### 6.1 Components

- **`JobQueueRetention` (`Schedulable`)** — matches the `Job*` pattern exactly (see `JobRetryEventProcessor.cls`). Implements `execute(SchedulableContext)`, `start()`, `abort()`. Entry point:
  1. Check `Queue_Admin_Setting__c.IsRetentionEnabled__c` — if false, return.
  2. Load active `Queue_Retention_Policy__mdt` rules (order irrelevant — uniqueness per status means at most one policy per status, and policies run serially).
  3. Kick off the **first** policy via `Database.executeBatch(new QueueRetentionBatch(firstPolicy, remainingQueue, TriggeredBy.SCHEDULED), chunkSize)`. The remaining policies ride along in the constructor; the batch's `finish()` step enqueues the next one.
- **`QueueRetentionBatch` (`Database.Batchable<sObject>, Database.Stateful`)** — one active instance at a time. Lifecycle:
  - `start(bc)` — opens a `Queue_Purge_Log__c` (status=PARTIAL) for this policy and returns a `Database.QueryLocator` over `Queue__c` filtered by `Status__c = :policy.Status__c AND CreatedDate < :cutoff`, up to the policy's `MaxDeletePerRun__c`.
  - `execute(bc, scope)` — **one well-marked delete step** (§6.7 extension seam): `Database.delete(scope, false)` (or counts-only if `DryRun__c`); then accumulates counters in stateful fields and records per-row failures into `RecordsSkipped__c`.
  - `finish(bc)` — closes the log (SUCCESS / PARTIAL / DRY_RUN / ERROR), calls `Database.emptyRecycleBin(...)` if `EmptyRecycleBin__c` is true, invokes the notifier hook (§6.6), and enqueues the **next policy** in the remaining queue (or exits cleanly if empty).
- **`QueueRetentionPolicyProvider`** — cache + test seam for MDT reads. `getActivePolicies()` returns cached list; `setMock(List)` is `@TestVisible` and used by tests to avoid relying on deployed MDT records. Mirrors the `EventQueueActiveRecord` MDT-cache idiom.
- **`QueueAdminService`** — façade for controller and tests. Methods: `runPolicyNow(developerName, dryRun)`, `previewPolicyMatch(developerName)`, `purgeHistory(filters, limit)`, `queueHealthSnapshot()`, `scheduleStatus()`, `startJob(whitelistName) / abortJob(whitelistName)`.

### 6.2 Policy matching rules

One active policy per `Status__c` — no overlap, no priority, no tie-breaking. A `Queue__c` row is eligible for delete if an active policy exists for its status and `CreatedDate < NOW − RetentionDays`.

Example:
```
Status=DELIVERED, RetentionDays=30   (active)
Status=ERROR,     RetentionDays=365  (active)
Status=INVALID,   RetentionDays=90   (inactive — skipped this cycle)
# No policy for QUEUED / PROCESSING / SCHEDULED → never purged (transient states)
```

**Uniqueness enforcement:** `QueueAdminController.upsertPolicy(dto)` rejects deployment if another active policy already targets the same `Status__c` (returns a validation error before `Metadata.Operations.enqueueDeployment` is called). To change a status's retention, the admin must either (a) deactivate the existing policy first, then create the new one, or (b) edit the existing policy's `RetentionDays__c`. This keeps the model unambiguous and makes the purge query trivial:

```sql
SELECT Id FROM Queue__c
 WHERE Status__c = :policy.Status__c
   AND CreatedDate < :cutoff
 LIMIT :policy.MaxDeletePerRun__c
```

### 6.3 Scheduling

- Default cron: **daily at 02:00**, `0 0 2 * * ?`. Retention isn't time-critical and a nightly drain keeps purge activity out of peak hours.
- A new `ScheduleHelper.scheduleDailyAt(hour, minute, job, name)` helper (parallels the existing `scheduleIntoMinutesInterval`) handles cron generation. Since `ScheduleHelper` is bare-names unmanaged per Q2, we add the method directly to the existing class rather than shipping a retention-local helper — keeps the pattern centralized. If any org still has a managed-package copy of `ScheduleHelper`, retention falls back to a local `RetentionScheduleHelper` in `retention/` (one branch, documented in `docs/setup/retention-configuration.md`).
- Admin console's Scheduling tab exposes "Start", "Abort", "Run now" — admins can abort then re-start with any cron if they need a different cadence.

### 6.4 Safety nets

- **Per-policy cap:** `Queue_Retention_Policy__mdt.MaxDeletePerRun__c` (default 10,000) — enforced via the batch's `QueryLocator` `LIMIT` clause.
- **Global ceiling:** `Queue_Admin_Setting__c.MaxRecordsPerRun__c` (default 50,000) — summed across all policies in one scheduled cycle. Because policies run serially, each batch's `finish()` checks the running total against the global ceiling; if exceeded, remaining policies are **skipped for this cycle** (not run partially) and will run in the next scheduled fire. Skipped policies are recorded with `Status__c = SKIPPED_GLOBAL_CAP` log entries so admins see the throttling.
- Every `delete` call uses `Database.delete(records, false)` so a single bad row doesn't fail the chunk; failures are counted into `RecordsSkipped__c`.
- `Database.emptyRecycleBin` is explicit and opt-in — default OFF (D10). Large delete volumes can otherwise consume the org's 15M recycle-bin allocation; admins flip ON when they hit that ceiling. Default OFF preserves the 15-day recovery window via Setup → Recycle Bin (see Q3 — no first-class restore button, but the Setup UI path still works).
- Dry-run writes to `Queue_Purge_Log__c` with `Status__c = DRY_RUN`, `RecordsDeleted__c = 0`.
- Global dry-run (`Queue_Admin_Setting__c.GlobalDryRun__c = true`) overrides every policy's `DryRun__c` — safe "freeze the whole purge cycle" switch for emergencies.

### 6.5 Attachment cascade

`Queue__c` rows have associated `Attachment` records (processing logs, persisted payloads). Standard `delete` of parent cascades to `Attachment`, which is desired. Worth a note in `docs/setup/retention-configuration.md` so admins understand that **logs are purged with the row**.

### 6.6 Cross-cutting infrastructure: Notifier & Logger

Two framework-wide extension points shipped with retention, both following the existing `ICommand` / `AbstractCommand` + `CommandFactory` pattern. These are **not** retention-specific — they live in `force-app/main/default/classes/` and are reusable by any future subsystem (retention, retry, dispatch, custom extensions).

**Why both live here:** retention is the first subsystem that needs a pluggable notification surface, and the existing codebase has inconsistent logging (ad-hoc `System.debug`, ad-hoc `Attachment` processing logs via `EventQueueFile`). Rather than invent retention-local versions, we introduce proper framework infrastructure now. Retrofitting `EventExecutor`, the existing `Job*` classes, and other core Apex to use `LoggerFactory.getInstance()` is flagged as follow-up work in `docs/improvements.md` — **not** in this PR's scope.

#### 6.6.1 Notifier — `AbstractNotifier` + `NotifierFactory`

**Shared contract** — one method, generic payload:

```apex
public virtual class AbstractNotifier {
    public virtual void notify(NotificationEvent evt) {}
}

public class NotificationEvent {
    public String  source;       // 'PURGE', 'RETRY', 'DISPATCH', … — framework subsystem
    public String  severity;     // 'INFO' | 'WARN' | 'ERROR'
    public String  eventType;    // fine-grained, e.g. 'PURGE_SUCCESS', 'PURGE_SKIPPED_GLOBAL_CAP'
    public String  title;        // one-line summary (email subject / Slack heading)
    public String  message;      // fuller description
    public Map<String, Object> context; // structured payload — recordId, counts, etc.
    public Exception thrown;     // optional
    public Datetime occurredAt;  // auto-set in ctor
    public Id       userId;      // auto-set from UserInfo
}
```

**Factory (`NotifierFactory.cls`, mirrors `CommandFactory`, reads folder-local `Notifier_Setting__c`):**
```apex
public class NotifierFactory {
    public static AbstractNotifier createInstance() {
        Notifier_Setting__c s = Notifier_Setting__c.getOrgDefaults();
        if (s == null || String.isBlank(s.ClassName__c)) return null;  // silent
        Type t = Type.forName(s.ClassName__c);
        if (t == null) return null;
        return (AbstractNotifier) t.newInstance();
    }
    @TestVisible private static AbstractNotifier mock;
    @TestVisible private static void setMock(AbstractNotifier m) { mock = m; }
}
```

**Implementer example** — single Slack notifier handles every source:
```apex
public class SlackNotifier extends AbstractNotifier {
    public override void notify(NotificationEvent evt) {
        if (evt.severity != 'ERROR') return;           // only page on errors
        String webhook = /* pull from NamedCredential / Custom Setting */ 'https://hooks.slack.com/...';
        Http h = new Http();
        HttpRequest req = new HttpRequest();
        req.setEndpoint(webhook);
        req.setMethod('POST');
        req.setBody(JSON.serialize(new Map<String,Object>{
            'text' => '[' + evt.source + '] ' + evt.title,
            'context' => evt.context
        }));
        h.send(req);
    }
}
```

**Purge invocation** — inside `QueueRetentionBatch.finish(bc)`, after the log is closed:
```apex
AbstractNotifier notifier = NotifierFactory.createInstance();
if (notifier != null) {
    NotificationEvent evt = new NotificationEvent();
    evt.source    = 'PURGE';
    evt.severity  = log.Status__c == 'ERROR' ? 'ERROR'
                  : log.Status__c == 'PARTIAL' ? 'WARN' : 'INFO';
    evt.eventType = 'PURGE_' + log.Status__c;           // 'PURGE_SUCCESS', etc.
    evt.title     = 'Queue purge ' + log.Status__c + ' — ' + log.PolicyLabel__c;
    evt.message   = log.RecordsDeleted__c + ' rows deleted; ' + log.RecordsSkipped__c + ' skipped';
    evt.context   = new Map<String,Object>{
        'purgeLogId'           => log.Id,
        'policyDeveloperName'  => log.PolicyDeveloperName__c,
        'recordsEvaluated'     => log.RecordsEvaluated__c,
        'recordsDeleted'       => log.RecordsDeleted__c,
        'recordsSkipped'       => log.RecordsSkipped__c
    };
    evt.thrown    = this.thrownException;
    try { notifier.notify(evt); } catch (Exception e) {
        LoggerFactory.getInstance().error('QueueRetentionBatch', 'notifier failed: ' + e.getMessage(), e);
    }
}
```

**Design principles:**
- **No concrete implementation ships.** No email, no Chatter, no platform event. Implementers choose the transport.
- **Silent by default.** Blank `NotifierClassName__c` → `null` → callers skip.
- **Failures in the notifier do not fail the subsystem.** Every invocation is wrapped in `try/catch`; failures are logged via the Logger infrastructure, never propagated.
- **Admin picks the class name** on the Settings tab. LWC validates `Type.forName` resolves + the class extends `AbstractNotifier` (via `@AuraEnabled` probe) before saving.

#### 6.6.2 Logger — `AbstractLogger` + `LoggerFactory` + shipped `DebugLogger`

**Shared contract** — level-based methods (familiar to Apex and to frameworks like Nebula Logger):

```apex
public virtual class AbstractLogger {
    public virtual void debug (String source, String message) {}
    public virtual void info  (String source, String message) {}
    public virtual void warn  (String source, String message) {}
    public virtual void error (String source, String message, Exception thrown) {}
}
```

`source` = originating class name (e.g. `'QueueRetentionBatch'`, `'EventExecutor'`). Keeps grep/filter ergonomic regardless of transport.

**Shipped default — `DebugLogger`** (concrete, because `System.debug` is the universally acceptable baseline):
```apex
public class DebugLogger extends AbstractLogger {
    public override void debug(String source, String msg)                          { System.debug(LoggingLevel.DEBUG, '[' + source + '] ' + msg); }
    public override void info (String source, String msg)                          { System.debug(LoggingLevel.INFO,  '[' + source + '] ' + msg); }
    public override void warn (String source, String msg)                          { System.debug(LoggingLevel.WARN,  '[' + source + '] ' + msg); }
    public override void error(String source, String msg, Exception thrown)        {
        System.debug(LoggingLevel.ERROR, '[' + source + '] ' + msg + (thrown != null ? ' | ' + thrown.getMessage() + '\n' + thrown.getStackTraceString() : ''));
    }
}
```

**Factory — reads folder-local `Logger_Setting__c`, returns `DebugLogger` if nothing configured:**
```apex
public class LoggerFactory {
    private static AbstractLogger cached;
    public static AbstractLogger getInstance() {
        if (cached != null) return cached;
        Logger_Setting__c s = Logger_Setting__c.getOrgDefaults();
        if (s == null || String.isBlank(s.ClassName__c)) { cached = new DebugLogger(); return cached; }
        Type t = Type.forName(s.ClassName__c);
        if (t == null)                                   { cached = new DebugLogger(); return cached; }
        cached = (AbstractLogger) t.newInstance();
        return cached;
    }
    @TestVisible private static void setMock(AbstractLogger m) { cached = m; }
}
```

**Implementer example** — wrap Nebula Logger:
```apex
public class NebulaLogger extends AbstractLogger {
    public override void info(String source, String msg) {
        Logger.info('[' + source + '] ' + msg);
        Logger.saveLog();
    }
    // … same shape for debug/warn/error
}
```

**Design principles:**
- **Ships with a working default** (`DebugLogger`). Unlike the notifier, logging is never "silent" — the framework always emits something; admins opt into a richer transport if they want.
- **One call always returns a non-null logger** — callers never null-check. Simpler call sites:
  ```apex
  LoggerFactory.getInstance().info('QueueRetentionBatch', 'processed ' + scope.size() + ' rows');
  ```
- **Scope of use in this PR:** retention code (`JobQueueRetention`, `QueueRetentionBatch`, `QueueAdminService`, `QueueRetentionPolicyProvider`, `QueueAdminController`) uses the Logger for all diagnostic output. Existing core code (`EventExecutor`, other `Job*` classes) continues using raw `System.debug` until the follow-up migration PR.
- **Admin picks the class name** on the Settings tab. LWC validates it extends `AbstractLogger` before saving.

### 6.7 Extension seam for future archive strategies (Phase 2-ready)

Phase 1 is **hard delete only**. To keep Phase 2 (e.g. Big Object archive) a clean additive change rather than a rewrite:

- **Single extension point:** `QueueRetentionBatch.execute(bc, scope)` contains exactly one line that performs the delete (`Database.delete(scope, false)`). Phase 2 replaces that line with whatever strategy is introduced (e.g. `archiver.archive(scope); Database.delete(scope, false);`) — no other code in the batch lifecycle changes.
- **Log schema forward-compatible:** `Queue_Purge_Log__c.DeleteStrategy__c` is written on every run with value `HARD_DELETE`. Phase 2 introduces additional values; queries and the Purge History tab filter on this field with no schema migration.
- **MDT forward-compatible:** If Phase 2 needs per-policy strategy choice, one `DeleteStrategy__c` picklist field can be added to `Queue_Retention_Policy__mdt` at that time (MDT supports additive field changes without data migration). We deliberately do **not** add it now — YAGNI — but the log field and single-line-delete step mean the addition is trivial.
- **Deliberately not pre-built:** no `IDeleteStrategy` interface, no strategy factory, no polymorphism. One implementation, one code path, documented extension point. Phase 2 refactors this into a strategy pattern with concrete requirements in hand.

---

## 7. Queue Admin Console (LWC)

### 7.1 Container

- **Component:** `queueAdminConsole` (parent LWC, SLDS `lightning-tabset`, variant `scoped`).
- **Exposed as:** `FlexiPage` of type **App Page** named `Queue_Admin_Console`, assigned a CustomTab `Queue_Admin_Console`. App page (not record page) because this is a global admin surface, not scoped to a record.
- **Access:**
  - Tab visibility granted only in `Event_Queue_Admin` permission set.
  - Every `@AuraEnabled` method in `QueueAdminController` starts with `if (!FeatureManagement.checkPermission('Queue_Admin_Console_Access')) throw new AuraHandledException('Not authorized');` — defense in depth. (We introduce a new Custom Permission `Queue_Admin_Console_Access` gated by the permission set.)
  - `with sharing` on controller; object permissions enforced via `WITH SECURITY_ENFORCED` in SOQL.

### 7.2 Tabs

Each tab is its own child LWC so we can iterate on them independently.

#### Tab 1 · Overview (`queueAdminOverview`)
- SLDS `slds-page-header` with queue totals.
- Grid of `lightning-card`s, one per `Status__c`, showing count + oldest record age. Uses aggregate SOQL (`SELECT Status__c, COUNT(Id), MIN(CreatedDate) FROM Queue__c GROUP BY Status__c`).
- Callout banner: next `JobQueueRetention` fire time (from `CronTrigger`), retention-enabled state, last purge summary.
- "Refresh" button; no auto-refresh (keeps governor usage predictable).

#### Tab 2 · Retention Policies (`queueAdminRetentionPolicies`)
- `lightning-datatable` of `Queue_Retention_Policy__mdt` joined with the latest `Queue_Purge_Log__c` per policy (for "last run" columns).
- **Create / edit** uses a modal with hand-built `lightning-input` fields — **not** `lightning-record-edit-form`, because MDT isn't LDS-backed. On save, client-side validation runs (including the D3 uniqueness check — "another active policy already targets this status"), then `QueueAdminController.upsertPolicy(dto)` is called.
- Controller returns a deployment ID. The modal flips to a "Deployment in progress…" state with a spinner; LWC polls `getDeploymentStatus(deploymentId)` every 3s until `Succeeded` / `Failed`, then refreshes the table and closes.
- Row actions: **Run now**, **Run now (dry)**, **Activate / Deactivate** (both toggle `IsActive__c` via deploy), **Delete** (via metadata delete deploy), **Preview matches**.
- **Run now** invokes `QueueAdminService.runPolicyNow(developerName, dryRun)` which enqueues a one-off `QueueRetentionBatch` scoped to that single policy with `TriggeredBy = MANUAL`. Returns the `AsyncApexJob` id; LWC polls the log record for status.
- **Preview matches** calls `QueueAdminService.previewPolicyMatch(developerName)` — returns a `COUNT()` of rows that would be purged right now. Pure SOQL read, **no deploy** needed. Useful sanity-check before toggling `IsActive__c` or before a big `RetentionDays__c` change.
- Admin UX note: because every edit triggers a ~30s deploy, the modal clearly signals the wait, and the Settings tab includes a "Danger zone" link that opens the Setup → Custom Metadata Types page for bulk editing outside the console.

#### Tab 3 · Scheduling (`queueAdminScheduling`)
- Table of all four `Job*` classes (`JobPendingEvents`, `JobOldQueuedEvents`, `JobRetryEventProcessor`, `JobQueueRetention`) with: scheduled yes/no, next fire, cron expression, last fire.
- Buttons per row: **Start** (invokes `Job*.start()` which uses `ScheduleHelper` defaults), **Abort** (invokes `Job*.abort()`).
- Cron expression is read-only in the grid. To change cadence, admin **Abort**s then **Start**s with a custom cron (a "Custom cron" input appears on the Start action, default pre-filled with the job's standard cron).

#### Tab 4 · Purge History (`queueAdminPurgeHistory`)
- `lightning-datatable` of recent `Queue_Purge_Log__c` (most recent 200, with a "Load more" for pagination).
- Filters: status (SUCCESS / PARTIAL / ERROR / DRY_RUN / SKIPPED_GLOBAL_CAP), date range, policy.
- Row click opens a side panel with full error stack + chunk breakdown.

#### Tab 5 · Settings (`queueAdminSettings`)
Three stacked `lightning-card`s, each with its own `lightning-record-edit-form`, because the three settings live in three isolated directories (§5.3–5.6):
- **Queue Admin** — bound to `Queue_Admin_Setting__c` org default (5 fields: `IsRetentionEnabled__c`, `GlobalDryRun__c`, `MaxRecordsPerRun__c`, `ChunkSize__c`, `LogRetentionDays__c`, `EmptyRecycleBin__c`).
- **Notifier** — bound to `Notifier_Setting__c` org default (1 field: `ClassName__c`). LWC validates the configured class extends `AbstractNotifier` (via `@AuraEnabled` probe) before allowing save.
- **Logger** — bound to `Logger_Setting__c` org default (1 field: `ClassName__c`). Same class-extends-probe. Tooltip: "Blank = DebugLogger default (writes to `System.debug`)."
- A "Danger zone" card at the bottom with `Abort all jobs` button.

### 7.3 SLDS building blocks used

`lightning-tabset`, `lightning-card`, `lightning-datatable`, `lightning-record-edit-form`, `lightning-button`, `lightning-badge`, `lightning-icon`, `lightning-spinner`, `lightning-formatted-date-time`. No third-party libraries, no scoped CSS beyond what SLDS provides — the existing codebase has no LWC precedent, so we start with the cleanest possible stack.

### 7.4 Controller surface

All methods on `QueueAdminController`, all `@AuraEnabled(cacheable=false)` except pure-read ones which use `cacheable=true`:

```
getOverview()                 → OverviewDTO
listPolicies()                → List<PolicyDTO>  // MDT + derived last-run columns
upsertPolicy(dto)             → Id (deploymentId — async)
deletePolicy(developerName)   → Id (deploymentId — async)
getDeploymentStatus(depId)    → DeploymentStatusDTO { state, errors[] }
runPolicyNow(devName, dryRun) → Id (AsyncApexJob id)
previewPolicyMatch(devName)   → Integer (COUNT of rows that would be purged)
listPurgeLogs(filters, limit) → List<Queue_Purge_Log__c>
getScheduleStatus()           → List<ScheduleDTO>
startJob(className)           → void    // one of the four Job* names, whitelisted
abortJob(className)           → void
getAllSettings()              → SettingsDTO { queueAdmin, notifier, logger } // one trip fetches all three
upsertQueueAdminSetting(s)    → void    // synchronous — Custom Setting DML
upsertNotifierSetting(s)      → void    // + validates AbstractNotifier extension
upsertLoggerSetting(s)        → void    // + validates AbstractLogger extension
```

`startJob`/`abortJob` accept a string enum, not arbitrary class names — hardcoded whitelist `{JobPendingEvents, JobOldQueuedEvents, JobRetryEventProcessor, JobQueueRetention}` to prevent anyone using this surface to start arbitrary Apex.

---

## 8. Permissions

Everything is bare-name / unmanaged (Q2), so we directly extend the existing `Event_Queue_Admin` and `Event_Queue_Running_User` permission sets rather than adding sidecar ones.

### 8.1 New Custom Permission

`Queue_Admin_Console_Access` — gates every `@AuraEnabled` method via `FeatureManagement.checkPermission(...)`.

### 8.2 `Event_Queue_Admin` permission set (modified)

Adds:
- Custom Permission: `Queue_Admin_Console_Access` → enabled
- Apex class access: `JobQueueRetention`, `QueueRetentionBatch`, `QueueAdminController`, `QueueAdminService`, `QueueRetentionPolicyProvider`, plus the new framework-wide classes from `notifier/` (`AbstractNotifier`, `NotifierFactory`, `NotificationEvent`) and `logger/` (`AbstractLogger`, `LoggerFactory`, `DebugLogger`) — batches invoked from the admin's context call into both factories
- Objects: CRUD on `Queue_Purge_Log__c`, `Queue_Admin_Setting__c`, `Notifier_Setting__c`, `Logger_Setting__c`
- Tab: `Queue_Admin_Console` → Visible
- User permissions: `CustomizeApplication` (required for `Metadata.Operations.enqueueDeployment` — the MDT edit path from the LWC). Already granted on this set, so no change.

### 8.3 `Event_Queue_Running_User` permission set (modified)

Adds:
- Apex class access: `JobQueueRetention`, `QueueRetentionBatch`, `QueueRetentionPolicyProvider`, `AbstractNotifier`, `NotifierFactory`, `NotificationEvent`, `AbstractLogger`, `LoggerFactory`, `DebugLogger`
- Objects: create/edit on `Queue_Purge_Log__c`; read on `Queue_Admin_Setting__c`, `Notifier_Setting__c`, `Logger_Setting__c`
- No Custom Permission, no tab, no controller access.

### 8.4 Why not a third permission set?

Two sets already cover admin vs runtime cleanly. A separate `Event_Queue_Retention_Admin` would just split what today is one admin persona. Revisit if/when the admin role bifurcates. Flagged as D8 in §11.

---

## 9. Tests

Follows the house pattern — one test class per production class. Because retention lives in its own `retention/` source directory (Q2) and can't modify test classes in the managed core, a **new** `QueueAdminTestFactory` (in the retention package) provides local fixtures that parallel `EventQueueFixtureFactory`.

| New test | Exercises |
|----------|-----------|
| `JobQueueRetentionTest` | `execute/start/abort` lifecycle (mirrors `JobRetryEventProcessorTest`); global-disable short-circuit; serial-chain kickoff |
| `QueueRetentionBatchTest` | `start → execute → finish` lifecycle; log write; dry-run path; partial-failure path via forced DML failure; next-policy chain from `finish()`; empty-queue exit |
| `QueueRetentionPolicyProviderTest` | MDT cache behavior; `setMock(...)` seam; uniqueness guard used by the upsert path |
| `AbstractNotifierTest` | default `notify()` is a no-op; instance construction |
| `NotifierFactoryTest` | blank class name → null; unknown class name → null with no exception; valid class name → instance returned |
| `AbstractLoggerTest` | default method overrides are no-ops |
| `DebugLoggerTest` | each level writes `System.debug` with correct `LoggingLevel` and `[source]` prefix; error path includes stack trace |
| `LoggerFactoryTest` | blank config → `DebugLogger`; unknown class → `DebugLogger` (graceful); valid custom class → instance; `setMock(...)` seam |
| `QueueAdminControllerTest` | permission-denied path; each `@AuraEnabled` happy path; whitelist enforcement on `startJob` / `abortJob`; uniqueness rejection before deploy |
| `QueueAdminServiceTest` | policy matching, SOQL cutoff computation, log opening/closing |
| `QueueAdminTestFactory` (new, in `retention/`) | `createRetentionPolicy(status, days, isActive)`, `createAgedQueueRows(status, count, ageDays)`, `createPurgeLog(...)` |

Conventions preserved:
- `System.assertEquals` / `System.assert` (not modern `Assert.*`) to match `EventQueueTest`.
- No `@TestSetup` — each method builds its own fixture.
- `Test.startTest()/stopTest()` around async operations.
- Target coverage: ≥ 85% on all new classes, matching the rest of the codebase.

---

## 10. Documentation

New files (match existing doc style — kebab-case, markdown, mermaid where helpful):

- `docs/reference/retention-policies.md` — data model, uniqueness rule (D3), examples.
- `docs/reference/queue-admin-console.md` — tab-by-tab walkthrough with screenshots (to add post-implementation).
- `docs/reference/notifier.md` — `AbstractNotifier` + `NotificationEvent` contract, `NotifierFactory` wiring, per-source payload conventions (what `PURGE` emits in `context`, what future subsystems should emit), implementation examples (email via `Messaging`, Slack via HTTP callout, platform event publisher).
- `docs/reference/logger.md` — `AbstractLogger` contract, shipped `DebugLogger`, `LoggerFactory` lookup + caching, Nebula Logger wrapper example. Section on migration path for existing `System.debug` calls in core framework (follow-up work tracked in `docs/improvements.md`).
- `docs/setup/retention-configuration.md` — step-by-step enablement; unmanaged / bare-names delivery notes (Q2); the "attachments are purged with rows" warning; guidance on which statuses to add policies for first.
- `docs/architecture/retention.md` — sequence diagram of schedule → serial batch chain → log → notifier hook.

Updates:

- `docs/README.md` — link to the new pages under Reference/Setup/Architecture.
- `docs/personas/admin.md` — new "Managing retention" section.
- `docs/personas/support-ops.md` — update the "never delete" warning to "never delete *manually* — use retention policies".
- `docs/improvements.md` — mark #26 (dead-letter / purge) as in progress; add a new item for **"Migrate core framework `System.debug` calls to `LoggerFactory.getInstance()`"** covering `EventExecutor`, the three existing `Job*` classes, and `EventQueueActiveRecord` — scoped as a follow-up PR, not this one.

---

## 11. Decision log

All 14 points locked. Full context for why each was picked:

| ID | Decision | Locked value | Alternative considered | Why this value |
|----|----------|--------------|------------------------|----------------|
| **D1** | Purge engine | **`Database.Batchable`, policies run serially** | Queueable chain | Native chunking for large row volumes, `AsyncApexJob` gives built-in observability alongside `Queue_Purge_Log__c`. Serial execution sidesteps the 5-concurrent-batch limit and produces one clean log per policy per cycle. |
| **D2** | Policy storage | **Custom Metadata Type `Queue_Retention_Policy__mdt`** | Custom Object | Version-controlled, free storage, matches `Event_Configuration__mdt` pattern. Tradeoffs accepted: admin edits are async (10–60s deploy), runtime state lives in `Queue_Purge_Log__c` instead of on the policy. |
| **D3** | Retention granularity | **Per-Status only, one active policy per status** | Per-Status + per-EventName | Simpler mental model, no priority/overlap logic, trivial purge query. |
| **D4** | Delete strategy | **Hard delete; extension seam for Phase 2 archive** | Archive now | Keeps this PR shippable; seam is minimal (one log field, single-line delete step). No interface pre-built. |
| **D5** | UI surface | **App Page + Tab `Queue_Admin_Console`, added to `Event_Queue` app nav** | Utility bar / home embed | Tab visibility is the natural permission gate; full viewport for five sub-tabs. |
| **D6** | Frontend framework | **LWC** | Aura | Modern standard; no Aura precedent in repo. |
| **D7** | Schedule cadence | **Daily at 02:00** (`0 0 2 * * ?`) | Hourly / every 15 min | Nightly drain keeps purge off peak hours; admin can override from Scheduling tab. |
| **D8** | Permission model | **Extend existing two sets + new Custom Permission** | New `Event_Queue_Retention_Admin` set | Same person admins framework + retention; easy future split if role bifurcates. |
| **D9** | Notifications | **Framework-wide pluggable via `AbstractNotifier` + `NotificationEvent`; no concrete shipped** | Purge-specific `AbstractPurgeNotifier` / built-in transport | Generalized to serve any future subsystem (retry, dispatch, etc.) from one central notifier. Follows the `AbstractCommand` / `CommandFactory` pattern. |
| **D10** | Empty recycle bin | **Default OFF (configurable)** | Default ON | Preserves 15-day recovery window via Setup → Recycle Bin UI. Admin flips ON if org-wide 15M recycle-bin cap is hit. |
| **D11** | Logging | **Framework-wide pluggable via `AbstractLogger` + `LoggerFactory`; ships `DebugLogger` as default** | Ad-hoc `System.debug` / retention-local logger | Centralizes framework logging; retention code uses `LoggerFactory.getInstance()` throughout. Non-null default so callers never null-check. Existing core `System.debug` migration tracked as improvements.md follow-up. |
| **Q2** | Packaging | **Unmanaged / source-only; no namespace prefix anywhere** | Same managed package / separate managed extension | Bare names throughout; `retention/` as a new source directory in `sfdx-project.json` with no `package` key. |
| **Q3** | Restore-from-recyclebin action | **None in Phase 1** | First-class button | Standard Setup → Recycle Bin UX is enough for a rare oh-crap scenario; building a button would be a half-measure. |
| **Q4** | Compliance constraints | **None** — no floors, ceilings, PII, or policy doc | — | Pure operational hygiene; no changes to D3 or D4 driven by compliance. |
| **Q5** | Rollout | **Single PR** — engine + UI + polish | Phase 1.0 / 1.1 / 1.2 split | One deploy, default-off safety. |

---

## 12. Rollout plan

**Single PR ships everything** (Q5). No phase split.

Scope of the one PR:
- **Notifier framework** (`notifier/`, self-contained, zero dependencies): `AbstractNotifier`, `NotificationEvent`, `NotifierFactory`, `Notifier_Setting__c` custom setting + tests.
- **Logger framework** (`logger/`, self-contained, zero dependencies): `AbstractLogger`, `DebugLogger`, `LoggerFactory`, `Logger_Setting__c` custom setting + tests. Concrete `DebugLogger` ships as default.
- **Data model** (`retention/`): `Queue_Retention_Policy__mdt`, `Queue_Purge_Log__c`, `Queue_Admin_Setting__c` (5 fields — Notifier/Logger config lives in their own folders)
- **Engine** (`retention/`): `JobQueueRetention` (Schedulable), `QueueRetentionBatch` (Batchable, serial policy execution), `QueueRetentionPolicyProvider` (MDT cache + test seam)
- **Admin Console** (`retention/`): `queueAdminConsole` parent LWC + five tab child LWCs, `QueueAdminController`, `QueueAdminService`, FlexiPage, Tab
- **Access** (`force-app/`): `Queue_Admin_Console_Access` Custom Permission, `Event_Queue_Admin` + `Event_Queue_Running_User` permission-set updates, `Event_Queue.app-meta.xml` nav update
- **Tests:** full suite (§9)
- **Docs:** full set (§10), including new `docs/reference/notifier.md` and `docs/reference/logger.md`
- **Polish:** preview-count action, improvements.md close-out (existing #26 + new "migrate core `System.debug` to LoggerFactory" item), screenshots

**Default-off safety.** The feature is inert on deploy: `Queue_Admin_Setting__c.IsRetentionEnabled__c = false`, zero active policies. Admin explicitly enables after reviewing the console and creating their first policy. Zero behavior change until that opt-in.

**Phase 2 (deferred, not in this PR):** Big Object archive (D4 extension seam), real-time metrics, per-event dashboards.

---

## 13. Risks & mitigations

| Risk | Mitigation |
|------|-----------|
| Mass delete triggers DLRS / flows on `Queue__c` | None currently exist in source; add a `docs/setup/retention-configuration.md` warning for extenders. |
| Batch chain exhausts batch-per-org limits (5 concurrent) | Serial execution (D1) — only one `QueueRetentionBatch` alive at a time, regardless of policy count. Never contends with its own chain. Can still contend with other batches org-wide; Settings tab surfaces a warning if batch slots are >80% occupied at scheduled fire time. |
| Admin accidentally sets `RetentionDays__c = 0` | Validation rule on the MDT: `RetentionDays__c >= 1`. First activation of a newly created policy shows a confirmation modal in the LWC with the row count a preview would return ("This will purge N rows on next run. Continue?"). |
| Attachment cascade deletes logs admins wanted to keep | Documented clearly; optional future enhancement: detach attachments to ContentVersion before delete. |
| Custom Permission check bypassed by a user with "Modify All Data" | By design — Modify-All is root-level access in Salesforce; we don't second-guess it. |
| Recycle bin overflow (org-wide 15M limit) | `EmptyRecycleBin__c` defaults OFF for the recovery window; Admin Console shows a warning banner if current recycle bin usage is >80% so admin knows when to flip it ON. |
| MDT deploy UX — admin saves a policy and has to wait ~30s | UI explicitly shows "deployment in progress" with spinner + polling; admin can close modal and return later. Documented in `docs/setup/retention-configuration.md`. |
| MDT deploys are subject to the org's concurrent deploy limits | Rare in practice for single-record changes. Polling surface handles "queued" state gracefully. |
| MDT test fixtures are awkward | Tests use in-memory `Queue_Retention_Policy__mdt` instances + a seam on the caching loader (`QueueRetentionPolicyProvider.setMock(...)`) to avoid relying on actually-deployed records in the test org. |
| **Unmanaged delivery (Q2)** — no package-version upgrade story; each customer org has its own copy of the source. | Accepted tradeoff. Publish retention as a tagged release in the repo so orgs can pull specific versions via `sf project deploy start`. Any unmanaged-package release uses standard Setup → Package install UX. |
| **Unmanaged delivery** — admins can edit the source in their org (including MDT fields) and diverge from the repo. | Accepted per Q2. Flagged in `docs/setup/retention-configuration.md`. |
| **`CustomizeApplication` grant** — required so the Admin Console can call `Metadata.Operations.enqueueDeployment`, but it's a broad permission (admin can also manage app settings, deploy metadata generally). | Only assigned to users who need the console. Console-level Custom Permission (`Queue_Admin_Console_Access`) is the narrower gate; `CustomizeApplication` is an API-level prerequisite we can't narrow further. Documented. Already granted by the existing `Event_Queue_Admin` set, so no change in scope. |

---

## 14. File inventory (what gets created)

```
# ─── notifier/ ─────────── self-contained notifier framework ──────
notifier/main/default/classes/
  AbstractNotifier.cls                          (+ -meta.xml)  ← virtual base; no-op default
  AbstractNotifierTest.cls                      (+ -meta.xml)
  NotificationEvent.cls                         (+ -meta.xml)  ← DTO
  NotifierFactory.cls                           (+ -meta.xml)  ← reads Notifier_Setting__c; returns null if unconfigured
  NotifierFactoryTest.cls                       (+ -meta.xml)

notifier/main/default/objects/
  Notifier_Setting__c/…                         (hierarchy custom setting + 1 field: ClassName__c)

# ─── logger/ ───────────── self-contained logger framework ────────
logger/main/default/classes/
  AbstractLogger.cls                            (+ -meta.xml)  ← virtual base; no-op default
  AbstractLoggerTest.cls                        (+ -meta.xml)
  DebugLogger.cls                               (+ -meta.xml)  ← concrete default; System.debug with level prefix
  DebugLoggerTest.cls                           (+ -meta.xml)
  LoggerFactory.cls                             (+ -meta.xml)  ← reads Logger_Setting__c; falls back to DebugLogger
  LoggerFactoryTest.cls                         (+ -meta.xml)

logger/main/default/objects/
  Logger_Setting__c/…                           (hierarchy custom setting + 1 field: ClassName__c)

# ─── retention/ ────────── retention engine + Admin Console ───────
retention/main/default/classes/
  JobQueueRetention.cls                         (+ -meta.xml)
  JobQueueRetentionTest.cls                     (+ -meta.xml)
  QueueRetentionBatch.cls                       (+ -meta.xml)
  QueueRetentionBatchTest.cls                   (+ -meta.xml)
  QueueAdminController.cls                      (+ -meta.xml)
  QueueAdminControllerTest.cls                  (+ -meta.xml)
  QueueAdminService.cls                         (+ -meta.xml)
  QueueAdminServiceTest.cls                     (+ -meta.xml)
  QueueRetentionPolicyProvider.cls              (+ -meta.xml)  ← MDT cache + test seam
  QueueAdminTestFactory.cls                     (+ -meta.xml)  ← local test fixtures; parallels EventQueueFixtureFactory

retention/main/default/objects/
  Queue_Retention_Policy__mdt/…                 (MDT + 6 custom fields)
  Queue_Purge_Log__c/…                          (object + 14 custom fields + auto-number Name + layout + list view + tab)
  Queue_Admin_Setting__c/…                      (hierarchy custom setting + 5 fields — Notifier/Logger config moved out per user request)

retention/main/default/tabs/
  Queue_Admin_Console.tab-meta.xml
  Queue_Purge_Log__c.tab-meta.xml               (standard object tab)

retention/main/default/flexipages/
  Queue_Admin_Console.flexipage-meta.xml        (App Page hosting queueAdminConsole)

retention/main/default/lwc/
  queueAdminConsole/                            (parent w/ tabset)
  queueAdminOverview/
  queueAdminRetentionPolicies/
  queueAdminScheduling/
  queueAdminPurgeHistory/
  queueAdminSettings/

retention/main/default/customPermissions/
  Queue_Admin_Console_Access.customPermission-meta.xml

# ─── force-app/ ────────── modifications to existing managed-core ─
force-app/main/default/permissionsets/
  Event_Queue_Admin.permissionset-meta.xml           (modified — see §8.2)
  Event_Queue_Running_User.permissionset-meta.xml    (modified — see §8.3)

force-app/main/default/applications/
  Event_Queue.app-meta.xml                           (modified — add new tab to app nav)

# ─── project config ───────────────────────────────────────────────
sfdx-project.json                               (modified — add three new packageDirectories entries:
                                                 `{"path": "notifier"}`, `{"path": "logger"}`, `{"path": "retention"}`,
                                                 all non-default, no `package` key, same shape as existing `demo/`)

docs/
  architecture/retention.md                     (new)
  reference/retention-policies.md               (new)
  reference/queue-admin-console.md              (new)
  setup/retention-configuration.md              (new)
  personas/admin.md                             (modified)
  personas/support-ops.md                       (modified)
  README.md                                     (modified)
  improvements.md                               (modified — #26 in progress)

manifest/package.xml                            (optional — maintained for selective deploys; not required for `sf project deploy start -d retention`)
```

**Totals:**
- `notifier/`: 5 Apex classes (3 prod + 2 tests) + 1 hierarchy custom setting + 1 field
- `logger/`: 6 Apex classes (3 prod + 3 tests) + 1 hierarchy custom setting + 1 field
- `retention/`: 10 Apex classes (7 prod + 2 tests + 1 test factory) + 1 MDT (6 fields) + 1 Custom Object (14 fields) + 1 hierarchy custom setting (5 fields) + 6 LWCs + 1 FlexiPage + 2 Tabs + 1 Custom Permission
- `force-app/` modifications: 2 permission sets + 1 application nav
- Project: 1 `sfdx-project.json` update (3 new packageDirectories)
- Docs: 7 new + 4 modified files

Total: ~21 new Apex classes, 3 new objects, 2 new custom settings, 6 new LWCs. All additive; feature is inert on deploy (opt-in via `IsRetentionEnabled__c`). `notifier/` and `logger/` are genuinely self-contained — each could be lifted into another project as a drop-in with zero edits.

---

## 15. Ready for implementation

All decision points and open questions resolved (see §11). Next step: start the implementation PR per §12.
