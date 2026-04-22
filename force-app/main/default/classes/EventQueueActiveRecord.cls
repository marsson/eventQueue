/**
 * @description Active-record base extended by `EventQueue`.
 * Loads and caches every `Event_Configuration__mdt` row at
 * construction time (keyed by `DeveloperName`) and exposes the
 * SOQL/DML helpers that the framework uses to find, save, and
 * bulk-operate on `Queue__c` records.
 *
 * Every read method is gated with
 * `Schema.sObjectType.<Obj>.isAccessible()` (or
 * `WITH SECURITY_ENFORCED`) — callers without read access simply
 * receive empty lists rather than an exception.
 *
 * @author Eduardo Ribeiro de Carvalho - @ercarval
 * @author Heitor Araujo
 * @author Marcelo Marsson
 */
public abstract with sharing class EventQueueActiveRecord  {

    private Map<String, Event_Configuration__mdt> configbymetadataName;

    public static final String[] PENDING_EVENTS = new String[] { EventQueueStatusType.SCHEDULED.name() };


    /**
     * @description Construct the active-record and populate the
     * in-memory configuration cache. Triggered once per
     * `EventQueue` instance — not per request.
     */
    public EventQueueActiveRecord () {
        configbymetadataName = new Map<String, Event_Configuration__mdt>();

        List<Event_Configuration__mdt> mdtList = new List<Event_Configuration__mdt>();
       if (Schema.sObjectType.Event_Configuration__mdt.isAccessible()) {

       mdtList =  [Select Label, DeveloperName, CommandClassName__c, DisableDispatcher__c, Method__c, NamedCredencial__c from Event_Configuration__mdt ];
        //TODO: Should we throw an exception on else??
       }


        for (Event_Configuration__mdt conf : mdtList){
            configbymetadataName.put(conf.DeveloperName, conf);
        }
    }

    /**
     * @description Look up the configuration for a given event
     * name.
     * @param eventName The event type (matches
     *                  `Event_Configuration__mdt.DeveloperName`).
     * @return The matching config row, or null if none is
     *         registered.
     */
    public Event_Configuration__mdt getEventConfiguration (String eventName) {
        return configbymetadataName.get(eventName);
    }

    /**
     * @description Report whether a configuration exists for the
     * given event name.
     * @param eventName The event type.
     * @return true if a mapping exists, false otherwise.
     */
    public Boolean hasHandlerFor (String eventName) {
        return configbymetadataName.containsKey(eventName);
    }

    /**
     * @description Bulk update of queue records.
     * @param events The records to update.
     */
    public static void updateAll ( List<Queue__c> events ) {
        update events;
    }

    /**
     * @description Bulk insert of queue records.
     * @param events The records to insert.
     */
    public static void createAll ( List<Queue__c> events ) {
        insert events;
    }

    /**
     * @description Insert or update a single queue record
     * depending on whether its Id is populated.
     * @param event The record to persist.
     * @return The persisted record (with Id set).
     */
    public Queue__c save (Queue__c event) {

        if (event.id == null) {
            insert event;
            return event;
        }

        update event;
        return event;
    }

    /**
     * @description Persist a batch of buffered payload files as
     * `Attachment` records. Swallows and logs exceptions so a
     * payload-storage failure doesn't block status updates on the
     * parent queue row.
     * @param eventFiles Buffered files to persist.
     */
    public static void storePayloads(List<EventQueueFile> eventFiles) {

        System.debug('\n\n\n Storing Payloads ' + eventFiles);

        try {

            EventQueueFileFacade.createFilesForEventQueues(eventFiles);

        } catch (Exception e) {

            System.debug('\n\n\n [ EXCEPTION ] UNABLE TO STORE PAYLOAD ' + eventFiles);
            System.debug('\n\n\n ' + e);
            System.debug('\n\n\n --------------------------------------------- ');
            System.debug (e.getStackTraceString());

        }

    }


    /**
     * @description Load queue records by Id.
     * @param keys Record Ids to load.
     * @return Matching records (a subset of fields).
     */
    public static List<Queue__c> findQueuedEvents(Set<String> keys) {
        List<Queue__c> queueList= new List<Queue__c>();
        if (Schema.sObjectType.Queue__c.isAccessible()) {
            queueList= [Select q.status__c, q.statusMessage__c, q.sender__c, q.payload__c, q.retryCount__c, q.receiver__c, q.objectId__c, q.internalId__c, q.externalCreationDate__c, q.exceptionStackTrace__c, q.eventName__c, q.businessDocument__c, q.businessDocumentCorrelatedNumber__c, q.Name, q.Id From Queue__c q where q.id in :keys] ;
        }
        return queueList;

    }

    /**
     * @description Load one queue record by Id.
     * @param id The Id to look up.
     * @return The record, or null if not found.
     */
    public Queue__c findOne (String id) {
        List<Queue__c> queues = findQueuedEvents ( new Set<String> {id});
        return (!queues.isEmpty()) ? queues.get(0) : null ;
    }

    /**
     * @description Check if a queue event is already pending
     * (in `QUEUED` status) for the given business document.
     * Used for basic deduplication by producers.
     * @param eventName Event type to match.
     * @param businessDocumentNumber Business doc to match.
     * @return true if at least one `QUEUED` event exists for the
     *         combination.
     */
    public boolean hasQueuedEventsForBusinessDocument (String eventName, String businessDocumentNumber) {
        List<Queue__c> events = new List<Queue__c> ();
                if (Schema.sObjectType.Queue__c.isAccessible()) {
             events = [
                    Select id, name
                    from Queue__c q
                    where q.eventName__c = :eventName
                    and q.status__c = :EventQueueStatusType.QUEUED.name()
                    and q.businessDocument__c = :businessDocumentNumber
                    limit 1
            ];
        }
        return !events.isEmpty();
    }

    /**
     * @description Find the last two events for a given event
     * type + business document, newest first (ordered by
     * `ExternalCreationDate__c`).
     * @param eventName Event type to match.
     * @param businessDocumentNumber Business doc to match.
     * @return Up to two matching records.
     */
    public List<Queue__c> findLastEventsByNameAndBusinessDocumentNumber (String eventName, String businessDocumentNumber) {
        List<Queue__c> queueList = new List<Queue__c>();
        if (Schema.sObjectType.Queue__c.isAccessible()) {

            queueList= [
                    Select q.status__c, q.statusMessage__c, q.sender__c, q.retryCount__c, q.receiver__c, q.payload__c, q.objectId__c, q.internalId__c, q.externalCreationDate__c, q.exceptionStackTrace__c, q.eventName__c, q.businessDocument__c, q.businessDocumentCorrelatedNumber__c, q.Name, q.Id
                    From Queue__c q
                    where q.eventName__c = :eventName
                    and q.businessDocument__c = :businessDocumentNumber
                    order by Queue__c.externalCreationDate__c desc
                    limit 2
            ] ;
        }
        return queueList;
    }

    /**
     * @description Find events in the default pending status set
     * (`SCHEDULED`) older than the supplied cutoff.
     * @param lastCreationDate Records older than this timestamp
     *                         are eligible.
     * @param listSize Max records to return.
     * @return Matching records, oldest first.
     */
    public static List<Queue__c> findPendingQueuedEvents (DateTime lastCreationDate, Integer listSize) {
        return findPendingQueuedEvents ( PENDING_EVENTS, lastCreationDate, listSize );
    }

    /**
     * @description Find events whose status is in the supplied
     * list and that are older than the supplied cutoff.
     * @param status Statuses to include.
     * @param lastCreationDate Records older than this timestamp
     *                         are eligible.
     * @param listSize Max records to return.
     * @return Matching records, oldest first.
     */
    public static List<Queue__c> findPendingQueuedEvents (String[] status,  DateTime lastCreationDate, Integer listSize) {
        List<Queue__c> queueList = new List<Queue__c>();
        if (Schema.sObjectType.Queue__c.isAccessible()) {
            queueList= [
                    Select q.parentEvent__c, q.businessDocument__c, q.businessDocumentCorrelatedNumber__c, q.Status__c, q.StatusMessage__c, q.Sender__c, q.RetryCount__c, q.Receiver__c, q.Payload__c, q.ObjectId__c, q.Name, q.LastModifiedDate, q.IsRetryDisabled__c, q.InternalId__c, q.Id, q.ExternalCreationDate__c, q.ExceptionStackTrace__c, q.EventName__c, q.CreatedDate
                    From Queue__c q
                    where q.status__c in :status
                    and q.createdDate < :lastCreationDate
                    order by q.createdDate asc
                    limit :listSize
            ];
        }
        return queueList;
    }

    /**
     * @description Find events in `ERROR` status older than the
     * supplied cutoff that still have retry budget and are not
     * hard-disabled. Drives the retry loop.
     * @param lastCreationDate Records older than this timestamp
     *                         are eligible.
     * @param listSize Max records to return.
     * @return Matching records, oldest first.
     */
    public static List<Queue__c> findEventsWithError ( DateTime lastCreationDate, Integer listSize) {
        List<Queue__c> queueList = new List<Queue__c>();
        if (Schema.sObjectType.Queue__c.isAccessible()) {
            queueList= [
                    Select q.parentEvent__c, q.businessDocument__c, q.businessDocumentCorrelatedNumber__c, q.Status__c, q.StatusMessage__c, q.Sender__c, q.RetryCount__c, q.Receiver__c, q.Payload__c, q.ObjectId__c, q.Name, q.LastModifiedDate, q.IsRetryDisabled__c, q.InternalId__c, q.Id, q.ExternalCreationDate__c, q.ExceptionStackTrace__c, q.EventName__c, q.CreatedDate
                    From Queue__c q
                    where q.status__c = 'ERROR'
                    and q.createdDate < :lastCreationDate
                    and q.retryCount__c > 0
                    and q.IsRetryDisabled__c = false
                    order by q.createdDate asc
                    limit :listSize
            ];
        }
        return queueList;
    }

    /**
     * @description Find events matching a single enum status,
     * oldest first. No date filter.
     * @param status Status to filter on.
     * @param listSize Max records to return.
     * @return Matching records, oldest first.
     */
    public static List<Queue__c> findPendingQueuedEvents (EventQueueStatusType status, Integer listSize) {
        List<Queue__c> queueList = new List<Queue__c>();
        if (Schema.sObjectType.Queue__c.isAccessible()) {
            queueList= [
                    Select q.parentEvent__c, q.businessDocument__c, q.businessDocumentCorrelatedNumber__c, q.Status__c, q.StatusMessage__c, q.Sender__c, q.RetryCount__c, q.Receiver__c, q.Payload__c, q.ObjectId__c, q.Name, q.LastModifiedDate, q.IsRetryDisabled__c, q.InternalId__c, q.Id, q.ExternalCreationDate__c, q.ExceptionStackTrace__c, q.EventName__c, q.CreatedDate
                    From Queue__c q
                    where q.status__c = :status.name()
                    order by q.createdDate asc
                    limit :listSize
            ];
        }
        return queueList;
    }

//    public List<Attachment> findAttachmentsForEvent (String eventId) {
//        return [ SELECT Body, BodyLength, ContentType, CreatedById, CreatedDate, Description, Id, LastModifiedDate, Name, ParentId FROM Attachment where ParentId = :eventId order by  LastModifiedDate desc ];
//    }

    /**
     * @description Read every `Attachment` on a queue record and
     * wrap it in an `EventQueueFile` DTO. Used by
     * `EventQueue.getPayload()` to read back the persisted body.
     * @param eventId The `Queue__c.Id` whose attachments to read.
     * @param eventName Event type (reserved; currently unused in
     *                  the query filter).
     * @return The attachments wrapped as DTOs.
     */
    public List<EventQueueFile> findLastPayloadProcessedForEvent (String eventId, String eventName) {

        List<Attachment> attachments = [SELECT Id,Body,Name,ParentId  FROM Attachment WHERE ParentId = :eventId WITH SECURITY_ENFORCED];
        List<EventQueueFile> payloads = new List<EventQueueFile>();
        List<ContentVersion> contentVersions = new List<ContentVersion>();

        for(Attachment attachment : attachments){
            EventQueueFile payload = new EventQueueFile();
            payload.title = attachment.Name;
            payload.parentId =attachment.ParentId ;
            payload.content = attachment.Body;
            payloads.add(payload);
        }

        return payloads;
    }

    /**
     * @description Find every event of a given type related to a
     * given Salesforce record.
     * @param eventName Event type to match.
     * @param objectId Salesforce record Id stored in
     *                 `Queue__c.ObjectId__c`.
     * @return Matching records.
     */
    public static List<Queue__c> findEventTypeForObject(String eventName, String objectId) {
        List<Queue__c> queueList = new List<Queue__c>();
        if (Schema.sObjectType.Queue__c.isAccessible()) {
            queueList = [SELECT Id from Queue__c where EventName__c = :eventName and ObjectId__c = :objectId];
        }
        return queueList;
    }

}
