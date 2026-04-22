/**
 * @author: Heitor Araujo on 12/10/2017.
 */

public with sharing class BookTransformer {

    public Book__c transformFromVO(Book bookVO){

        Book__c book = new Book__c();

        book.Name = bookVO.name;
        book.Author__c = bookVO.author;
        book.ReleaseDate__c = bookVO.releaseDate;
        book.ExternalId__c = bookVO.externalId; 
        book.Id = bookVO.id;

        return book;
    }

    public Book transformToVO(Book__c book){

        Book bookVO = new Book();

        bookVO.id = book.Id;
        bookVO.name = book.Name;
        bookVO.author = book.Author__c;
        bookVO.releaseDate = book.ReleaseDate__c;

        return bookVO;
    }
}
