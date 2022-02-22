/**
 * @author: Heitor Araujo on 11/10/2017.
 */

public with sharing class BookInboundCommand extends AbstractCommand{

    private Book bookVO {get; set;}

    override
    public void preExecute(){

        this.bookVO = (Book) this.event.getPayloadFromJson(Book.class);
    }

    override
    public void execute(){

        BookTransformer transformer = new BookTransformer();
        Book__c book = transformer.transformFromVO(this.bookVO);

        if(Schema.sObjectType.Book__c.isCreateable()) {
            insert book;
            this.bookVO.id = book.Id;
        }



    }

    override
    public void postExecute(){

        this.event.event.InternalId__c = this.bookVO.id;
        update this.event.event;
    }

}
