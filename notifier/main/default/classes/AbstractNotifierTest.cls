@isTest
private class AbstractNotifierTest {

    @isTest
    static void baseNotifyIsNoOp () {
        NotificationEvent evt = new NotificationEvent();
        evt.source    = 'TEST';
        evt.severity  = 'INFO';
        evt.eventType = 'UNIT_TEST';
        evt.title     = 't';
        evt.message   = 'm';

        AbstractNotifier n = new AbstractNotifier();
        Test.startTest();
        n.notify(evt);
        Test.stopTest();

        System.assertEquals('TEST', evt.source, 'event is unchanged by no-op notifier');
    }

    @isTest
    static void eventCtorStampsTimeAndUser () {
        Test.startTest();
        NotificationEvent evt = new NotificationEvent();
        Test.stopTest();

        System.assertNotEquals(null, evt.occurredAt, 'occurredAt auto-set');
        System.assertEquals(UserInfo.getUserId(), evt.userId, 'userId auto-set from UserInfo');
        System.assertNotEquals(null, evt.context, 'context map initialised');
    }
}
