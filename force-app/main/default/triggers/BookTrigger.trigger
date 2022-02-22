/**
 * @author: Heitor Araujo on 12/10/2017.
 */

trigger BookTrigger on Book__c (after insert) {

    BookPublisher publisher = new BookPublisher();
    for(Book__c book : Trigger.NEW) {

        if(book.Externalid__c == null) {

            publisher.publishOutbound(Book);
        }
    }
}
