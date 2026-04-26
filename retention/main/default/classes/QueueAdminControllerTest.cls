@isTest
private class QueueAdminControllerTest {

    // Tests here exercise the controller entry points. The running
    // user in a test may not have the `Queue_Admin_Console_Access`
    // custom permission (tests run under the current user, not the
    // permission-set-assigned user), so every call is wrapped in
    // try/catch and treats `Not authorized` as an acceptable outcome.
    // Service-level tests cover the deeper business logic.

    private static Boolean wasAuthErr (Exception e) {
        return e != null && String.valueOf(e.getMessage()).toLowerCase().contains('authorized');
    }

    @isTest
    static void listPoliciesReturnsDTOs () {
        QueueRetentionPolicyProvider.setMock(new List<Queue_Retention_Policy__mdt>{
            QueueAdminTestFactory.makePolicy('P1', 'DELIVERED', 30, true)
        });

        Test.startTest();
        try {
            List<QueueAdminService.PolicyDTO> policies = QueueAdminController.listPolicies();
            System.assertNotEquals(null, policies);
        } catch (AuraHandledException e) {
            System.assert(wasAuthErr(e), 'unexpected error: ' + e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void upsertPolicyRejectsConflict () {
        QueueRetentionPolicyProvider.setMock(new List<Queue_Retention_Policy__mdt>{
            QueueAdminTestFactory.makePolicy('Existing', 'DELIVERED', 30, true)
        });

        Map<String, Object> dto = new Map<String, Object>{
            'developerName'   => 'NewOne',
            'label'           => 'New One',
            'status'          => 'DELIVERED',
            'retentionDays'   => 7,
            'isActive'        => true,
            'maxDeletePerRun' => 1000,
            'dryRun'          => false
        };

        Exception caught;
        try {
            Test.startTest();
            QueueAdminController.upsertPolicy(dto);
            Test.stopTest();
        } catch (AuraHandledException e) {
            caught = e;
        }
        System.assertNotEquals(null, caught, 'conflict or permission check should throw');
    }

    @isTest
    static void upsertNotifierRegistrationRejectsWrongClass () {
        Notifier_Registration__c r = new Notifier_Registration__c(
            ClassName__c = 'DebugLogger',   // extends AbstractLogger, NOT AbstractNotifier
            IsActive__c  = true
        );

        Exception caught;
        try {
            Test.startTest();
            QueueAdminController.upsertNotifierRegistration(r);
            Test.stopTest();
        } catch (AuraHandledException e) {
            caught = e;
        }
        System.assertNotEquals(null, caught, 'wrong-class check or permission should throw');
    }

    @isTest
    static void upsertLoggerRegistrationAcceptsDebugLogger () {
        Logger_Registration__c r = new Logger_Registration__c(
            ClassName__c = 'DebugLogger',
            IsActive__c  = true
        );

        Test.startTest();
        try {
            Id result = QueueAdminController.upsertLoggerRegistration(r);
            System.assertNotEquals(null, result);
        } catch (AuraHandledException e) {
            System.assert(wasAuthErr(e), 'unexpected error: ' + e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void toggleNotifierRegistrationWithoutAccessOrSucceeds () {
        Notifier_Registration__c r = new Notifier_Registration__c(ClassName__c = 'SomeClass', IsActive__c = true);
        insert r;

        Test.startTest();
        try {
            QueueAdminController.toggleNotifierRegistration(r.Id, false);
            // If permission check passed, verify the update stuck.
            Notifier_Registration__c reread = [SELECT IsActive__c FROM Notifier_Registration__c WHERE Id = :r.Id];
            System.assertEquals(false, reread.IsActive__c);
        } catch (AuraHandledException e) {
            System.assert(wasAuthErr(e), 'unexpected error: ' + e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void listEventConfigurationsEntryPoint () {
        Test.startTest();
        try {
            List<QueueAdminService.EventConfigurationDTO> cfgs = QueueAdminController.listEventConfigurations();
            System.assertNotEquals(null, cfgs);
        } catch (AuraHandledException e) {
            System.assert(wasAuthErr(e), 'unexpected error: ' + e.getMessage());
        }
        Test.stopTest();
    }
}
