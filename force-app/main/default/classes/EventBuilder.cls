/**
 * @description Fluent builder for `Queue__c` (and, in convenience
 * methods, `EventQueue`). Callers chain `.withXxx(...)` setters
 * and finish with `build()` / `buildEvent()` / `buildAndSave()`.
 *
 * Example:
 * <pre>
 * new EventBuilder()
 *     .createOutboundEventFor('BOOK_OUTBOUND_SERVICE')
 *     .forObjectId(order.Id)
 *     .withBusinessDocumentNumber(order.OrderNumber)
 *     .withPayload(JSON.serialize(dto))
 *     .buildAndSave();
 * </pre>
 *
 * `createOutboundEventFor` sets sender='SALESFORCE' and
 * retryCount=10 by default.
 *
 * PMD suppression: the fluent style exceeds PMD's default public
 * count threshold by design.
 *
 * @author Eduardo Ribeiro de Carvalho - @ercarval
 * @author Heitor Araujo
 * @author Marcelo Marsson
 */

@SuppressWarnings('PMD.ExcessivePublicCount')
public with sharing class EventBuilder {

    private Queue__c event;

    /**
     * @description Start a new event intended to go out to an
     * external system. Defaults: `sender='SALESFORCE'`,
     * `retryCount=10`.
     * @param eventName Logical event-type name (must match an
     *                  `Event_Configuration__mdt` label).
     * @return The builder, for chaining.
     */
    public EventBuilder createOutboundEventFor(String eventName) {
        return createEventFor(eventName)
               .usingRetryStrategy()
               .withSender('SALESFORCE');
    }

    /**
     * @description Start a new event with the given type.
     * @param eventName Logical event-type name.
     * @return The builder, for chaining.
     */
    public EventBuilder createEventFor(String eventName) {
        event = new Queue__c();
        return createEventBaseOn (event, eventName);
    }

    /**
     * @description Convenience overload using the `EventType` enum.
     * @param eventName Enum value corresponding to the event type.
     * @return The builder, for chaining.
     */
    public EventBuilder createEventFor(EventType eventName) {
        return createEventFor (eventName.name());
    }

    /**
     * @description Re-initialise the builder around an existing
     * `Queue__c`. Sets `Status__c = QUEUED`.
     * @param event A pre-populated `Queue__c` to take ownership of.
     * @param eventName Logical event-type name.
     * @return The builder, for chaining.
     */
    public EventBuilder createEventBaseOn(Queue__c event, String eventName ) {
        this.event = event;
        this.event.eventName__c = eventName;
        this.event.status__c = EventQueueStatusType.QUEUED.name();
        return this;
    }

    /**
     * @description Override the event type after construction.
     * @param eventName New event-type name.
     * @return The builder, for chaining.
     */
    public EventBuilder forEvent(String eventName) {
        event.eventName__c = eventName;
        return this;
    }

    /**
     * @description Associate the event with a Salesforce record
     * (stored in `ObjectId__c`).
     * @param id The Salesforce record Id.
     * @return The builder, for chaining.
     */
    public EventBuilder forObjectId (String id) {
        event.objectId__c = id;
        return this;
    }

    /**
     * @description Enable the default retry budget
     * (`retryCount = 10`).
     * @return The builder, for chaining.
     */
    public EventBuilder usingRetryStrategy () {
        event.retryCount__c = 10;
        return this;
    }

    /**
     * @description Hard-disable retries for this event
     * (`retryCount = 0`, `IsRetryDisabled = true`).
     * @return The builder, for chaining.
     */
    public EventBuilder disablingRetryStrategy () {
        event.retryCount__c = 0;
        event.IsRetryDisabled__c = true;
        return this;
    }

    /**
     * @description Set an explicit retry budget.
     * @param count Number of technical-error retries to allow.
     * @return The builder, for chaining.
     */
    public EventBuilder withRetryCount(Integer count) {
        event.retryCount__c = count;
        return this;
    }

    /**
     * @description Set the sender system.
     * @param sender Sender identifier.
     * @return The builder, for chaining.
     */
    public EventBuilder withSender (String sender) {
        event.sender__c = sender;
        return this;
    }

    /**
     * @description Link this event to a parent `Queue__c` via
     * `parentEvent__c`.
     * @param eventId Parent `Queue__c.Id`.
     * @return The builder, for chaining.
     */
    public EventBuilder correlatedTo (String eventId) {
        event.parentEvent__c = eventId;
        return this;
    }

    /**
     * @description Set `ObjectId__c`, `businessDocument__c`,
     * `businessDocumentCorrelatedNumber__c`, and `InternalId__c`
     * to the same value. Shorthand for flows where a single
     * identifier applies across all four fields.
     * @param documentNumber Value to store on every identifier
     *                       field.
     * @return The builder, for chaining.
     */
    public EventBuilder withSameDocumentNumberForAllIdentifiers (String documentNumber ) {

        return this.forObjectId(documentNumber)
               .withBusinessDocumentNumber (documentNumber)
               .withBusinessDocumentCorrelatedNumber (documentNumber)
               .withInternalID(documentNumber);
    }

    /**
     * @description Set the receiver system / account.
     * @param receiver Receiver identifier.
     * @return The builder, for chaining.
     */
    public EventBuilder withReceiver (String receiver) {
        event.receiver__c = receiver;
        return this;
    }

    /**
     * @description Set the inline payload. Persisted to an
     * `Attachment` on first `save()` and cleared from the field.
     * @param payload The payload body (typically JSON).
     * @return The builder, for chaining.
     */
    public EventBuilder withPayload (String payload) {
        event.payload__c = payload;
        return this;
    }

    /**
     * @description Override the initial status. Rarely needed —
     * default is `QUEUED` which is what the dispatcher expects.
     * @param status New status string (should be a value from
     *               `EventQueueStatusType`).
     * @return The builder, for chaining.
     */
    public EventBuilder withStatus (String status) {
        event.status__c = status;
        return this;
    }

    /**
     * @description Set a status message (e.g. when parking an
     * event at a non-error terminal state).
     * @param message Status message to persist.
     * @return The builder, for chaining.
     */
    public EventBuilder withStatusMessage (String message) {
        event.statusMessage__c = message;
        return this;
    }

    /**
     * @description Set the business document number.
     * @param businessDocumentNumber External business doc number.
     * @return The builder, for chaining.
     */
    public EventBuilder withBusinessDocumentNumber (String businessDocumentNumber) {
        event.businessDocument__c = businessDocumentNumber;
        return this;
    }

    /**
     * @description Set the correlated business document number.
     * @param businessDocumentCorrelatedNumber Secondary
     *        correlation number.
     * @return The builder, for chaining.
     */
    public EventBuilder withBusinessDocumentCorrelatedNumber (String businessDocumentCorrelatedNumber) {
        event.businessDocumentCorrelatedNumber__c  = businessDocumentCorrelatedNumber;
        return this;
    }

    /**
     * @description Set the external system's internal Id.
     * @param internalId External correlation id.
     * @return The builder, for chaining.
     */
    public EventBuilder withInternalID (String internalId) {
        event.internalId__c  = internalId;
        return this;
    }

    /**
     * @description Terminal: return the underlying `Queue__c`
     * SObject without persisting it.
     * @return The built `Queue__c`.
     */
    public Queue__c build() {
        return event;
    }


    /**
     * @description Terminal: wrap the built `Queue__c` in an
     * `EventQueue` without persisting.
     * @return The built `EventQueue`.
     */
    public EventQueue buildEvent() {
        return new EventQueue (event);
    }

    /**
     * @description Terminal: wrap the built `Queue__c` in an
     * `EventQueue`, insert/update it, and return the saved
     * instance. The trigger fires, so the dispatcher will pick up
     * the event asynchronously.
     * @return The saved `EventQueue`.
     */
    public EventQueue buildAndSave() {
        EventQueue built = new EventQueue (this.event);
        built.save();
        return built;
    }

    /**
     * @description Build an external-facing `EventQueue` populated
     * only via its SOAP (webservice) fields. Not persisted.
     * @return The populated `EventQueue`.
     */
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
