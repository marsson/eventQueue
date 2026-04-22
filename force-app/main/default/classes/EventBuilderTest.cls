/**
 * @description Tests for `EventBuilder`. Exercises the fluent
 * builder chain end-to-end (`build()` and `buildExternalEvent()`).
 *
 * @author Eduardo Ribeiro de Carvalho - @ercarval
 * @author Heitor Araujo
 * @author Marcelo Marsson
 */
@isTest
public with sharing class EventBuilderTest {

	testMethod
	public static void buildEvent() { 
		
		EventBuilder builder = new EventBuilder();
		builder.createOutboundEventFor( 'SYNC_BACKORDER_OUTBOUND' )
									 .forObjectId( '3213213112321')
									 .withBusinessDocumentNumber ( 'XXXXXXXX' )
									 .withBusinessDocumentCorrelatedNumber( 'XXXXXX' )
									 .withInternalID ('XXXXXXXX')
									 .forEvent('XXXXXXXXXX')
									 .withPayload( 'XXXXXXXX' )
									 .withSender ('EXECUTIVE_CRM')
									 .withReceiver ('EPARTS-REVAMP')
									 .usingRetryStrategy()
									 .disablingRetryStrategy ()
									 .build();
									 
		
		
	}

	testMethod
	public static void buildExternalEvent(){

		EventBuilder builder = new EventBuilder();
		builder.createOutboundEventFor( 'SYNC_BACKORDER_OUTBOUND' )
				.forObjectId( '3213213112321')
				.withBusinessDocumentNumber ( 'XXXXXXXX' )
				.withBusinessDocumentCorrelatedNumber( 'XXXXXX' )
				.withInternalID ('XXXXXXXX')
				.forEvent('XXXXXXXXXX')
				.withPayload( 'XXXXXXXX' )
				.withSender ('EXECUTIVE_CRM')
				.withReceiver ('EPARTS-REVAMP')
				.usingRetryStrategy()
				.disablingRetryStrategy ()
				.build();

		builder.buildExternalEvent();
	}

}