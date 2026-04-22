/**
 * @description Schedulable that drives the retry loop for events
 * in `ERROR` status. Re-queues events older than 60s that still
 * have `RetryCount__c > 0` and `IsRetryDisabled__c = false`.
 * Default cadence is every 8 minutes.
 *
 * @author Eduardo Ribeiro de Carvalho - @ercarval
 * @author Heitor Araujo
 * @author Marcelo Marsson
 */
global class JobRetryEventProcessor implements Schedulable {

    /**
     * @description Default constructor.
     */
    public JobRetryEventProcessor() {
    }

    /**
     * @description Scheduler entry point. Delegates to
     * `EventExecutor.processErrorEvents()`.
     * @param sc The schedulable context provided by the platform.
     */
    global void execute(SchedulableContext sc) {
        EventExecutor.processErrorEvents();
    }

    /**
     * @description Register this job to fire every 8 minutes.
     */
    public static void start ()  {
        new ScheduleHelper().scheduleIntoMinutesInterval(  new JobRetryEventProcessor() , 8);
    }

    /**
     * @description Abort every registered instance of this job.
     */
    public static void abort () {
        new ScheduleHelper().abort ('JobRetryEventProcessor');
    }

}
