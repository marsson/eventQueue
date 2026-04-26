@isTest
private class NotifierFactoryTest {

    public class CapturingNotifier extends AbstractNotifier {
        public NotificationEvent lastEvent;
        public override void notify (NotificationEvent evt) {
            this.lastEvent = evt;
        }
    }

    @isTest
    static void noRegistrationsReturnsNull () {
        Test.startTest();
        AbstractNotifier n = NotifierFactory.createInstance();
        Test.stopTest();

        System.assertEquals(null, n, 'no registrations → silent');
    }

    @isTest
    static void inactiveRegistrationsReturnNull () {
        insert new Notifier_Registration__c(ClassName__c = 'NotifierFactoryTest.CapturingNotifier', IsActive__c = false);

        Test.startTest();
        AbstractNotifier n = NotifierFactory.createInstance();
        Test.stopTest();

        System.assertEquals(null, n, 'inactive rows are ignored');
    }

    @isTest
    static void unknownClassIsSkippedNotThrown () {
        insert new Notifier_Registration__c(ClassName__c = 'DoesNotExistNotifier', IsActive__c = true);

        Test.startTest();
        AbstractNotifier n = NotifierFactory.createInstance();
        Test.stopTest();

        System.assertEquals(null, n, 'unknown class resolves to null, factory never throws');
    }

    @isTest
    static void singleActiveReturnsBareInstance () {
        insert new Notifier_Registration__c(ClassName__c = 'NotifierFactoryTest.CapturingNotifier', IsActive__c = true);

        Test.startTest();
        AbstractNotifier n = NotifierFactory.createInstance();
        Test.stopTest();

        System.assert(n instanceof CapturingNotifier, 'single active returns the notifier directly — no composite wrapping');
    }

    @isTest
    static void multipleActiveReturnsComposite () {
        insert new Notifier_Registration__c(ClassName__c = 'NotifierFactoryTest.CapturingNotifier', IsActive__c = true);
        insert new Notifier_Registration__c(ClassName__c = 'NotifierFactoryTest.CapturingNotifier', IsActive__c = true);

        Test.startTest();
        AbstractNotifier n = NotifierFactory.createInstance();
        Test.stopTest();

        System.assert(n instanceof CompositeNotifier, 'multiple active → CompositeNotifier');
    }

    @isTest
    static void mockOverridesResolution () {
        CapturingNotifier mock = new CapturingNotifier();
        NotifierFactory.setMock(mock);

        Test.startTest();
        AbstractNotifier n = NotifierFactory.createInstance();
        Test.stopTest();

        System.assert(n === mock, 'mock returned regardless of registration rows');
    }

    @isTest
    static void compositeFansOutToAllChildren () {
        CapturingNotifier a = new CapturingNotifier();
        CapturingNotifier b = new CapturingNotifier();
        CompositeNotifier c = new CompositeNotifier(new List<AbstractNotifier>{ a, b });

        NotificationEvent evt = new NotificationEvent();
        evt.source = 'TEST';

        Test.startTest();
        c.notify(evt);
        Test.stopTest();

        System.assertEquals('TEST', a.lastEvent.source, 'child A received the event');
        System.assertEquals('TEST', b.lastEvent.source, 'child B received the event');
    }
}
