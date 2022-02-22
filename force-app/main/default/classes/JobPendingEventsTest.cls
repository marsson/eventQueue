/**
 * @author: Eduardo Ribeiro de Carvalho - @ercarval
*/
@isTest
private class JobPendingEventsTest {
    @isTest
    static void testPendingEvents() {

        EventQueue event = new EventBuilder()
        .createOutboundEventFor('EventUnitTest')
        .withReceiver('SALESFORCE')
        .withStatus(EventQueueStatusType.WAITING.name())
        .forObjectId( '801Q00000006FA8IAM' )
        .withInternalId( '801Q00000006FA8IAM' )
        .withBusinessDocumentNumber ( '234213' )
        .withBusinessDocumentCorrelatedNumber ( '234213, 324425' )
        .withPayload( EventQueueFixtureFactory.getOrderInboundResultFromJson() )
        .buildEvent();

        // When
        Test.startTest();

        // Then
        JobPendingEvents sched = new JobPendingEvents();
        sched.execute(null);

        Test.stopTest();

    }

    @isTest
    static void testScheduleJob() {

        Test.startTest();
        ScheduleHelper.jobCountForTest = 100;
        JobPendingEvents.start();
        JobPendingEvents.abort();

        Test.stopTest();

    }

}