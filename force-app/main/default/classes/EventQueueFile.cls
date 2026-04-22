/**
 * @description DTO representing one attachment to be persisted
 * against a `Queue__c` event. Buffered in
 * `EventQueue.payloads` and flushed to `Attachment` records via
 * `EventQueueFileFacade.createFilesForEventQueues(...)`.
 *
 * @author Heitor Araujo
 * @author Marcelo Marsson
 */
public with sharing class EventQueueFile {

    public String title {get; set;}
    public Blob content {get; set;}
    public Id parentId {get; set;}

    /**
     * @description Default constructor. Fields are populated by the
     * caller before the file is flushed.
     */
    public EventQueueFile(){ }

    /**
     * @description Build an attachment DTO with explicit title.
     * @param title Attachment name (without `.txt` suffix — added
     *              by the facade on insert).
     * @param parentId Id of the `Queue__c` record this attachment
     *                 belongs to. May be null at construction time
     *                 if the parent is not yet inserted.
     * @param content Body bytes for the attachment.
     */
    public EventQueueFile(String title, Id parentId, Blob content){

        this.title = title;
        this.parentId = parentId;
        this.content = content;
    }

    /**
     * @description Build an attachment DTO using a canonical title
     * prefix from `EventQueueFileTitle`.
     * @param title Canonical attachment title.
     * @param parentId Id of the `Queue__c` record this attachment
     *                 belongs to.
     * @param content Body bytes for the attachment.
     */
    public EventQueueFile(EventQueueFileTitle title, Id parentId, Blob content){

        this(title.name(), parentId, content);
    }
}
