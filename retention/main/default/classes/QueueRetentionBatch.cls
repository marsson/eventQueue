/**
 * @description Batchable worker for one retention policy. One active
 * instance at a time (D1 = serial); `finish()` chains the next policy
 * in the pending queue. Writes a `Queue_Purge_Log__c` per run, emits
 * a `NotificationEvent` via `NotifierFactory`, logs through
 * `LoggerFactory`.
 *
 * Lifecycle:
 *   start(bc)   — opens a PARTIAL log, returns the QueryLocator
 *                 bounded by the policy's MaxDeletePerRun__c
 *   execute(bc) — deletes the scope (D4 = hard delete; the extension
 *                 seam is this one line)
 *   finish(bc)  — closes the log, notifies, optionally chains next
 *
 * Stateful because we accumulate counters across chunks.
 */
public with sharing class QueueRetentionBatch implements Database.Batchable<sObject>, Database.Stateful {

    private static final String SRC = 'QueueRetentionBatch';

    @TestVisible private Queue_Retention_Policy__mdt policy;
    @TestVisible private List<Queue_Retention_Policy__mdt> remaining;
    @TestVisible private String triggeredBy;
    @TestVisible private Id runByUserId;
    @TestVisible private Boolean effectiveDryRun;
    @TestVisible private Integer alreadyDeletedThisCycle;

    @TestVisible private Id logId;
    @TestVisible private Datetime runStarted;
    @TestVisible private Long evaluated = 0;
    @TestVisible private Long deleted = 0;
    @TestVisible private Long skipped = 0;
    @TestVisible private Integer chunkCount = 0;
    @TestVisible private Exception thrownException;
    @TestVisible private Boolean globalCapHit = false;
    @TestVisible private List<Id> deletedIds = new List<Id>();

    /**
     * @description Construct a batch for a single policy, optionally
     * carrying the remaining-policy queue for the serial chain.
     * @param policy Policy to run.
     * @param remaining Policies to chain after this one finishes.
     *                  Pass empty list or null for one-off runs.
     * @param triggeredBy One of `SCHEDULED`, `MANUAL`, `DRY_RUN_MANUAL`.
     * @param runByUserId User who initiated the run (UserInfo.getUserId() for scheduled runs).
     * @param alreadyDeletedThisCycle Sum of rows deleted by earlier
     *        policies in this cycle — enforced against the global cap.
     */
    public QueueRetentionBatch (
        Queue_Retention_Policy__mdt policy,
        List<Queue_Retention_Policy__mdt> remaining,
        String triggeredBy,
        Id runByUserId,
        Integer alreadyDeletedThisCycle
    ) {
        this.policy      = policy;
        this.remaining   = remaining == null ? new List<Queue_Retention_Policy__mdt>() : remaining;
        this.triggeredBy = triggeredBy;
        this.runByUserId = runByUserId;
        this.alreadyDeletedThisCycle = alreadyDeletedThisCycle == null ? 0 : alreadyDeletedThisCycle;
    }

    public Database.QueryLocator start (Database.BatchableContext bc) {
        this.runStarted = System.now();

        Queue_Admin_Setting__c s = Queue_Admin_Setting__c.getOrgDefaults();
        Boolean policyDryRun = this.policy.DryRun__c == true;
        Boolean globalDryRun = s != null && s.GlobalDryRun__c == true;
        this.effectiveDryRun = policyDryRun || globalDryRun;

        // Global cap check — if we've already spent the budget, skip.
        Integer globalCap = (s != null && s.MaxRecordsPerRun__c != null)
                            ? Integer.valueOf(s.MaxRecordsPerRun__c)
                            : 50000;
        if (this.alreadyDeletedThisCycle >= globalCap) {
            this.globalCapHit = true;
            this.logId = openLog('SKIPPED_GLOBAL_CAP');
            LoggerFactory.getInstance().warn(SRC,
                'Global cap (' + globalCap + ') reached; policy '
                + this.policy.DeveloperName + ' skipped this cycle.');
            // Return an empty locator — execute() won't run.
            return Database.getQueryLocator([SELECT Id FROM Queue__c WHERE Id = null]);
        }

        this.logId = openLog(this.effectiveDryRun ? 'DRY_RUN' : 'PARTIAL');

        DateTime cutoff = System.now().addDays(-Integer.valueOf(this.policy.RetentionDays__c));
        Integer perPolicyCap = this.policy.MaxDeletePerRun__c != null
                             ? Integer.valueOf(this.policy.MaxDeletePerRun__c)
                             : 10000;
        Integer remainingGlobal = globalCap - this.alreadyDeletedThisCycle;
        Integer effectiveLimit = Math.min(perPolicyCap, remainingGlobal);

        String status = this.policy.Status__c;
        LoggerFactory.getInstance().info(SRC,
            'Running policy ' + this.policy.DeveloperName
            + ' status=' + status
            + ' cutoff=' + cutoff
            + ' limit=' + effectiveLimit
            + ' dryRun=' + this.effectiveDryRun);

        return Database.getQueryLocator([
            SELECT Id
            FROM Queue__c
            WHERE Status__c = :status
              AND CreatedDate < :cutoff
            ORDER BY CreatedDate ASC
            LIMIT :effectiveLimit
        ]);
    }

    public void execute (Database.BatchableContext bc, List<sObject> scope) {
        this.chunkCount++;
        this.evaluated += scope.size();

        if (this.effectiveDryRun) {
            return;
        }

        // ─── Extension seam (§6.7) ─────────────────────────────────
        // Phase 2 (archive) replaces the next line with
        //   archiver.archive(scope); Database.delete(scope, false);
        // and no other lifecycle code changes.
        Database.DeleteResult[] results = Database.delete(scope, false);
        // ───────────────────────────────────────────────────────────

        for (Integer i = 0; i < results.size(); i++) {
            if (results[i].isSuccess()) {
                this.deleted++;
                this.deletedIds.add(results[i].getId());
            } else {
                this.skipped++;
            }
        }
    }

    public void finish (Database.BatchableContext bc) {
        AbstractLogger log = LoggerFactory.getInstance();
        Datetime finished = System.now();
        Long durationSec = (finished.getTime() - this.runStarted.getTime()) / 1000;

        String finalStatus;
        if (this.globalCapHit) {
            finalStatus = 'SKIPPED_GLOBAL_CAP';
        } else if (this.effectiveDryRun) {
            finalStatus = 'DRY_RUN';
        } else if (this.thrownException != null) {
            finalStatus = 'ERROR';
        } else if (this.skipped > 0) {
            finalStatus = 'PARTIAL';
        } else {
            finalStatus = 'SUCCESS';
        }

        // Each finish() step is isolated: a failure in one (e.g. log
        // close, recycle bin, notifier) must not stop the chain. The
        // most important step is enqueueNext() — without it, the
        // policy chain stalls silently.
        try { closeLog(finalStatus, finished, durationSec); }
        catch (Exception e) { log.error(SRC, 'closeLog failed: ' + e.getMessage(), e); }

        try { emptyRecycleBinIfConfigured(); }
        catch (Exception e) { log.error(SRC, 'emptyRecycleBinIfConfigured failed: ' + e.getMessage(), e); }

        try { fireNotification(finalStatus); }
        catch (Exception e) { log.error(SRC, 'fireNotification failed: ' + e.getMessage(), e); }

        try { enqueueNext(); }
        catch (Exception e) { log.error(SRC, 'enqueueNext failed — chain stalled: ' + e.getMessage(), e); }
    }

    // ─── helpers ────────────────────────────────────────────────────

    private Id openLog (String initialStatus) {
        Queue_Purge_Log__c log = new Queue_Purge_Log__c(
            RunStartedAt__c        = this.runStarted == null ? System.now() : this.runStarted,
            PolicyDeveloperName__c = this.policy.DeveloperName,
            PolicyLabel__c         = this.policy.Label,
            Status__c              = initialStatus,
            TriggeredBy__c         = this.triggeredBy,
            RunByUser__c           = this.runByUserId,
            DeleteStrategy__c      = 'HARD_DELETE'
        );
        insert log;
        return log.Id;
    }

    private void closeLog (String status, Datetime completed, Long durationSec) {
        if (this.logId == null) return;
        Queue_Purge_Log__c log = new Queue_Purge_Log__c(
            Id                  = this.logId,
            Status__c           = status,
            RunCompletedAt__c   = completed,
            DurationSeconds__c  = durationSec,
            RecordsEvaluated__c = this.evaluated,
            RecordsDeleted__c   = this.deleted,
            RecordsSkipped__c   = this.skipped,
            ChunkCount__c       = this.chunkCount,
            ErrorMessage__c     = this.thrownException == null ? null
                                  : this.thrownException.getMessage() + '\n' + this.thrownException.getStackTraceString()
        );
        update log;
    }

    private void emptyRecycleBinIfConfigured () {
        Queue_Admin_Setting__c s = Queue_Admin_Setting__c.getOrgDefaults();
        if (s == null || s.EmptyRecycleBin__c != true) return;
        if (this.deletedIds == null || this.deletedIds.isEmpty()) return;
        try {
            // Process in 200-id slices — Database.emptyRecycleBin caps at 200 per call.
            Integer i = 0;
            while (i < this.deletedIds.size()) {
                Integer ending = Math.min(i + 200, this.deletedIds.size());
                List<Id> slice = new List<Id>();
                for (Integer j = i; j < ending; j++) slice.add(this.deletedIds[j]);
                Database.emptyRecycleBin(slice);
                i = ending;
            }
        } catch (Exception e) {
            LoggerFactory.getInstance().warn(SRC, 'emptyRecycleBin failed: ' + e.getMessage());
        }
    }

    private void fireNotification (String finalStatus) {
        AbstractNotifier notifier = NotifierFactory.createInstance();
        if (notifier == null) return;

        Queue_Purge_Log__c log = [
            SELECT Id, Name, RunStartedAt__c, RunCompletedAt__c, DurationSeconds__c,
                   PolicyDeveloperName__c, PolicyLabel__c, Status__c,
                   RecordsEvaluated__c, RecordsDeleted__c, RecordsSkipped__c,
                   ChunkCount__c, ErrorMessage__c, TriggeredBy__c, DeleteStrategy__c
            FROM Queue_Purge_Log__c
            WHERE Id = :this.logId
            LIMIT 1
        ];

        NotificationEvent evt = new NotificationEvent();
        evt.source    = 'PURGE';
        evt.severity  = finalStatus == 'ERROR' ? 'ERROR'
                      : (finalStatus == 'PARTIAL' || finalStatus == 'SKIPPED_GLOBAL_CAP') ? 'WARN'
                      : 'INFO';
        evt.eventType = 'PURGE_' + finalStatus;
        evt.title     = 'Queue purge ' + finalStatus + ' — ' + log.PolicyLabel__c;
        evt.message   = log.RecordsDeleted__c + ' deleted; ' + log.RecordsSkipped__c + ' skipped; ' + log.ChunkCount__c + ' chunks';
        evt.context   = new Map<String, Object>{
            'purgeLogId'          => log.Id,
            'purgeLogName'        => log.Name,
            'policyDeveloperName' => log.PolicyDeveloperName__c,
            'recordsEvaluated'    => log.RecordsEvaluated__c,
            'recordsDeleted'      => log.RecordsDeleted__c,
            'recordsSkipped'      => log.RecordsSkipped__c,
            'durationSeconds'     => log.DurationSeconds__c,
            'triggeredBy'         => log.TriggeredBy__c,
            'deleteStrategy'      => log.DeleteStrategy__c
        };
        evt.thrown = this.thrownException;

        try {
            notifier.notify(evt);
        } catch (Exception e) {
            LoggerFactory.getInstance().error(SRC, 'notifier failed: ' + e.getMessage(), e);
        }
    }

    private void enqueueNext () {
        if (this.remaining.isEmpty()) {
            LoggerFactory.getInstance().info(SRC, 'policy chain complete.');
            return;
        }
        Queue_Retention_Policy__mdt next = this.remaining.remove(0);
        Integer chunk = resolveChunkSize();
        Integer runningTotal = this.alreadyDeletedThisCycle + (this.deleted == null ? 0 : Integer.valueOf(this.deleted));
        LoggerFactory.getInstance().info(SRC,
            'chaining next policy ' + next.DeveloperName + '; running total=' + runningTotal);
        Database.executeBatch(
            new QueueRetentionBatch(next, this.remaining, this.triggeredBy, this.runByUserId, runningTotal),
            chunk
        );
    }

    private Integer resolveChunkSize () {
        Queue_Admin_Setting__c s = Queue_Admin_Setting__c.getOrgDefaults();
        if (s != null && s.ChunkSize__c != null) return Integer.valueOf(s.ChunkSize__c);
        return 2000;
    }
}
