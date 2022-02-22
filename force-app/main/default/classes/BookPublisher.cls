/**
 * @author: Heitor Araujo on 11/10/2017.
 */

public with sharing class BookPublisher {

    public void publishInbound(Book book){

        EventBuilder builder = new EventBuilder();

        EventQueue eventQueue = new EventQueue(
                builder
                        .createEventFor(EventType.BOOK_INBOUND_SERVICE)
                        .withSender('REST_CONTROLLER')
                        .withReceiver('SALESFORCE')
                        .build());

        eventQueue.setPayload( JSON.serialize(book) );

        eventQueue.save();
    }

    public void publishOutbound(Book__c book){

        EventBuilder builder = new EventBuilder();

        EventQueue eventQueue = new EventQueue(
            builder
                .createOutboundEventFor(EventType.BOOK_OUTBOUND_SERVICE.name())
                .withReceiver('HEROKU')
                .withInternalID(book.Id)
                .build());

        eventQueue.setPayload( JSON.serialize(book) );

        eventQueue.save();

    }

    public void publishOutbound(List<Book__c> books){

        for(Book__c book : books){
            publishOutbound(book);
        }
    }
}
