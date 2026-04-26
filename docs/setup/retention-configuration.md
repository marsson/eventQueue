# Retention — Setup & Configuration

## Prerequisites

1. `async_queue` core framework deployed (standard install).
2. `notifier/`, `logger/`, `retention/` source directories deployed via `sf project deploy start -d notifier -d logger -d retention`.
3. `Event_Queue_Admin` permission set assigned to your admin user.

## Enabling retention

Retention is **inert on deploy**. Nothing happens until an admin explicitly enables it.

1. Navigate to the **Queue Admin Console** tab (visible under the Event Queue app for users with `Event_Queue_Admin`).
2. **Settings** tab → Queue Admin card:
   - Toggle **Retention enabled** ON.
   - Leave **Global dry run** ON for your first cycle if you want to confirm everything behaves without any DML.
   - Adjust **Max records per cycle** and **Chunk size** if needed (defaults: 50,000 global cap, 2,000 scope size).
   - Leave **Empty recycle bin** OFF (default) — gives you 15 days of recovery via standard Setup → Recycle Bin.
3. **Retention Policies** tab → **New policy**:
   - Pick a `Status__c` and `RetentionDays__c`.
   - Start with `IsActive__c = false` + `DryRun__c = true` on your first policy.
   - Save → waits ~30s for the Metadata deploy.
4. Back on the policy row, **Run now (dry)** → produces a `Queue_Purge_Log__c` with status `DRY_RUN` and `RecordsEvaluated__c` showing what would be purged.
5. If the count looks right: edit the policy, flip `DryRun__c` OFF, flip `IsActive__c` ON, save (another deploy).
6. **Scheduling** tab → Start `JobQueueRetention`. Default cron is daily at 02:00; override with a custom cron via the "Custom cron" input if needed.

## Important warnings

- **Attachments are purged with the row.** `Queue__c` rows have associated `Attachment` records (processing logs, payloads). Standard cascade delete of the parent removes them. If you need to preserve logs, migrate them off `Attachment` before enabling retention.
- **Unmanaged delivery.** There is no managed-package upgrade story. Each org has its own copy of `notifier/`, `logger/`, `retention/` source. Bumps come via redeploy.
- **Admins can edit the MDT.** `Queue_Retention_Policy__mdt` lives in an unmanaged source folder — admins with `Customize Application` can edit it directly in Setup, bypassing the console's uniqueness check. The console is the safer path.
- **`CustomizeApplication` grant** — required for `Metadata.Operations.enqueueDeployment`. Already granted by `Event_Queue_Admin`. This is a broad permission (covers app/setup deployment in general), gate access accordingly.

## Notifier + Logger setup

### Notifier (optional — silent by default)

1. Write a class extending `AbstractNotifier` (see `docs/reference/notifier.md`).
2. Deploy the class to the org.
3. Queue Admin Console → Settings → Notifier card → enter the fully-qualified class name → Save.

The save path validates that the class exists and extends `AbstractNotifier`; invalid classes are rejected before persisting.

### Logger (optional — `DebugLogger` default)

1. Write a class extending `AbstractLogger` (see `docs/reference/logger.md`).
2. Deploy.
3. Queue Admin Console → Settings → Logger card → enter the fully-qualified class name → Save.

Blank = `DebugLogger` (writes to `System.debug` with level prefix).

## Deploy order

The three folders have clean dependency arrows:

```
notifier/   (no deps)
logger/     (no deps)
retention/  (depends on notifier/, logger/, async_queue/Queue__c)
```

Valid sfdx deploy command:

```
sf project deploy start -d notifier -d logger -d retention -d force-app
```

Tests run against the combined source.
