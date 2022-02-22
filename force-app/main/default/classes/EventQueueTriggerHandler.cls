/**
 * Created by marcelo.cost on 22/2/2022.
 */

public with sharing class EventQueueTriggerHandler {
    public EventQueueTriggerHandler() {

        //all elements with status__c = Queued
        Map<String, String> events = new Map<String, String>();

        Integer i = 0;

        if (System.isBatch() || System.isFuture()) {
            System.debug('Dequeue is in future method. Ignore');
            return;
        }

        for (Queue__c event : (List<Queue__c>)trigger.new) {

            if (event.status__c != EventQueueStatusType.QUEUED.name()) {
                continue;
            }

// Callout Control, only 100 simultaneous.
            if (i == EventExecutor.FUTURE_CALL_SIZE) {
                EventExecutor.processEvents(events);
                events = new Map<String, String>();
                i = 0;
            }

            events.put(event.id, event.eventName__c);
            i++;
        }

        if (events.size() > 0) {
            System.debug('DeQueueProcessor - Process last batch ' + events.size());
            EventExecutor.processEvents(events);
        }
    }
}
