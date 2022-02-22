/**
 * @author: Heitor Araujo on 12/10/2017.
 */

public with sharing class BookOutboundCommand extends AbstractOutboundCommand {

    private Book__c bookObj;
    private BookTransformer transformer;

    public BookOutboundCommand() {

        this.transformer = new BookTransformer();
    }

    override
    public Object tranformToSend() {

        String payloadStr = this.event.getLastAttachedPayloadForEvent();
        this.bookObj = (Book__c) JSON.deserialize(payloadStr, Book__c.class);

        return this.transformer.transformToVO(this.bookObj);
    }

    override
    public void processResult(Object responseObject) {

        Book bookVO = (Book) JSON.deserialize((String) responseObject, Book.class);

        this.bookObj = this.transformer.transformFromVO(bookVO);

        if (Schema.sObjectType.Book__c.isUpdateable()) {
            update this.bookObj;

        }

    }

}
