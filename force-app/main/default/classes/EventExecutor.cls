/**
 * @description The Event Queue dispatcher. Two entry points:
 *
 *  1. `processEvents(Map<String,String>)` — invoked as a
 *     `@future(callout=true)` from `EventQueueTriggerHandler`
 *     when a `Queue__c` row is inserted/updated in `QUEUED`
 *     status.
 *  2. Static `process{Pending,OldQueued,Error}Events()` methods
 *     called by the scheduled jobs to re-queue events that are
 *     stuck or eligible for retry.
 *
 * Also implements `Queueable` + `Database.AllowsCallouts` so the
 * same class can be enqueued directly via `System.enqueueJob(...)`.
 *
 * `processEvents(List<Queue__c>)` is the workhorse. It walks the
 * list once to run every command's `execute(...)` (callouts OK)
 * and a second time to invoke `postUpdateExecute(...)` on
 * `IUpdatableCommmad` instances (DML OK), then bulk-updates the
 * queue rows and persists the accumulated payloads — keeping the
 * callouts-before-DML invariant in Apex.
 *
 * @author Eduardo Ribeiro de Carvalho - @ercarval
 * @author Heitor Araujo
 * @author Marcelo Marsson
 */
public class EventExecutor implements Queueable,  Database.AllowsCallouts {

    private List<Queue__c> events;

    public static final Integer FUTURE_CALL_SIZE = 5;

    /**
     * @description Build an executor for a single queue record.
     * @param queue The `Queue__c` to process when this executor
     *              is enqueued.
     */
    public EventExecutor (Queue__c queue) {
        events = new List<Queue__c> ();
        events.add (queue);
    }

    /**
     * @description Build an executor for an arbitrary list of
     * queue records.
     * @param events The `Queue__c` records to process.
     */
    public EventExecutor (List<Queue__c> events) {
        this.events = events;
    }

    /**
     * @description Process all events on a future scope. Called
     * from `EventQueueTriggerHandler` with up to
     * `FUTURE_CALL_SIZE` entries per invocation.
     * @param eventnameByEventId Map of event Id → event name for
     *                           the batch to process.
     */
    @future(callout = true)
    public static void processEvents ( Map<String, String> eventnameByEventId ) {
        processEvents ( EventQueueActiveRecord.findQueuedEvents(eventnameByEventId.keySet()) );
    }


    /**
     * @description Dispatch every event in the supplied list.
     * Runs a two-pass loop (callouts first, then DML) and
     * bulk-persists queue rows + payloads at the end.
     * @param processingQueue The queue records to dispatch.
     */
    public static void processEvents (List<Queue__c> processingQueue) {

        List<EventQueueFile> payloads = new List<EventQueueFile>();
        List<EventQueue> events = new List<EventQueue>();

        String eventsIntoBatch4Log = JSON.serialize(processingQueue);
        for (Queue__c queue : processingQueue) {

            EventQueue event = new EventQueue(queue);

            event.log( 'Events into Batch to Process \n ' + eventsIntoBatch4Log + '\n'  );

            event.process();
            events.add(event);
        }

        // Apply All DMLs After callout execution
        for (EventQueue event : events) {
            event.postExecute ();
            event.appendProcessLogToAttachament();
            payloads.addAll( event.payloads );
        }

        EventQueueActiveRecord.updateAll (processingQueue);
        EventQueueActiveRecord.storePayloads(payloads);

    }

    /**
     * @description Requeue events in `SCHEDULED` status older than
     * 120 seconds. Invoked by `JobPendingEvents`.
     */
    public static void processPendingEvents () {
        List<Queue__c> queues = EventQueueActiveRecord.findPendingQueuedEvents(
                                    DateTimeHelper.removeSecondsIntoCurrentDate(120) , 80 ) ;
        reprocess (queues);
    }

    /**
     * @description Requeue events stuck in `QUEUED` status older
     * than 600 seconds. Invoked by `JobOldQueuedEvents`.
     */
    public static void processOldQueuedEvents () {
        List<Queue__c> queues = EventQueueActiveRecord.findPendingQueuedEvents(
                                    new String[] {EventQueueStatusType.QUEUED.name()},
                                    DateTimeHelper.removeSecondsIntoCurrentDate(600) , 80 ) ;
        reprocess (queues);
    }

    /**
     * @description Requeue events in `ERROR` status older than
     * 60 seconds that still have retry budget. Invoked by
     * `JobRetryEventProcessor`.
     */
    public static void processErrorEvents () {
        List<Queue__c> queues =  EventQueueActiveRecord.findEventsWithError(
                                     DateTimeHelper.removeSecondsIntoCurrentDate(60) , 80 ) ;
        reprocess (queues);
    }

    /**
     * @description Flip the status of every supplied queue record
     * back to `QUEUED` and persist in a single DML.
     * @param queues The records to re-queue.
     */
    public static void reprocess (List<Queue__c> queues) {

        for (Queue__c queue : queues ) {
            queue.status__c = EventQueueStatusType.QUEUED.name();
        }

        update queues;

    }

    /**
     * @description `Queueable.execute` entry point. When used as a
     * queueable without an explicit event list, falls back to
     * processing up to 20 events in `WORKFLOW` status.
     * @param context The queueable context supplied by the
     *                platform.
     */
    public void execute(QueueableContext context) {
        if (events == null || events.isEmpty() ) {
            events = EventQueueActiveRecord.findPendingQueuedEvents (EventQueueStatusType.WORKFLOW, 20);
        }

        EventExecutor.processEvents(events);
    }



}
