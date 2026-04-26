/**
 * @description Local test fixtures for the retention package.
 * Parallels the existing `EventQueueFixtureFactory` in force-app.
 * Built here because retention tests reach for constructs the core
 * factory doesn't know about (MDT mock policies, purge logs, aged rows).
 */
@isTest
public class QueueAdminTestFactory {

    /**
     * @description Build an in-memory MDT policy record (no insert —
     * MDT DML is blocked in production; tests use
     * `QueueRetentionPolicyProvider.setMock(...)`).
     */
    public static Queue_Retention_Policy__mdt makePolicy (String devName, String status, Integer days, Boolean isActive) {
        return new Queue_Retention_Policy__mdt(
            DeveloperName     = devName,
            Label             = devName,
            Status__c         = status,
            RetentionDays__c  = days,
            IsActive__c       = isActive,
            MaxDeletePerRun__c = 10000,
            DryRun__c         = false
        );
    }

    /**
     * @description Insert N Queue__c rows with a given status. For
     * ageing rows to appear "old" enough for retention to target,
     * callers use `setCreatedDate(id, datetime)` via Test.setCreatedDate().
     */
    public static List<Queue__c> makeQueueRows (String status, Integer count) {
        List<Queue__c> rows = new List<Queue__c>();
        for (Integer i = 0; i < count; i++) {
            rows.add(new Queue__c(
                EventName__c = 'RetentionUnitTest',
                Status__c    = status
            ));
        }
        insert rows;
        return rows;
    }

    /**
     * @description Age inserted rows backward in time so retention
     * cutoffs match them. Uses `Test.setCreatedDate`.
     */
    public static void ageRowsBackward (List<Queue__c> rows, Integer days) {
        Datetime back = System.now().addDays(-days);
        for (Queue__c r : rows) {
            Test.setCreatedDate(r.Id, back);
        }
    }

    /**
     * @description Insert an empty org-default custom setting record
     * (the factory creates one with all defaults; tests can then
     * update the specific fields they care about).
     */
    public static Queue_Admin_Setting__c makeAdminSetting (Boolean enabled, Boolean globalDryRun) {
        Queue_Admin_Setting__c s = new Queue_Admin_Setting__c(
            SetupOwnerId            = UserInfo.getOrganizationId(),
            IsRetentionEnabled__c   = enabled,
            GlobalDryRun__c         = globalDryRun,
            MaxRecordsPerRun__c     = 50000,
            ChunkSize__c            = 2000,
            LogRetentionDays__c     = 90,
            EmptyRecycleBin__c      = false
        );
        insert s;
        return s;
    }

    /**
     * @description Build a purge log record for tests that want to
     * read back the "latest run per policy" aggregates.
     */
    public static Queue_Purge_Log__c makePurgeLog (String policyDev, String status, Integer deleted) {
        Queue_Purge_Log__c l = new Queue_Purge_Log__c(
            PolicyDeveloperName__c = policyDev,
            PolicyLabel__c         = policyDev,
            Status__c              = status,
            RunStartedAt__c        = System.now(),
            RunCompletedAt__c      = System.now(),
            DurationSeconds__c     = 1,
            RecordsEvaluated__c    = deleted,
            RecordsDeleted__c      = deleted,
            RecordsSkipped__c      = 0,
            ChunkCount__c          = 1,
            TriggeredBy__c         = 'MANUAL',
            DeleteStrategy__c      = 'HARD_DELETE',
            RunByUser__c           = UserInfo.getUserId()
        );
        insert l;
        return l;
    }
}
