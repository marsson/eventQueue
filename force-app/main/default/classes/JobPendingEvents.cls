/**
 * @description Schedulable that re-queues events parked in
 * `SCHEDULED` status older than 120 seconds. Default cadence is
 * every 5 minutes (12 cron jobs across the hour).
 *
 * @author Eduardo Ribeiro de Carvalho - @ercarval
 * @author Heitor Araujo
 * @author Marcelo Marsson
 */
global class JobPendingEvents implements Schedulable {

    public static Integer jobCountForTest = 0;

    /**
     * @description Scheduler entry point. Delegates to
     * `EventExecutor.processPendingEvents()`.
     * @param sc The schedulable context provided by the platform.
     */
    global void execute(SchedulableContext sc) {
        EventExecutor.processPendingEvents();
    }

    /**
     * @description Register this job to fire every 5 minutes by
     * scheduling 12 cron jobs across the hour.
     */
    public static void start ()  {
        new ScheduleHelper().scheduleIntoMinutesInterval(  new JobPendingEvents() , 5);
    }

    /**
     * @description Abort every registered instance of this job
     * (matches cron names starting with `JobPendingEvents`).
     */
    public static void abort () {
        new ScheduleHelper().abort ('JobPendingEvents');
    }

}
