@isTest
private class QueueRetentionPolicyProviderTest {

    @isTest
    static void mockedListIsReturnedUnchanged () {
        List<Queue_Retention_Policy__mdt> mocks = new List<Queue_Retention_Policy__mdt>{
            QueueAdminTestFactory.makePolicy('A', 'DELIVERED', 30, true),
            QueueAdminTestFactory.makePolicy('B', 'ERROR',     365, false)
        };
        QueueRetentionPolicyProvider.setMock(mocks);

        Test.startTest();
        List<Queue_Retention_Policy__mdt> all = QueueRetentionPolicyProvider.getAll();
        List<Queue_Retention_Policy__mdt> actives = QueueRetentionPolicyProvider.getActive();
        Queue_Retention_Policy__mdt found = QueueRetentionPolicyProvider.getByDeveloperName('A');
        Test.stopTest();

        System.assertEquals(2, all.size());
        System.assertEquals(1, actives.size());
        System.assertEquals('A', actives[0].DeveloperName);
        System.assertEquals('A', found.DeveloperName);
    }

    @isTest
    static void getByDevNameUnknownReturnsNull () {
        QueueRetentionPolicyProvider.setMock(new List<Queue_Retention_Policy__mdt>{
            QueueAdminTestFactory.makePolicy('X', 'DELIVERED', 30, true)
        });

        Test.startTest();
        Queue_Retention_Policy__mdt r = QueueRetentionPolicyProvider.getByDeveloperName('Y');
        Test.stopTest();

        System.assertEquals(null, r);
    }

    @isTest
    static void activeConflictDetection () {
        QueueRetentionPolicyProvider.setMock(new List<Queue_Retention_Policy__mdt>{
            QueueAdminTestFactory.makePolicy('Existing', 'DELIVERED', 30, true)
        });

        // Candidate conflicts because another active policy already targets DELIVERED.
        Queue_Retention_Policy__mdt conflict  = QueueAdminTestFactory.makePolicy('New',      'DELIVERED', 7, true);
        Queue_Retention_Policy__mdt ok        = QueueAdminTestFactory.makePolicy('New',      'ERROR',     7, true);
        Queue_Retention_Policy__mdt inactive  = QueueAdminTestFactory.makePolicy('New',      'DELIVERED', 7, false);
        Queue_Retention_Policy__mdt sameDevN  = QueueAdminTestFactory.makePolicy('Existing', 'DELIVERED', 60, true);

        Test.startTest();
        System.assert(QueueRetentionPolicyProvider.hasActiveConflict(conflict));
        System.assert(!QueueRetentionPolicyProvider.hasActiveConflict(ok));
        System.assert(!QueueRetentionPolicyProvider.hasActiveConflict(inactive));
        System.assert(!QueueRetentionPolicyProvider.hasActiveConflict(sameDevN),
            'same DeveloperName editing itself is not a conflict');
        Test.stopTest();
    }
}
