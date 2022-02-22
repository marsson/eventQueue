/**
 * @author: Eduardo Ribeiro de Carvalho - @ercarval
*/
@isTest
private class JobOldQueuedEventsTest {

    @isTest
    static void testPendingEvents() {
        // Given
//        EventQueueFixtureFactory.createEventConfigForEvent ('MOCK_LOG', 'MockCommandLogTrace');

        EventQueue event = new EventBuilder()
        .createOutboundEventFor('EventUnitTest')
        .withReceiver('SALESFORCE')
        .forObjectId( '801Q00000006FA8IAM' )
        .withInternalId( '801Q00000006FA8IAM' )
        .withBusinessDocumentNumber ( '234213' )
        .withBusinessDocumentCorrelatedNumber ( '234213, 324425' )
        .withPayload( EventQueueFixtureFactory.getOrderInboundResultFromJson() )
        .buildEvent();

        // When
        Test.startTest();

        // Then
        JobOldQueuedEvents schedule = new JobOldQueuedEvents();
        schedule.execute(null);

        Test.stopTest();

    }

    @isTest
    static void testScheduleJob() {

        Test.startTest();
        ScheduleHelper.jobCountForTest = 210;
        JobOldQueuedEvents.start();
        JobOldQueuedEvents.abort();

        Test.stopTest();

    }


}