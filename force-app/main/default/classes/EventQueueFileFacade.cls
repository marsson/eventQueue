/**
 * @description Facade over the standard `Attachment` SObject for
 * persisting payloads associated with a `Queue__c` event. Hides
 * the conversion from `EventQueueFile` DTO to `Attachment` and
 * the bulk insert.
 *
 * @author Heitor Araujo
 * @author Marcelo Marsson
 */
public with sharing class EventQueueFileFacade {


    /**
     * @description Convert each `EventQueueFile` to an `Attachment`
     * (named `<title>.txt`, content type `txt`) and insert them in
     * a single DML.
     * @param eventFiles Buffered files to persist.
     */
    public static void createFilesForEventQueues(List<EventQueueFile> eventFiles){

        Map<String, EventQueueFile> eventFilesByTitle = buildEventFilesByTitle(eventFiles);
        List<Attachment> attachments = new List<Attachment>();
        for(EventQueueFile eventFile : eventFiles){

            Attachment attachment = new Attachment();
            attachment.Body = eventFile.content;
            attachment.Name = eventFile.title +'.txt';
            attachment.ParentId = eventFile.parentId;
            attachment.ContentType ='txt';
            attachments.add(attachment);
        }

        insert attachments;


    }

    private static Map<String, EventQueueFile> buildEventFilesByTitle(List<EventQueueFile> eventFiles){

        Map<String, EventQueueFile> eventFilesByTitle = new Map<String, EventQueueFile>();

        for(EventQueueFile eventFile : eventFiles){
            eventFilesByTitle.put(eventFile.title, eventFile);
        }
        return eventFilesByTitle;
    }


}
