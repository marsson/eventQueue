trigger queueProcessor on queueEvent__e (after insert) {

    List<Queue__c> rows = new List<Queue__c>();

    for (queueEvent__e event : Trigger.New) {
        rows.add(new Queue__c(
            EventName__c = event.Event_Type__c,
            Payload__c = event.Payload__c,
            ObjectId__c = event.Related_sObject_Id__c,
            Status__c = EventQueueStatusType.QUEUED.name(),
            RetryCount__c = 10
        ));
    }

    if (!rows.isEmpty()) {
        insert rows;
    }
}
