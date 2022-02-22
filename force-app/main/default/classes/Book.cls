/**
 * Created by marcelo.cost on 22/2/2022.
 */
/**
 * @author: Heitor Araujo on 11/10/2017.
 */

global with sharing class Book {

    public Id id {get; set;}
    public String name {get; set;}
    public String author {get; set;}
    public Date releaseDate {get; set;}
    public String externalId {get; set;}
}
