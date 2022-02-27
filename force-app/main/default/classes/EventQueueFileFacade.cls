/**
 * @author: Heitor Araujo on 18/10/2017.
 */

public with sharing class EventQueueFileFacade {


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
