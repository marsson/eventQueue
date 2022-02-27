/**
 *
 * @author: Eduardo Ribeiro de Carvalho - @ercarval
 * Service Class (Decorator Pattern)
 * Should be allowed to have a bunch of public methods
 */

@SuppressWarnings('PMD.ExcessivePublicCount')
public with sharing class EventBuilder {

    private Queue__c event;

    public EventBuilder createOutboundEventFor(String eventName) {
        return createEventFor(eventName)
               .usingRetryStrategy()
               .withSender('SALESFORCE');
    }

    public EventBuilder createEventFor(String eventName) {
        event = new Queue__c();
        return createEventBaseOn (event, eventName);
    }

    public EventBuilder createEventFor(EventType eventName) {
        return createEventFor (eventName.name());
    }

    public EventBuilder createEventBaseOn(Queue__c event, String eventName ) {
        this.event = event;
        this.event.eventName__c = eventName;
        this.event.status__c = EventQueueStatusType.QUEUED.name();
        return this;
    }

    public EventBuilder forEvent(String eventName) {
        event.eventName__c = eventName;
        return this;
    }

    public EventBuilder forObjectId (String id) {
        event.objectId__c = id;
        return this;
    }

    public EventBuilder usingRetryStrategy () {
        event.retryCount__c = 10;
        return this;
    }

    public EventBuilder disablingRetryStrategy () {
        event.retryCount__c = 0;
        event.IsRetryDisabled__c = true;
        return this;
    }

    public EventBuilder withRetryCount(Integer count) {
        event.retryCount__c = count;
        return this;
    }

    public EventBuilder withSender (String sender) {
        event.sender__c = sender;
        return this;
    }

    public EventBuilder correlatedTo (String eventId) {
        event.parentEvent__c = eventId;
        return this;
    }

    public EventBuilder withSameDocumentNumberForAllIdentifiers (String documentNumber ) {

        return this.forObjectId(documentNumber)
               .withBusinessDocumentNumber (documentNumber)
               .withBusinessDocumentCorrelatedNumber (documentNumber)
               .withInternalID(documentNumber);
    }

    public EventBuilder withReceiver (String receiver) {
        event.receiver__c = receiver;
        return this;
    }

    public EventBuilder withPayload (String payload) {
        event.payload__c = payload;
        return this;
    }

    public EventBuilder withStatus (String status) {
        event.status__c = status;
        return this;
    }

    public EventBuilder withStatusMessage (String message) {
        event.statusMessage__c = message;
        return this;
    }

    public EventBuilder withBusinessDocumentNumber (String businessDocumentNumber) {
        event.businessDocument__c = businessDocumentNumber;
        return this;
    }

    public EventBuilder withBusinessDocumentCorrelatedNumber (String businessDocumentCorrelatedNumber) {
        event.businessDocumentCorrelatedNumber__c  = businessDocumentCorrelatedNumber;
        return this;
    }

    public EventBuilder withInternalID (String internalId) {
        event.internalId__c  = internalId;
        return this;
    }

    public Queue__c build() {
        return event;
    }


    public EventQueue buildEvent() {
        return new EventQueue (event);
    }

    public EventQueue buildAndSave() {
        EventQueue event = new EventQueue (event);
        event.save();
        return event;
    }

    public EventQueue buildExternalEvent() {

        EventQueue external =  new EventQueue ();

        external.eventName = event.eventName__c;
        external.internalId = event.internalId__c;
        external.sender = event.sender__c;
        external.receiver = event.receiver__c;
        external.businessDocumentNumber = event.businessDocument__c;
        external.businessDocumentCorrelatedNumber = event.businessDocumentCorrelatedNumber__c;

        return external;
    }

}
