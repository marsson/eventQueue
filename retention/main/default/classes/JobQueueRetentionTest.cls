@isTest
private class JobQueueRetentionTest {

    @isTest
    static void disabledShortCircuits () {
        QueueAdminTestFactory.makeAdminSetting(false, false);
        QueueRetentionPolicyProvider.setMock(new List<Queue_Retention_Policy__mdt>{
            QueueAdminTestFactory.makePolicy('Delivered_30d', 'DELIVERED', 30, true)
        });

        Test.startTest();
        new JobQueueRetention().execute(null);
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM Queue_Purge_Log__c],
            'no logs should be written when master switch is off');
    }

    @isTest
    static void noActivePoliciesIsANoOp () {
        QueueAdminTestFactory.makeAdminSetting(true, false);
        QueueRetentionPolicyProvider.setMock(new List<Queue_Retention_Policy__mdt>{
            QueueAdminTestFactory.makePolicy('Delivered_30d', 'DELIVERED', 30, false)  // inactive
        });

        Test.startTest();
        new JobQueueRetention().execute(null);
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM Queue_Purge_Log__c],
            'no logs when zero active policies');
    }

    @isTest
    static void startAndAbortRegisterCronJob () {
        Test.startTest();
        JobQueueRetention.start();
        Integer scheduled = [SELECT COUNT() FROM CronTrigger WHERE CronJobDetail.Name LIKE 'JobQueueRetention%'];
        System.assert(scheduled >= 1, 'start() registered a cron job');

        JobQueueRetention.abort();
        Test.stopTest();

        Integer after = [SELECT COUNT() FROM CronTrigger WHERE CronJobDetail.Name LIKE 'JobQueueRetention%'];
        System.assertEquals(0, after, 'abort() cleared every registered job');
    }

    @isTest
    static void startWithCustomCron () {
        Test.startTest();
        JobQueueRetention.start('0 30 3 * * ?');
        Test.stopTest();

        List<CronTrigger> jobs = [SELECT Id, CronExpression FROM CronTrigger WHERE CronJobDetail.Name LIKE 'JobQueueRetention%'];
        System.assertEquals(1, jobs.size(), 'one registered');
        System.assertEquals('0 30 3 * * ?', jobs[0].CronExpression);
    }
}
