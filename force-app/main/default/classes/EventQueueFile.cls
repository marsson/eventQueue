/**
 * @author: Heitor Araujo on 18/10/2017.
 */

public with sharing class EventQueueFile {

    public String title {get; set;}
    public Blob content {get; set;}
    public Id parentId {get; set;}

    public EventQueueFile(){ }

    public EventQueueFile(String title, Id parentId, Blob content){

        this.title = title;
        this.parentId = parentId;
        this.content = content;
    }

    public EventQueueFile(EventQueueFileTitle title, Id parentId, Blob content){

        this(title.name(), parentId, content);
    }
}