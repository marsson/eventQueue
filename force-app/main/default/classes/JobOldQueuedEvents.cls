/**
 * @description Schedulable safety-net that re-queues events stuck
 * in `QUEUED` status for more than 600 seconds (usually because
 * the original trigger-side dispatch failed or hit governor
 * limits). Default cadence is every 9 minutes.
 *
 * @author Eduardo Ribeiro de Carvalho - @ercarval
 * @author Heitor Araujo
 * @author Marcelo Marsson
 */
global with sharing class JobOldQueuedEvents implements Schedulable {

    public static Integer jobCountForTest = 0;


    /**
     * @description Scheduler entry point. Delegates to
     * `EventExecutor.processOldQueuedEvents()`.
     * @param sc The schedulable context provided by the platform.
     */
    global void execute(SchedulableContext sc) {
        EventExecutor.processOldQueuedEvents();
    }

    /**
     * @description Register this job to fire every 9 minutes.
     */
    public static void start ()  {
        new ScheduleHelper().scheduleIntoMinutesInterval(  new JobOldQueuedEvents() , 9);
    }

    /**
     * @description Abort every registered instance of this job.
     */
    public static void abort () {
        new ScheduleHelper().abort ('JobOldQueuedEvents');
    }


}
