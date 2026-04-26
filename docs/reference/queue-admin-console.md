# Queue Admin Console

SLDS-based Lightning page, exposed as App Page + Tab `Queue_Admin_Console`, added to the `Event_Queue` app navigation. Tab visibility is gated by the `Event_Queue_Admin` permission set; every `@AuraEnabled` method additionally checks the `Queue_Admin_Console_Access` custom permission.

## Tabs

### 1. Overview

- Retention enabled / global dry-run badges
- Next scheduled `JobQueueRetention` fire + cron expression
- Last purge summary (Name, Policy, Status, Deleted count)
- Queue__c aggregate by Status (count + oldest row)
- Refresh button — no auto-refresh

### 2. Retention Policies

- `lightning-datatable` joining `Queue_Retention_Policy__mdt` with the latest `Queue_Purge_Log__c` per policy (for Last Run columns)
- **New policy** → modal with `lightning-input` fields (MDT isn't LDS-backed, so no `lightning-record-edit-form`)
- Save → `QueueAdminController.upsertPolicy` returns a deployment id; modal shows "Deploying…" spinner; polls `getDeploymentStatus` every 3s up to 2 minutes
- D3 uniqueness checked **before** the deploy fires (saves a round trip)
- Row actions: **Run now**, **Run now (dry)**, **Preview matches**, **Edit**

### 3. Scheduling

- Table of all four `Job*` classes (`JobPendingEvents`, `JobOldQueuedEvents`, `JobRetryEventProcessor`, `JobQueueRetention`)
- Per row: scheduled yes/no, next fire, current cron, last fire
- Actions: **Start** / **Abort**. Optional "Custom cron" input at the top of the tab lets the admin override a job's default cadence on Start.

### 4. Purge History

- `lightning-datatable` of `Queue_Purge_Log__c` (most recent 200)
- Status filter: All / SUCCESS / PARTIAL / ERROR / DRY_RUN / SKIPPED_GLOBAL_CAP

### 5. Settings

Three stacked cards, each bound to its own hierarchy custom setting so the folders stay self-contained:

- **Queue Admin** (`Queue_Admin_Setting__c`) — 6 fields: master switch, global dry-run, global cap, chunk, log retention, empty recycle bin
- **Notifier** (`Notifier_Setting__c.ClassName__c`) — LWC validates the configured class extends `AbstractNotifier` via `@AuraEnabled` probe before saving. Blank = silent.
- **Logger** (`Logger_Setting__c.ClassName__c`) — same validation pattern. Blank = shipped `DebugLogger` default.
- **Danger zone** — "Abort all jobs" button.

## Access

- `Event_Queue_Admin` permission set assigns:
  - Custom Permission `Queue_Admin_Console_Access`
  - Apex class access for all retention + notifier + logger classes
  - Object CRUD on `Queue_Purge_Log__c`
  - Tab visibility on `Queue_Admin_Console`, `Queue_Purge_Log__c`
  - `CustomizeApplication` (required for `Metadata.Operations.enqueueDeployment`)

## Server surface

All methods on `QueueAdminController`; all wrap `FeatureManagement.checkPermission('Queue_Admin_Console_Access')`:

- `getOverview()`, `listPolicies()`, `previewPolicyMatch()`, `runPolicyNow()`
- `upsertPolicy()`, `getDeploymentStatus()`
- `listPurgeLogs()`, `getScheduleStatus()`, `startJob()`, `abortJob()`
- `getAllSettings()`, `upsertQueueAdminSetting()`, `upsertNotifierSetting()`, `upsertLoggerSetting()`
