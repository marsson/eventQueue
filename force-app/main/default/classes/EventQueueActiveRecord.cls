/**
 *
 *
 * @author: Eduardo Ribeiro de Carvalho - @ercarval
 * @reviewer: Marcelo Marsson
 */
public abstract with sharing class EventQueueActiveRecord  {

    private Map<String, Event_Configuration__mdt> configbymetadataName;

    public static final String[] PENDING_EVENTS = new String[] { EventQueueStatusType.SCHEDULED.name() };


    public EventQueueActiveRecord () {
        configbymetadataName = new Map<String, Event_Configuration__mdt>();

        List<Event_Configuration__mdt> mdtList = new List<Event_Configuration__mdt>();
       if (Schema.sObjectType.Event_Configuration__mdt.isAccessible()) {

       mdtList =  [Select Label, CommandClassName__c, DisableDispatcher__c, Method__c,NamedCredencial__c from Event_Configuration__mdt ];
        //TODO: Should we throw an exception on else??
       }


        for (Event_Configuration__mdt conf : mdtList){
            configbymetadataName.put(conf.Label, conf);
        }
    }

    public Event_Configuration__mdt getEventConfiguration (String eventName) {
        return configbymetadataName.get(eventName);
    }

    public Boolean hasHandlerFor (String eventName) {
        return configbymetadataName.containsKey(eventName);
    }

    public static void updateAll ( List<Queue__c> events ) {
        update events;
    }

    public static void createAll ( List<Queue__c> events ) {
        insert events;
    }

    public Queue__c save (Queue__c event) {

        if (event.id == null) {
            insert event;
            return event;
        }

        update event;
        return event;
    }

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


    public static List<Queue__c> findQueuedEvents(Set<String> keys) {
        List<Queue__c> queueList= new List<Queue__c>();
        if (Schema.sObjectType.Queue__c.isAccessible()) {
            queueList= [Select q.status__c, q.statusMessage__c, q.sender__c, q.payload__c, q.retryCount__c, q.receiver__c, q.objectId__c, q.internalId__c, q.externalCreationDate__c, q.exceptionStackTrace__c, q.eventName__c, q.businessDocument__c, q.businessDocumentCorrelatedNumber__c, q.Name, q.Id From Queue__c q where q.id in :keys] ;
        }
        return queueList;

    }

    public Queue__c findOne (String id) {
        List<Queue__c> queues = findQueuedEvents ( new Set<String> {id});
        return (!queues.isEmpty()) ? queues.get(0) : null ;
    }

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

    public static List<Queue__c> findPendingQueuedEvents (DateTime lastCreationDate, Integer listSize) {
        return findPendingQueuedEvents ( PENDING_EVENTS, lastCreationDate, listSize );
    }

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

    public static List<Queue__c> findEventTypeForObject(String eventName, String objectId) {
        List<Queue__c> queueList = new List<Queue__c>();
        if (Schema.sObjectType.Queue__c.isAccessible()) {
            queueList = [SELECT Id from Queue__c where EventName__c = :eventName and ObjectId__c = :objectId];
        }
        return queueList;
    }

}
