# Retention Policies

`Queue_Retention_Policy__mdt` — one record per status the admin wants governed.

## Fields

| Field | Type | Purpose |
|-------|------|---------|
| `Label` | Text(40) | Human label, e.g. "Delivered — 30 days" |
| `DeveloperName` | Text(40) | Stable key used in `Queue_Purge_Log__c.PolicyDeveloperName__c` |
| `Status__c` | Picklist | `Queue__c.Status__c` value this policy targets |
| `RetentionDays__c` | Number(4,0) | Rows older than this (by `CreatedDate`) are eligible |
| `IsActive__c` | Checkbox | Per-policy opt-in (master switch is on `Queue_Admin_Setting__c`) |
| `MaxDeletePerRun__c` | Number(7,0) | Per-policy cap enforced in the QueryLocator LIMIT |
| `DryRun__c` | Checkbox | Evaluate + log, no DML. Global override at `Queue_Admin_Setting__c.GlobalDryRun__c` |
| `Notes__c` | LongText | Free-form admin notes |

## Uniqueness rule (D3)

**At most one ACTIVE policy per `Status__c`.** Enforced at upsert by `QueueRetentionPolicyProvider.hasActiveConflict(...)` before the Metadata deploy fires. To change retention for a status, edit the existing active policy or deactivate it before creating a new one.

## Example

```
DeveloperName    Status      Days   IsActive  MaxPerRun
Delivered_30d    DELIVERED   30     true      10000
Error_1y         ERROR       365    true      10000
Invalid_90d      INVALID     90     false     10000
```

Transient statuses (`QUEUED`, `PROCESSING`, `SCHEDULED`) typically have no policy — they're recovered by the existing `Job*` retry jobs, not purged.

## Edit path

Admins edit via:
1. **Queue Admin Console → Retention Policies tab** — create/edit/delete modal. Save → `QueueAdminController.upsertPolicy` → `Metadata.Operations.enqueueDeployment` → LWC polls for completion (~30s).
2. **Setup → Custom Metadata Types → Queue Retention Policy** — standard Salesforce UI.

Both paths go through the Metadata API; both take 10–60s per save.
