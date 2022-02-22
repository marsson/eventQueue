/**
 *
 * @author: Eduardo Ribeiro de Carvalho - @ercarval
 */
global class JobPendingEvents implements Schedulable {

    public static Integer jobCountForTest = 0;

    global void execute(SchedulableContext sc) {
        EventExecutor.processPendingEvents();
    }

    /**
     * Start Schedule execution for this class
     */
    public static void start ()  {
        new ScheduleHelper().scheduleIntoMinutesInterval(  new JobPendingEvents() , 5);
    }

    public static void abort () {
        new ScheduleHelper().abort ('JobPendingEvents');
    }

}