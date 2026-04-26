/**
 * @description Schedulable that kicks off the retention cycle once
 * per scheduled fire. Matches the `Job*` pattern used by
 * `JobPendingEvents`, `JobOldQueuedEvents`, `JobRetryEventProcessor`.
 *
 * Behavior:
 *   1. Check Queue_Admin_Setting__c.IsRetentionEnabled__c — if false, no-op.
 *   2. Load active `Queue_Retention_Policy__mdt` rules.
 *   3. Kick off the first policy as a Batchable. That batch's
 *      finish() enqueues the next one — serial execution.
 *
 * Default cron is daily at 02:00. Admins can abort and re-start with
 * a custom cron from the Admin Console's Scheduling tab.
 */
global class JobQueueRetention implements Schedulable {

    private static final String JOB_NAME = 'JobQueueRetention';
    private static final String DEFAULT_CRON = '0 0 2 * * ?';

    global JobQueueRetention () {}

    global void execute (SchedulableContext sc) {
        AbstractLogger log = LoggerFactory.getInstance();

        Queue_Admin_Setting__c s = Queue_Admin_Setting__c.getOrgDefaults();
        if (s == null || s.IsRetentionEnabled__c != true) {
            log.info(JOB_NAME, 'retention disabled via Queue_Admin_Setting__c — skipping cycle.');
            return;
        }

        List<Queue_Retention_Policy__mdt> actives = QueueRetentionPolicyProvider.getActive();
        if (actives.isEmpty()) {
            log.info(JOB_NAME, 'no active policies — nothing to do.');
            return;
        }

        Queue_Retention_Policy__mdt first = actives.remove(0);
        Integer chunk = s.ChunkSize__c != null ? Integer.valueOf(s.ChunkSize__c) : 2000;

        log.info(JOB_NAME, 'starting cycle; ' + (actives.size() + 1) + ' active policies; chunk=' + chunk);

        Database.executeBatch(
            new QueueRetentionBatch(first, actives, 'SCHEDULED', UserInfo.getUserId(), 0),
            chunk
        );
    }

    /**
     * @description Register this job with the default daily-02:00 cron.
     */
    public static void start () {
        start(DEFAULT_CRON);
    }

    /**
     * @description Register this job with a custom cron expression.
     * Used by the Admin Console when admins want to override the
     * default cadence without redeploying.
     * @param cronExpression Valid Salesforce cron (e.g. `0 30 1 * * ?`).
     */
    public static void start (String cronExpression) {
        try {
            System.schedule(JOB_NAME + ' ' + Datetime.now().getTime(), cronExpression, new JobQueueRetention());
        } catch (Exception e) {
            LoggerFactory.getInstance().error(JOB_NAME,
                'Failed to schedule with cron "' + cronExpression + '": ' + e.getMessage(), e);
            throw e;
        }
    }

    /**
     * @description Abort every registered instance of this job.
     */
    public static void abort () {
        for (CronTrigger t : [SELECT Id, CronJobDetail.Name FROM CronTrigger WHERE CronJobDetail.Name LIKE :(JOB_NAME + '%')]) {
            System.abortJob(t.Id);
        }
    }
}
