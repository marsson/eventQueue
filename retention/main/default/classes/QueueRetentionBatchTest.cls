@isTest
private class QueueRetentionBatchTest {

    @isTest
    static void endToEndDeleteAgedRows () {
        QueueAdminTestFactory.makeAdminSetting(true, false);
        Queue_Retention_Policy__mdt p = QueueAdminTestFactory.makePolicy('Delivered_7d', 'DELIVERED', 7, true);

        List<Queue__c> rows = QueueAdminTestFactory.makeQueueRows('DELIVERED', 5);
        QueueAdminTestFactory.ageRowsBackward(rows, 10);

        Test.startTest();
        Database.executeBatch(
            new QueueRetentionBatch(p, new List<Queue_Retention_Policy__mdt>(), 'MANUAL', UserInfo.getUserId(), 0),
            2000
        );
        Test.stopTest();

        Queue_Purge_Log__c log = [
            SELECT Status__c, RecordsDeleted__c, RecordsSkipped__c, ChunkCount__c, DeleteStrategy__c
            FROM Queue_Purge_Log__c
            LIMIT 1
        ];
        System.assertEquals('SUCCESS', log.Status__c);
        System.assertEquals(5, log.RecordsDeleted__c, 'all 5 aged rows deleted');
        System.assertEquals(0, log.RecordsSkipped__c);
        System.assertEquals('HARD_DELETE', log.DeleteStrategy__c);
    }

    @isTest
    static void dryRunCountsButDoesNotDelete () {
        QueueAdminTestFactory.makeAdminSetting(true, false);
        Queue_Retention_Policy__mdt p = QueueAdminTestFactory.makePolicy('Delivered_dry', 'DELIVERED', 1, true);
        p.DryRun__c = true;

        List<Queue__c> rows = QueueAdminTestFactory.makeQueueRows('DELIVERED', 3);
        QueueAdminTestFactory.ageRowsBackward(rows, 5);

        Test.startTest();
        Database.executeBatch(
            new QueueRetentionBatch(p, new List<Queue_Retention_Policy__mdt>(), 'DRY_RUN_MANUAL', UserInfo.getUserId(), 0),
            2000
        );
        Test.stopTest();

        Queue_Purge_Log__c log = [SELECT Status__c, RecordsDeleted__c, RecordsEvaluated__c FROM Queue_Purge_Log__c LIMIT 1];
        System.assertEquals('DRY_RUN', log.Status__c);
        System.assertEquals(0, log.RecordsDeleted__c);
        System.assertEquals(3, log.RecordsEvaluated__c);
        System.assertEquals(3, [SELECT COUNT() FROM Queue__c WHERE Status__c = 'DELIVERED'],
            'rows still present — no DML during dry-run');
    }

    @isTest
    static void globalDryRunOverridesPerPolicy () {
        QueueAdminTestFactory.makeAdminSetting(true, true);  // globalDryRun = true
        Queue_Retention_Policy__mdt p = QueueAdminTestFactory.makePolicy('Delivered_7d', 'DELIVERED', 7, true);
        p.DryRun__c = false;

        List<Queue__c> rows = QueueAdminTestFactory.makeQueueRows('DELIVERED', 2);
        QueueAdminTestFactory.ageRowsBackward(rows, 10);

        Test.startTest();
        Database.executeBatch(
            new QueueRetentionBatch(p, new List<Queue_Retention_Policy__mdt>(), 'MANUAL', UserInfo.getUserId(), 0),
            2000
        );
        Test.stopTest();

        Queue_Purge_Log__c log = [SELECT Status__c FROM Queue_Purge_Log__c LIMIT 1];
        System.assertEquals('DRY_RUN', log.Status__c, 'global dry-run overrides the policy flag');
        System.assertEquals(2, [SELECT COUNT() FROM Queue__c WHERE Status__c = 'DELIVERED']);
    }

    @isTest
    static void globalCapSkipsOverflowPolicy () {
        Queue_Admin_Setting__c s = QueueAdminTestFactory.makeAdminSetting(true, false);
        s.MaxRecordsPerRun__c = 5;
        update s;

        Queue_Retention_Policy__mdt p = QueueAdminTestFactory.makePolicy('Delivered_1d', 'DELIVERED', 1, true);

        Test.startTest();
        // Simulate that 5 rows were already deleted earlier this cycle — cap hit.
        Database.executeBatch(
            new QueueRetentionBatch(p, new List<Queue_Retention_Policy__mdt>(), 'SCHEDULED', UserInfo.getUserId(), 5),
            2000
        );
        Test.stopTest();

        Queue_Purge_Log__c log = [SELECT Status__c, RecordsDeleted__c FROM Queue_Purge_Log__c LIMIT 1];
        System.assertEquals('SKIPPED_GLOBAL_CAP', log.Status__c);
        System.assertEquals(0, log.RecordsDeleted__c);
    }

    @isTest
    static void emptyQueueProducesSuccessLog () {
        QueueAdminTestFactory.makeAdminSetting(true, false);
        Queue_Retention_Policy__mdt p = QueueAdminTestFactory.makePolicy('Delivered_7d', 'DELIVERED', 7, true);

        Test.startTest();
        Database.executeBatch(
            new QueueRetentionBatch(p, new List<Queue_Retention_Policy__mdt>(), 'MANUAL', UserInfo.getUserId(), 0),
            2000
        );
        Test.stopTest();

        Queue_Purge_Log__c log = [SELECT Status__c, RecordsDeleted__c, RecordsEvaluated__c FROM Queue_Purge_Log__c LIMIT 1];
        System.assertEquals('SUCCESS', log.Status__c);
        System.assertEquals(0, log.RecordsDeleted__c);
        System.assertEquals(0, log.RecordsEvaluated__c);
    }
}
