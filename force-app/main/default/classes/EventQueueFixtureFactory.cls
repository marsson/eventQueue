/**
 * @description Test fixture factory. Provides canned `EventQueue`
 * instances and sample JSON payloads used by the Apex test suite
 * to avoid repeating boilerplate builder chains.
 *
 * @author Eduardo Ribeiro de Carvalho - @ercarval
 * @author Heitor Araujo
 * @author Marcelo Marsson
 */
@isTest
public with sharing class EventQueueFixtureFactory {

	/**
	 * @description Build a pre-populated `EventQueue` for the given
	 * event name with default business-document, sender/receiver,
	 * internal id, and a 10-attempt retry budget.
	 * @param eventName Logical event type (must match an
	 *                  `Event_Configuration__mdt` for the dispatcher
	 *                  to act on it).
	 * @return A ready-to-process `EventQueue`.
	 */
	public static EventQueue createBaseEvent (String eventName) {
		EventBuilder builder = new EventBuilder();
		return new EventQueue ( builder.createEventFor( eventName )
		                        .withBusinessDocumentNumber ('BIZDOC')
		                        .withBusinessDocumentCorrelatedNumber( 'BIZDOC' )
		                        .withInternalID ('1234')
		                        .withSender ('SENDER')
		                        .withReceiver ('RECEIVER')
		                        .usingRetryStrategy ()
		                        .build() );

	}

	/**
	 * @description Build an `EventQueue` populated only via its
	 * SOAP-facing (webservice) fields. Not persisted.
	 * @return A non-persisted external-facing `EventQueue`.
	 */
	public static EventQueue createExternalEvent () {
		EventQueue event  = new EventQueue();
		event.payload = 'Payload';
		event.retryCount = '5';
		event.id = '1312312312';
		event.eventName = 'eventName';
		event.outboundUrl = 'http://xyz';
		event.internalId = '5';
		event.sender = '5';
		event.receiver = '5';
		event.status = '5';
		event.statusMessage = '5';
		event.businessDocumentNumber = '5';
		event.businessDocumentCorrelatedNumber = '5';

		return event;
	}

	/**
	 * @description Deserialise a canned B2D inbound event payload.
	 * @return An `EventQueue` populated from the fixture JSON.
	 */
	public static EventQueue newB2dEventQueueFromJson() {

		String eventJson = '{"sender": "B2D","receiver": "SALESFORCE","internalId": "20170103122001","eventName": "B2D_CREATE_OPPORTUNITY_INBOUND","businessDocumentNumber": "CustomerPO-03012017","businessDocumentCorrelatedNumber": "CustomerPO-03012017"}';

		return (EventQueue) JSON.deserialize(eventJson, EventQueue.class);
	}

	/**
	 * @description Deserialise a canned B2B inbound event payload.
	 * @return An `EventQueue` populated from the fixture JSON.
	 */
	public static EventQueue newB2bEventQueueFromJson() {

		String eventJson = '{"sender": "B2B","receiver": "SALESFORCE","internalId": "20170606120101","eventName": "B2B_CREATE_OPPORTUNITY_INBOUND","businessDocumentNumber": "4500510522","businessDocumentCorrelatedNumber": "4500510522"}';

		return (EventQueue) JSON.deserialize(eventJson, EventQueue.class);
	}

	/**
	 * @description Canned response body for tests that simulate an
	 * inbound order-processing result.
	 * @return Sample response JSON as a String.
	 */
	public static String getOrderInboundResultFromJson() {
		return '{"returnRS":[{"messageType":"S","messageText":"SALES_HEADER_IN processado com Ãªxito","messageNumber":"233"},{"messageType":"S","messageText":"SALES_ITEM_IN processado com Ãªxito","messageNumber":"233"},{"messageType":"S","messageText":"SALES_CONDITIONS_IN processado com Ãªxito","messageNumber":"233"},{"messageType":"W","messageText":"Documento de vendas e distrib.ainda incompleto -> completar","messageNumber":"555"},{"messageType":"W","messageText":"Em item 000010 considerar a unidade de medida de remessa: 5,000 PC","messageNumber":"081"},{"messageType":"S","messageText":"DX OV Normal 2669678 foi gravado(a)","messageNumber":"311"}],"numberOfGeneratedDocument":"0002669678"}';
	}

	/**
	 * @description Query one `Event_Configuration__mdt` row. Used
	 * by tests that need a "known-good" configuration record.
	 * @return An existing `Event_Configuration__mdt` (the first
	 *         returned by SOQL).
	 */
	public static Event_Configuration__mdt findEventConfigMetadata(){
		return [SELECT Id, MasterLabel, CommandClassName__c, DisableDispatcher__c, Method__c, NamedCredencial__c FROM Event_Configuration__mdt LIMIT 1];
	}


}
