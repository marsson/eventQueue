/**
 *
 * @author: Eduardo Ribeiro de Carvalho - @ercarval
 */
@isTest
private class JobRetryEventProcessorTest {

    @isTest
    static void processErrorEvents() {

        JobRetryEventProcessor job = new JobRetryEventProcessor();
        ScheduleHelper helper = new ScheduleHelper();

        Test.startTest();

        job.execute(null);

        ScheduleHelper.jobCountForTest = 1;

        JobRetryEventProcessor.start();

        List<CronTrigger> cronTriggers = helper.findJobsByName('JobRetryEventProcessor');

        System.assert(cronTriggers.size() > 0);

        JobRetryEventProcessor.abort();


        Test.stopTest();


    }

}