/**
 *
 * @author: Eduardo Ribeiro de Carvalho - @ercarval
 */
global class JobRetryEventProcessor implements Schedulable {

    public JobRetryEventProcessor() {
    }

    global void execute(SchedulableContext sc) {
        EventExecutor.processErrorEvents();
    }

    /**
     * Start Schedule execution for this class
     */
    public static void start ()  {
        new ScheduleHelper().scheduleIntoMinutesInterval(  new JobRetryEventProcessor() , 8);
    }

    public static void abort () {
        new ScheduleHelper().abort ('JobRetryEventProcessor');
    }

}