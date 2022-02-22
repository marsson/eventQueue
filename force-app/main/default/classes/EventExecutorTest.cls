/**
 * @author: Eduardo Ribeiro de Carvalho - @ercarval
 */
@isTest
private class EventExecutorTest {

    @isTest
    static void givenConfiguredEventWhenEnqueuedThenProcessSucessefully() {

//        EventQueueFixtureFactory.createEventConfigForEvent ('MOCK_LOG', 'MockCommandLogTrace');

        EventQueue event = EventQueueFixtureFactory.createBaseEvent('EventUnitTest');
        event.setStatus('WORKFLOW');
        event.setPayload('MegaPayload');
        event.save();

        Test.startTest();

        new EventExecutor ( event.get() ) .execute(null);

        System.debug('\n\n\n\n ------------------------------ ');

        System.debug(event);

        System.assert( event.getStatus() == 'DELIVERED' );

        Test.stopTest();

    }

    @isTest
    static void givenConfiguredEventSWhenEnqueuedThenProcessSucessefully() {

//        EventQueueFixtureFactory.createEventConfigForEvent ('MOCK_LOG', 'MockCommandLogTrace');

        EventQueue event = EventQueueFixtureFactory.createBaseEvent('EventUnitTest');
        event.setStatus('WORKFLOW');
        event.setPayload('MegaPayload');
        event.save();

        Test.startTest();

        new EventExecutor ( new Queue__c [] { event.get() } ) .execute(null);

        System.debug('\n\n\n\n ------------------------------ ');

        System.debug(event);

        System.assert( event.getStatus() == 'DELIVERED' );

        EventExecutor.reprocess ( new Queue__c [] { event.get() } );

        System.assert( event.getStatus() == 'QUEUED' );

        EventExecutor.processPendingEvents();
        EventExecutor.processOldQueuedEvents();
        EventExecutor.processErrorEvents();
        EventQueueActiveRecord.findPendingQueuedEvents (EventQueueStatusType.WORKFLOW, 20);

        Test.stopTest();

    }

}