@isTest
public with sharing class EventConsumerTest {

	testmethod
	public static void publishNewEventSuccess() {

	}

	testMethod
	public static void whenSendSeveralEventsSplitEvent() {

		EventQueueFixtureFactory.createBaseEvent ('SYNC_OUTBOUND');

		Test.startTest();

		//Test.setMock ( HttpCalloutMock.class , new OutboundProxyTest());

		List<Queue__c> events = new List<Queue__c>();
		for (Integer i = 0; i < 100 ; i++) {
			EventBuilder builder = new EventBuilder();
			events.add( builder.createOutboundEventFor( 'SYNC_OUTBOUND' )
			            .forObjectId( '3213213112321')
			            .withBusinessDocumentNumber ( 'XXXXXXXX' )
			            .withBusinessDocumentCorrelatedNumber( 'XXXXXX' )
			            .withInternalID ('XXXXXXXX')
			            .withPayload( 'XXXXXXXX' )
			            .withSender ('SALESFORCE')
			            .withReceiver ('RECEIVER')
			            .usingRetryStrategy()
			            .disablingRetryStrategy ()
			            .build());
		}

		insert events;


		Test.stopTest();


	}


}