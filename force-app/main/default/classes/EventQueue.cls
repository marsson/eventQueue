/**
 * @description The core domain object for the Event Queue. Wraps
 * one `Queue__c` record plus its attachments, in-memory log
 * buffer, and resolved command.
 *
 * Extends `EventQueueActiveRecord` so it also exposes the
 * SOQL/DML helpers used across the framework.
 *
 * The `webservice`-scoped fields make the class SOAP-addressable:
 * external clients can marshal an `EventQueue` over a custom
 * webservice endpoint.
 *
 * `global` because subclasses and extensions live outside the
 * package namespace.
 *
 * @author Eduardo Ribeiro de Carvalho - @ercarval
 * @author Heitor Araujo
 * @author Marcelo Marsson
 */
global class EventQueue extends EventQueueActiveRecord {

    public static final Integer DEQUEUE_QUEUED_BATCH_SIZE = 30;
    public static final Integer DEQUEUE_ERROR_BATCH_SIZE = 30;

    public String payload { get; set; }
    public String retryCount { get; set; }

    webservice String id { get; set; }
    webservice String eventName { get; set; }
    webservice String outboundUrl { get; set; }
    webservice String internalId { get; set; }
    webservice String sender { get; set; }
    webservice String receiver { get; set; }
    webservice String status { get; set; }
    webservice String statusMessage { get; set; }
    webservice String businessDocumentNumber { get; set; }
    webservice String businessDocumentCorrelatedNumber { get; set; }

    public Event_Configuration__mdt config { get; set; }

    public Queue__c event { get; set; }

    public List<EventQueueFile> payloads { get; set; }

    public List<String> processingLog { get; set; }

    private ICommand command;

    /**
     * @description Default constructor. Sets up empty payload
     * and log buffers.
     */
    public EventQueue() {
        init();
    }

    /**
     * @description Wrap an existing `Queue__c` record.
     * @param event The record to wrap.
     */
    public EventQueue(Queue__c event) {
        this();
        init(event);
    }

    /**
     * @description Create a fresh `EventQueue` for the given event
     * type. A new `Queue__c` is allocated with the enum's name.
     * @param type The event type.
     */
    public EventQueue(EventType type) {
        this();
        init(new Queue__c(eventName__c = type.name()));
    }

    /**
     * @description Load an existing `Queue__c` by Id.
     * @param id The Id to look up.
     */
    public EventQueue(Id id) {
        this();
        init (findOne (id));
    }


    /**
     * @description Initialise the in-memory payload / log buffers.
     */
    public void init() {
        payloads = new List<EventQueueFile>();
        processingLog = new List<String>();
    }

    /**
     * @description Initialise from an existing `Queue__c`,
     * migrating any inline `Payload__c` into the payload buffer
     * (so it will be persisted as an `Attachment` on save) and
     * resolving the configuration row.
     * @param event The record to wrap.
     */
    public void init(Queue__c event) {

        this.event = event;

        if (event.payload__c != null && event.payload__c != '') {
            setPayload(event.payload__c);
            event.payload__c = '';
        }

        configEvent();
    }

    /**
     * @description Access the underlying `Queue__c` record.
     * @return The wrapped record.
     */
    public Queue__c get() {
        return event;
    }

    /**
     * @description Read the last attached payload body for this
     * event.
     * @return The payload body as a String, or null if none exists.
     */
    public String getPayload() {
        return getLastAttachedPayloadForEvent();
    }

    /**
     * @description Deserialise the last attached payload into the
     * given Apex type.
     * @param clazz The target Apex class.
     * @return The deserialised object (caller must cast).
     */
    public Object getPayloadFromJson(Type clazz) {
        return JSON.deserialize(getPayload(), clazz);
    }

    /**
     * @description Buffer a new attachment to be persisted with
     * this event on save.
     * @param name Attachment title (without `.txt` suffix).
     * @param content Body.
     */
    public void addPayload(String name, String content) {
        payloads.add (new EventQueueFile(name, event.id, Blob.valueOf(content)));
    }

    /**
     * @description Event type of the underlying `Queue__c` record.
     * @return `Queue__c.EventName__c`.
     */
    public String getEventName() {
        return this.event.eventName__c;
    }

    /**
     * @description Current status of the underlying record.
     * @return `Queue__c.Status__c`.
     */
    public String getStatus() {
        return this.event.status__c;
    }

    /**
     * @description Set the status of the underlying record.
     * @param status New status (should be a value from
     *               `EventQueueStatusType`).
     */
    public void setStatus(String status) {
        this.event.status__c = status;
    }

    /**
     * @description Stack trace from the last failure, if any.
     * @return `Queue__c.ExceptionStackTrace__c`.
     */
    public String getStackTrace() {
        return this.event.exceptionStackTrace__c;
    }

    /**
     * @description Related Salesforce record Id.
     * @return `Queue__c.ObjectId__c`.
     */
    public String getObjectId() {
        return this.event.ObjectId__c;
    }

    /**
     * @description Id of the underlying `Queue__c` record.
     * @return `Queue__c.Id`.
     */
    public String getEventId() {
        return this.event.Id;
    }

    /**
     * @description Main dispatcher entry point. Resolves the
     * configured command, honours the `DisableDispatcher__c` kill
     * switch, invokes `execute(event)`, and routes exceptions to
     * either the business (non-retryable) or technical
     * (retryable) branch.
     */
    public void process() {

        log('--------------------EVENT START EXECUTION-----------------');

        // not execute for UNHANDLED
        if (!hasHandlerFor(getEventName())) {
            setToUnhandledEvent();
            return;
        }

        configEvent();

        // honour the per-event-type kill switch
        if (isRequestDisabled()) {
            log('Dispatcher disabled for ' + getEventName() + ' - marking IGNORED');
            setStatus(EventQueueStatusType.IGNORED.name());
            return;
        }

        try {

            this.command = getCommand();
            this.command.execute(this);
            successfullyDeliveryEvent ();

        } catch (IntegrationBusinessException e) {
            errorProcessingEvent(e);
            disableRetry();
        } catch (Exception e) {
            errorProcessingEvent(e);
            decreaseRetry();
        }

        log('--------------------EVENT END EXECUTION-----------------');
    }


    /**
     * @description Second pass of the two-phase flow. Invoked by
     * `EventExecutor.processEvents(...)` after every callout has
     * completed so commands implementing `IUpdatableCommmad` can
     * apply DML using the response.
     *
     * Skipped when the event is `IGNORED`, `UNHANDLED`, or the
     * command does not implement `IUpdatableCommmad`.
     */
    public void postExecute() {

        log('--------------------POST EXECUTE START -----------------');

        // not execute for UNHANDLED
        if (isIgnored ()
                || !hasHandlerFor(getEventName())
                || !(this.command instanceOf IUpdatableCommmad)) {

            log ('-------------------- POST EXECUTE SKIPED -----------');

            return;
        }

        try {

            IUpdatableCommmad updatableCommand = (IUpdatableCommmad) this.command;
            updatableCommand.postUpdateExecute (this);

            if (!hasError()) {
                successfullyDeliveryEvent ();
            }

        } catch (IntegrationBusinessException e) {
            errorProcessingEvent(e);
            disableRetry();
        } catch (Exception e) {
            errorProcessingEvent(e);
            decreaseRetry();
        }

        log('--------------------POST EXECUTE END -----------------');

    }

    /**
     * @description Whether the event is currently in `ERROR`
     * status.
     * @return true if `Status__c == 'ERROR'`.
     */
    public boolean hasError() {
        return getStatus() == EventQueueStatusType.ERROR.name();
    }

    /**
     * @description Whether the event is currently marked
     * `IGNORED` (skipped intentionally by a command or the kill
     * switch).
     * @return true if `Status__c == 'IGNORED'`.
     */
    public boolean isIgnored() {
        return getStatus() == EventQueueStatusType.IGNORED.name();
    }

    /**
     * @description Resolve the configured `ICommand` instance for
     * this event via `CommandFactory`.
     * @return A fresh command instance.
     */
    public ICommand getCommand() {
        log ('Get Command Info for ' + this.getEventInfo());
        return CommandFactory.createInstanceFor (this.config.commandClassName__c);
    }

    /**
     * @description Mark the event as `UNHANDLED` (no
     * configuration exists for this event name).
     */
    public void setToUnhandledEvent() {
        event.status__c = EventQueueStatusType.UNHANDLED.name();
    }

    /**
     * @description Mark the event as `SUCCESS` and clear error
     * fields. Legacy terminal state — not used by the packaged
     * dispatcher but available to custom commands.
     * @return `this`, for chaining.
     */
    public EventQueue successfullyProcessedEvent() {
        event.Status__c = EventQueueStatusType.SUCCESS.name();
        event.StatusMessage__c = '';
        event.ExceptionStackTrace__c = '';
        return this;
    }

    /**
     * @description Mark the event as `DELIVERED` and clear error
     * fields. Skipped when the event is `IGNORED` (in which case
     * only the error fields are cleared).
     * @return `this`, for chaining.
     */
    public EventQueue successfullyDeliveryEvent() {

        if (!isIgnored()) {
            event.Status__c = EventQueueStatusType.DELIVERED.name();
        }

        event.StatusMessage__c = '';
        event.ExceptionStackTrace__c = '';
        return this;
    }

    /**
     * @description Record an exception on the event: sets status
     * to `ERROR`, writes the type + message to `StatusMessage__c`
     * and the stack trace to `ExceptionStackTrace__c`, and
     * appends to the processing log.
     * @param e The exception raised by the command.
     * @return `this`, for chaining.
     */
    public EventQueue errorProcessingEvent(Exception e) {

        event.status__c = EventQueueStatusType.ERROR.name();
        event.statusMessage__c = e.getTypeName() + ' :  { ' + e.getMessage() + ' }';
        event.exceptionStackTrace__c = e.getStackTraceString();

        log(' \n \n ------- EVENT THROWS EXCEPTION ------- \n\n ');
        log(event.statusMessage__c);
        log(event.exceptionStackTrace__c);

        return this;
    }

    private EventQueue disableRetry() {
        event.retryCount__c = 0;
        event.IsRetryDisabled__c = true;
        return this;
    }

    private EventQueue decreaseRetry() {
        if (event.retryCount__c == 0) {
            return this;
        }
        event.retryCount__c -= 1;
        return this;
    }

    /**
     * @description Queue a payload to be persisted as an
     * `Attachment` on save. Ignored if `payload` is null or empty.
     * @param payload The payload body.
     */
    public void setPayload(String payload) {

        if (this.payloads == null) {
            this.payloads = new List<EventQueueFile>();
        }

        if (payload == null || payload.trim() == '') {
            return;
        }

        addPayload(event.eventName__c, payload);
    }

    /**
     * @description Set the related Salesforce record Id.
     * @param objId The record Id.
     */
    public void setObjectId(Id objId) {
        this.event.objectId__c = objId;
    }

    /**
     * @description Whether the dispatcher is disabled for this
     * event type (via `Event_Configuration__mdt.DisableDispatcher__c`).
     * `process()` honours this flag by routing the event to
     * `IGNORED`.
     * @return true when the kill switch is set; false otherwise.
     */
    public boolean isRequestDisabled() {
        if (this.config == null) {
            return false;
        }
        return this.config.disableDispatcher__c;
    }


    /**
     * @description Persist the underlying `Queue__c` (insert or
     * update), flush any inline `Payload__c` to a buffered
     * attachment, append the processing log as an attachment, and
     * store the payload attachments.
     * @return `this`, for chaining.
     */
    public EventQueue save() {

        if (event == null) {
            return this;
        }

        if (event.payload__c != null && event.payload__c != '') {
            setPayload(event.payload__c);
            event.payload__c = ''; //clear this old field;
        }

        appendProcessLogToAttachament();

        save(event);

        storePayloads();

        return this;
    }

    /**
     * @description Resolve the configuration row for this event
     * and cache it on `this.config`.
     */
    public void configEvent() {
        this.config = getEventConfiguration(this.getEventName());
    }

    private List<EventQueueFile> correlateAttachedPayloadWithEvent() {

        if (this.payloads == null || this.payloads.isEmpty()) {
            return new List<EventQueueFile>() ;
        }

        for (EventQueueFile eventFile : this.payloads) {
            if (eventFile.parentId == null) {
                eventFile.parentId = event.id;
            }
        }

        return this.payloads;

    }

    private void storePayloads() {

        if (payloads == null || payloads.isEmpty()) {
            return ;
        }

        correlateAttachedPayloadWithEvent ();

        storePayloads(payloads);

    }

    /**
     * @description Read the most recent payload Attachment body
     * for this event. Kept for legacy API reasons — TODO: rework
     * to improve testability.
     * @return The payload body as a String, or null when no
     *         attachment exists.
     */
    public String getLastAttachedPayloadForEvent() {

        List<EventQueueFile> eventFiles = findLastPayloadProcessedForEvent(this.event.id, this.getEventName());

        if (eventFiles == null || eventFiles.isEmpty()) {
            return null;
        }

        EventQueueFile eventFile = eventFiles.get(0);

        return eventFile.content.toString();

    }

    /**
     * @description Human-readable description of this event.
     * @return A string of the form
     *         `Event [ <id> | <bizdoc> ] - <name>`.
     */
    override
    public String toString() {
        return getEventInfo();
    }

    /**
     * @description Concise description used in logs and debug
     * messages.
     * @return `Event [ <id> | <bizdoc> ] - <name>`.
     */
    public String getEventInfo() {
        return 'Event [ ' + this.event.Id + ' | ' + this.event.businessDocument__c + ' ] - ' + getEventName();
    }

    /**
     * @description Append a message to the processing log buffer.
     * Alias for `appendLog(...)`.
     * @param message The message to log.
     */
    public void log(String message) {
        appendLog(message);
    }

    /**
     * @description Append a line to the in-memory processing log
     * buffer and echo it to `System.debug`. Flushed to an
     * `ExecutionTrace_*` attachment on save.
     * @param message The line to record.
     */
    public void appendLog(String message) {
        if (this.processingLog == null) {
            this.processingLog = new List<String>();
        }
        processingLog.add (message);
        System.debug (message);
    }

    /**
     * @description Flush the processing log buffer to a new
     * `ExecutionTrace_<now>_<bizdoc>` payload, then clear the
     * buffer.
     */
    public void appendProcessLogToAttachament() {

        if (processingLog == null || processingLog.isEmpty()) {
            return;
        }

        System.debug ('\n\n ................. appendProcessLogToAttachament Logged Lines [ ' + processingLog.size() + ' ] ');

        addPayload ('ExecutionTrace_' + System.now() + '_' + (event.businessDocument__c == null ? '' : event.businessDocument__c)
                , convertProcessingLogToStringFile());

        processingLog.clear();

    }

    /**
     * @description Concatenate the processing log buffer into a
     * single newline-delimited string suitable for an attachment
     * body.
     * @return The flattened log.
     */
    public String convertProcessingLogToStringFile() {
        String log = '';
        for (String value : processingLog) {
            log += '\n' + value;
        }
        return log;
    }


    /**
     * @description Bulk-insert a list of `EventQueue` wrappers.
     * The underlying `Queue__c` records are inserted together, and
     * the buffered payloads are correlated to their parent before
     * being persisted.
     * @param events The events to create.
     */
    public void createAllEvents(List<EventQueue> events) {

        System.debug('\n -------------- STORE ALL EVENTS -------------\n' + events);

        List<Queue__c> queues = new List<Queue__c>();
        List<EventQueueFile> payloads = new List<EventQueueFile>();

        for (EventQueue event : events) {
            Queue__c queue = event.get();
            queues.add(queue);
        }

        createAll (queues);

        for (EventQueue event : events) {

            System.debug('\n -------------- Events Into IndexedEvents  -------------\n' + JSON.serialize(event));

            payloads.addAll(event.correlateAttachedPayloadWithEvent ());

        }

        storePayloads (payloads);


    }


}
