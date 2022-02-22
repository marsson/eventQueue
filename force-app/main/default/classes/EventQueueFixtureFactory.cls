/**
 *
 * @author: Eduardo Ribeiro de Carvalho - @ercarval
 */
@isTest
public with sharing class EventQueueFixtureFactory {

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

	public static EventQueue newB2dEventQueueFromJson() {

		String eventJson = '{"sender": "B2D","receiver": "SALESFORCE","internalId": "20170103122001","eventName": "B2D_CREATE_OPPORTUNITY_INBOUND","businessDocumentNumber": "CustomerPO-03012017","businessDocumentCorrelatedNumber": "CustomerPO-03012017"}';

		return (EventQueue) JSON.deserialize(eventJson, EventQueue.class);
	}

	public static EventQueue newB2bEventQueueFromJson() {

		String eventJson = '{"sender": "B2B","receiver": "SALESFORCE","internalId": "20170606120101","eventName": "B2B_CREATE_OPPORTUNITY_INBOUND","businessDocumentNumber": "4500510522","businessDocumentCorrelatedNumber": "4500510522"}';

		return (EventQueue) JSON.deserialize(eventJson, EventQueue.class);
	}

	public static String getOrderInboundResultFromJson() {
		return '{"returnRS":[{"messageType":"S","messageText":"SALES_HEADER_IN processado com Ãªxito","messageNumber":"233"},{"messageType":"S","messageText":"SALES_ITEM_IN processado com Ãªxito","messageNumber":"233"},{"messageType":"S","messageText":"SALES_CONDITIONS_IN processado com Ãªxito","messageNumber":"233"},{"messageType":"W","messageText":"Documento de vendas e distrib.ainda incompleto -> completar","messageNumber":"555"},{"messageType":"W","messageText":"Em item 000010 considerar a unidade de medida de remessa: 5,000 PC","messageNumber":"081"},{"messageType":"S","messageText":"DX OV Normal 2669678 foi gravado(a)","messageNumber":"311"}],"numberOfGeneratedDocument":"0002669678"}';
	}

	public static Event_Configuration__mdt findEventConfigMetadata(){
		return [SELECT Id, MasterLabel, CommandClassName__c, DisableDispatcher__c, Method__c, NamedCredencial__c FROM Event_Configuration__mdt LIMIT 1];
	}


}