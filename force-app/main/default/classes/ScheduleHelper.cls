/**
 * @description Helper that schedules a `Schedulable` to run every
 * N minutes by emitting `60/N` separate cron jobs (one per minute
 * slot). Apex doesn't support `*/N` in the minutes field of cron
 * expressions outside batch context, so this helper compensates
 * by registering one job per slot.
 *
 * @author Eduardo Ribeiro de Carvalho - @ercarval
 * @author Heitor Araujo
 * @author Marcelo Marsson
 */
public with sharing class ScheduleHelper {

    public static Integer jobCountForTest = 0;


    /**
     * @description Schedule the given service to fire every
     * `minuteInterval` minutes by registering 60/`minuteInterval`
     * cron jobs across the hour.
     * @param service The schedulable instance to register.
     * @param minuteInterval The minute spacing between fires
     *                       (e.g. 5 → 12 jobs at *:00, *:05, ..., *:55).
     */
    public void scheduleIntoMinutesInterval ( Schedulable service,  Integer minuteInterval ) {

        String cronExpression = ' * * * ?';
        Integer i = 0;
        String executionMinute = '';
        while ( i < 60 ) {

            if (i < 10) {
                executionMinute = '0';
            }

            executionMinute += i;

            System.schedule( getServiceName (service) + '  ' + jobCountForTest + executionMinute , '0 ' + executionMinute + cronExpression , service);

            i += minuteInterval;

            executionMinute = '';

        }

    }

    /**
     * @description Aborts every cron job whose name starts with the
     * supplied string. Used to remove every per-minute sibling job
     * created by `scheduleIntoMinutesInterval`.
     * @param jobName Prefix of the cron job names to abort.
     */
    public void abort (String jobName) {
        for ( CronTrigger  cron : findJobsByName(jobName) ) {
            System.abortJob( cron.id );
        }

    }

    /**
     * @description Look up `CronTrigger` rows whose
     * `CronJobDetail.Name` starts with `jobName`.
     * @param jobName Prefix to filter on.
     * @return Matching cron triggers.
     */
    public List<CronTrigger> findJobsByName (String jobName) {
        return [SELECT Id , CronJobDetail.Name from CronTrigger where CronJobDetail.Name like : (jobName + '%') ];
    }


    @TestVisible
    private String getServiceName(Schedulable service) {
        return String.valueOf(service).substring(0, String.valueOf(service).indexOf(':'));
    }


}
