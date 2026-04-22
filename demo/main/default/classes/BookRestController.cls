
@RestResource(urlMapping = '/api/books')
global with sharing class BookRestController {

    @HttpPost
    global static void newBook(Book book){

        BookPublisher publisher = new BookPublisher();
        publisher.publishInbound(book);
    }
}
