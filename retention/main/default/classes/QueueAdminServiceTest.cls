@isTest
private class QueueAdminServiceTest {

    @isTest
    static void overviewReturnsStatusBreakdownAndSettingFlags () {
        QueueAdminTestFactory.makeAdminSetting(true, false);
        QueueAdminTestFactory.makeQueueRows('DELIVERED', 3);
        QueueAdminTestFactory.makeQueueRows('ERROR', 2);

        Test.startTest();
        QueueAdminService.OverviewDTO o = QueueAdminService.getOverview();
        Test.stopTest();

        System.assertEquals(true, o.retentionEnabled);
        System.assertEquals(false, o.globalDryRun);
        System.assertEquals(2, o.statusBreakdown.size(), 'two statuses present');
    }

    @isTest
    static void listPoliciesJoinsLatestLog () {
        QueueRetentionPolicyProvider.setMock(new List<Queue_Retention_Policy__mdt>{
            QueueAdminTestFactory.makePolicy('P1', 'DELIVERED', 30, true)
        });
        QueueAdminTestFactory.makePurgeLog('P1', 'SUCCESS', 7);

        Test.startTest();
        List<QueueAdminService.PolicyDTO> policies = QueueAdminService.listPolicies();
        Test.stopTest();

        System.assertEquals(1, policies.size());
        System.assertEquals('SUCCESS', policies[0].lastRunStatus);
        System.assertEquals(7, policies[0].lastRunDeleted);
    }

    @isTest
    static void runPolicyNowEnqueuesBatch () {
        QueueAdminTestFactory.makeAdminSetting(true, false);
        QueueRetentionPolicyProvider.setMock(new List<Queue_Retention_Policy__mdt>{
            QueueAdminTestFactory.makePolicy('P1', 'DELIVERED', 1, true)
        });

        Test.startTest();
        Id jobId = QueueAdminService.runPolicyNow('P1', false);
        Test.stopTest();

        System.assertNotEquals(null, jobId, 'batch enqueued');
    }

    @isTest
    static void runPolicyNowWithUnknownPolicyThrows () {
        QueueRetentionPolicyProvider.setMock(new List<Queue_Retention_Policy__mdt>());
        Exception caught;
        try {
            Test.startTest();
            QueueAdminService.runPolicyNow('DoesNotExist', false);
            Test.stopTest();
        } catch (AuraHandledException e) {
            caught = e;
        }
        System.assertNotEquals(null, caught);
    }

    @isTest
    static void previewCountsMatches () {
        QueueAdminTestFactory.makeAdminSetting(true, false);
        QueueRetentionPolicyProvider.setMock(new List<Queue_Retention_Policy__mdt>{
            QueueAdminTestFactory.makePolicy('P1', 'DELIVERED', 1, true)
        });
        List<Queue__c> rows = QueueAdminTestFactory.makeQueueRows('DELIVERED', 4);
        QueueAdminTestFactory.ageRowsBackward(rows, 5);

        Test.startTest();
        Integer n = QueueAdminService.previewPolicyMatch('P1');
        Test.stopTest();

        System.assertEquals(4, n);
    }

    @isTest
    static void scheduleStatusIncludesAllFourJobs () {
        Test.startTest();
        List<QueueAdminService.ScheduleDTO> out = QueueAdminService.getScheduleStatus();
        Test.stopTest();

        System.assertEquals(4, out.size(), 'all four Job* classes reported');
        Set<String> names = new Set<String>();
        for (QueueAdminService.ScheduleDTO d : out) names.add(d.className);
        System.assert(names.contains('JobQueueRetention'));
        System.assert(names.contains('JobPendingEvents'));
        System.assert(names.contains('JobOldQueuedEvents'));
        System.assert(names.contains('JobRetryEventProcessor'));
    }

    @isTest
    static void startJobWhitelistBlocksUnknownNames () {
        Exception caught;
        try {
            Test.startTest();
            QueueAdminService.startJob('EvilJob', null);
            Test.stopTest();
        } catch (AuraHandledException e) {
            caught = e;
        }
        System.assertNotEquals(null, caught);
    }

    @isTest
    static void classExtendsRecognizesBlank () {
        System.assertEquals(true, QueueAdminService.classExtends('', 'AbstractNotifier'));
        System.assertEquals(true, QueueAdminService.classExtends(null, 'AbstractLogger'));
    }

    @isTest
    static void classExtendsRejectsUnknown () {
        System.assertEquals(false, QueueAdminService.classExtends('NotARealClass', 'AbstractNotifier'));
    }

    @isTest
    static void classExtendsAcceptsValid () {
        System.assertEquals(true, QueueAdminService.classExtends('DebugLogger', 'AbstractLogger'));
    }

    @isTest
    static void getAllSettingsReturnsQueueAdminOnly () {
        QueueAdminTestFactory.makeAdminSetting(true, false);

        Test.startTest();
        QueueAdminService.SettingsDTO s = QueueAdminService.getAllSettings();
        Test.stopTest();

        System.assertNotEquals(null, s.queueAdmin);
    }

    @isTest
    static void listNotifierRegistrationsReturnsInsertedRows () {
        insert new Notifier_Registration__c(ClassName__c = 'FakeClassA', IsActive__c = true);
        insert new Notifier_Registration__c(ClassName__c = 'FakeClassB', IsActive__c = false);

        Test.startTest();
        List<Notifier_Registration__c> rows = QueueAdminService.listNotifierRegistrations();
        Test.stopTest();

        System.assertEquals(2, rows.size());
    }

    @isTest
    static void listLoggerRegistrationsReturnsInsertedRows () {
        insert new Logger_Registration__c(ClassName__c = 'DebugLogger', IsActive__c = true);

        Test.startTest();
        List<Logger_Registration__c> rows = QueueAdminService.listLoggerRegistrations();
        Test.stopTest();

        System.assertEquals(1, rows.size());
        System.assertEquals('DebugLogger', rows[0].ClassName__c);
    }

    @isTest
    static void listEventConfigurationsReturnsMdt () {
        Test.startTest();
        List<QueueAdminService.EventConfigurationDTO> configs = QueueAdminService.listEventConfigurations();
        Test.stopTest();

        System.assertNotEquals(null, configs, 'should return list — never null, even if empty');
    }
}
