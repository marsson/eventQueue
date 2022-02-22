/**
 *
 * @author: Eduardo Ribeiro de Carvalho - @ercarval
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

    public EventQueue() {
        init();
    }

    public EventQueue(Queue__c event) {
        this();
        init(event);
    }

    public EventQueue(EventType type) {
        this();
        init(new Queue__c(eventName__c = type.name()));
    }

    public EventQueue(Id id) {
        this();
        init (findOne (id));
    }


    public void init() {
        payloads = new List<EventQueueFile>();
        processingLog = new List<String>();
    }

    public void init(Queue__c event) {

        this.event = event;

        if (event.payload__c != null && event.payload__c != '') {
            setPayload(event.payload__c);
            event.payload__c = '';
        }

        configEvent();
    }

    public Queue__c get() {
        return event;
    }

    public String getPayload() {
        return getLastAttachedPayloadForEvent();
    }

    public Object getPayloadFromJson(Type clazz) {
        return JSON.deserialize(getPayload(), clazz);
    }

    public void addPayload(String name, String content) {
        payloads.add (new EventQueueFile(name, event.id, Blob.valueOf(content)));
    }

    public String getEventName() {
        return this.event.eventName__c;
    }

    public String getStatus() {
        return this.event.status__c;
    }

    public void setStatus(String status) {
        this.event.status__c = status;
    }

    public String getStackTrace() {
        return this.event.exceptionStackTrace__c;
    }

    public String getObjectId() {
        return this.event.ObjectId__c;
    }

    public String getEventId() {
        return this.event.Id;
    }

    public void process() {

        log('--------------------EVENT START EXECUTION-----------------');

        // not execute for UNHANDLED
        if (!hasHandlerFor(getEventName())) {
            setToUnhadledEvent();
            return;
        }

        try {

            configEvent();
            this.command = getCommand();
            this.command.execute(this);
            successfullyDeliveyEvent ();

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
     * execute all Update DMLs
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
                successfullyDeliveyEvent ();
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

    public boolean hasError() {
        return getStatus() == EventQueueStatusType.ERROR.name();
    }

    public boolean isIgnored() {
        return getStatus() == EventQueueStatusType.IGNORED.name();
    }

    public ICommand getCommand() {
        log ('Get Command Info for ' + this.getEventInfo());
        return CommandFactory.createIntanceFor (this.config.commandClassName__c);
    }

    public void setToUnhadledEvent() {
        event.status__c = EventQueueStatusType.UNHANDLED.name();
    }

    public EventQueue successfullyProcessedEvent() {
        event.Status__c = EventQueueStatusType.SUCCESS.name();
        event.StatusMessage__c = '';
        event.ExceptionStackTrace__c = '';
        return this;
    }

    public EventQueue successfullyDeliveyEvent() {

        if (!isIgnored()) {
            event.Status__c = EventQueueStatusType.DELIVERED.name();
        }

        event.StatusMessage__c = '';
        event.ExceptionStackTrace__c = '';
        return this;
    }

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

    public void setPayload(String payload) {

        if (this.payloads == null) {
            this.payloads = new List<EventQueueFile>();
        }

        if (payload == null || payload.trim() == '') {
            return;
        }

        addPayload(event.eventName__c, payload);
    }

    public void setObjectId(Id objId) {
        this.event.objectId__c = objId;
    }

    public boolean isRequestDisabled() {
        if (this.config == null) {
            return false;
        }
        return this.config.disableDispatcher__c;
    }


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
     * rethink this method to improve testability
     */
    public String getLastAttachedPayloadForEvent() {

        List<EventQueueFile> eventFiles = findLastPayloadProcessedForEvent(this.event.id, this.getEventName());

        if (eventFiles == null || eventFiles.isEmpty()) {
            return null;
        }

        EventQueueFile eventFile = eventFiles.get(0);

        return eventFile.content.toString();

    }

    override
    public String toString() {
        return getEventInfo();
    }

    public String getEventInfo() {
        return 'Event [ ' + this.event.Id + ' | ' + this.event.businessDocument__c + ' ] - ' + getEventName();
    }

    public void log(String message) {
        appendLog(message);
    }

    public void appendLog(String message) {
        if (this.processingLog == null) {
            this.processingLog = new List<String>();
        }
        processingLog.add (message);
        System.debug (message);
    }

    public void appendProcessLogToAttachament() {

        if (processingLog == null || processingLog.isEmpty()) {
            return;
        }

        System.debug ('\n\n ................. appendProcessLogToAttachament Logged Lines [ ' + processingLog.size() + ' ] ');

        addPayload ('ExecutionTrace_' + System.now() + '_' + (event.businessDocument__c == null ? '' : event.businessDocument__c)
                , convertProcessingLogToStringFile());

        processingLog.clear();

    }

    public String convertProcessingLogToStringFile() {
        String log = '';
        for (String value : processingLog) {
            log += '\n' + value;
        }
        return log;
    }


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
