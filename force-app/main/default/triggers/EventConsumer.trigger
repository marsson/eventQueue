/**
 * @author: Eduardo Ribeiro de Carvalho - ercarval
 */
trigger EventConsumer on Queue__c (after insert, after update) {
    new EventQueueTriggerHandler();

}
