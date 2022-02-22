/**
 *
 * @author: Eduardo Ribeiro de Carvalho - @ercarval
 */
@isTest
public with sharing class EventQueueTest {

    testMethod
    public static void givenKnowEventWhenProcessThisYourStatusIsSucess () {
        //-- fixture
//        EventQueueFixtureFactory.createConfigForMockCommandLogTrace () ;
        EventQueue event = EventQueueFixtureFactory.createBaseEvent ('EventUnitTest' );

        //-- assertion
        event.process();
        System.debug (event.getStackTrace());
        System.assertEquals('DELIVERED', event.getStatus());

    }


    testMethod
    public static void givenUnknowEventWheIsProcessedThenYourStatusIsUnhandled() {

        EventQueue queuedEvent =  EventQueueFixtureFactory.createBaseEvent ('SYNC_XXXXX_OUTBOUND' );
        queuedEvent.process();
        System.assertEquals( 'UNHANDLED', queuedEvent.get().status__c);
    }

    testMethod
    public static void givenValidEventHandle() {

//        EventQueueFixtureFactory.createConfigForMockCommandLogTrace ( ) ;
        EventQueue event  = new EventQueue();
        event.eventName = 'SYNC_XXXXX_OUTBOUND';


    }

    testMethod
    public static void givenValidEventThenProcessThisEvent() {

        EventBuilder builder = new EventBuilder();

        EventQueue event = EventQueueFixtureFactory.createBaseEvent('EventUnitTest');

        Test.startTest();

        event.process();

        event.save();

        event.successfullyProcessedEvent( );
        event.save();

        //event.findAllQueuedEvents(new Set<String>{''+ event.get().id} );
        event.findOne( event.get().id );
        event.findLastEventsByNameAndBusinessDocumentNumber( 'SYNC_XXXX', '9832394328');

        Test.stopTest();


    }

    testmethod
    public static void publishNewEventSuccess() {

        EventQueue event = EventQueueFixtureFactory.createBaseEvent('EventUnitTest');

        Test.startTest();

        event.save();

        System.debug('\n\n\n\n ------------------------------ ');

        System.debug(event);

        Test.stopTest();

    }

    testMethod
    public static void giveEventWithProcessingLogThenCreateAttachmentForThis () {

        EventQueue event = EventQueueFixtureFactory.createBaseEvent('EventUnitTest');

        event.setPayload('MegaPayload');

        event.save();

        Test.startTest();

        event.process();

        event.save();

        String payload = event.getLastAttachedPayloadForEvent();

        System.assert( payload != null );

//        System.assert( event.findAttachmentsForEvent(event.get().id ).size () > 0 );

        System.debug('\n\n\n\n ------------------------------ ');

        System.debug(event);

        Test.stopTest();

    }


    testMethod
    public static void whenEventThrowsExceptionThenCatchAndSaveWithError () {


//        EventQueueFixtureFactory.createEventConfigForEvent ('PROCESS_MOCK_EVENT_EXCEPTION', 'MockThrowsExeceptionCommand');

        EventQueue event = EventQueueFixtureFactory.createBaseEvent('EventUnitTestThrowsException');

        event.save();

        Test.startTest();

        event.process();

        event.postExecute();

        System.debug('\n\n\n\n ------------------------------ ');

        System.assert( event.getStatus() == EventQueueStatusType.ERROR.name() );
        System.assert( event.getStackTrace() != null );

        Test.stopTest();



    }



}