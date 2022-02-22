/**
 * @author: Heitor Araujo on 18/10/2017.
 */

public with sharing class EventQueueFileFacade {

    public void createFileForEventQueue(EventQueueFile eventFile){

        ContentVersion contentVersion = new ContentVersion();
        contentVersion.Title = eventFile.title;
        contentVersion.PathOnClient = eventFile.title + '.txt';
        contentVersion.VersionData = eventFile.content;

        insert contentVersion;

        contentVersion = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id =: contentVersion.Id];

        ContentDocumentLink contentLink = new ContentDocumentLink();
        contentLink.ContentDocumentId = contentVersion.ContentDocumentId;
        contentLink.LinkedEntityId = eventFile.parentId;

        insert contentLink;
    }

    public static void createFilesForEventQueues(List<EventQueueFile> eventFiles){

        Map<String, EventQueueFile> eventFilesByTitle = buildEventFilesByTitle(eventFiles);

        List<ContentVersion> contentVersions = new List<ContentVersion>();
        for(EventQueueFile eventFile : eventFiles){

            ContentVersion contentVersion = new ContentVersion();
            contentVersion.Title = eventFile.title;
            contentVersion.PathOnClient = eventFile.title + '.txt';
            contentVersion.VersionData = eventFile.content;

            contentVersions.add(contentVersion);
        }

        insert contentVersions;

        Set<Id> contentVersionIds = new Set<Id>();
        for(ContentVersion contentVersion : contentVersions){
            contentVersionIds.add(contentVersion.Id);
        }

        contentVersions = [SELECT Id, Title, ContentDocumentId FROM ContentVersion WHERE Id IN :contentVersionIds];

        List<ContentDocumentLink> contentLinks = new List<ContentDocumentLink>();
        for(ContentVersion contentVersion : contentVersions){

            EventQueueFile eventFile = eventFilesByTitle.get(contentVersion.Title);

            ContentDocumentLink contentLink = new ContentDocumentLink();
            contentLink.ContentDocumentId = contentVersion.ContentDocumentId;
            contentLink.LinkedEntityId = eventFile.parentId;
            contentLink.ShareType = 'V';

            contentLinks.add(contentLink);
        }

        insert contentLinks;

    }

    private static Map<String, EventQueueFile> buildEventFilesByTitle(List<EventQueueFile> eventFiles){

        Map<String, EventQueueFile> eventFilesByTitle = new Map<String, EventQueueFile>();

        for(EventQueueFile eventFile : eventFiles){
            eventFilesByTitle.put(eventFile.title, eventFile);
        }

        return eventFilesByTitle;
    }


}