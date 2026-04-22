/**
 * @description Small utility for date/time arithmetic used by the
 * scheduled retry jobs to compute "older than N seconds" cutoffs.
 *
 * @author Eduardo Ribeiro de Carvalho - @ercarval
 * @author Heitor Araujo
 * @author Marcelo Marsson
 */
public with sharing class DateTimeHelper {

    public static final String NOW_LOG_PATTERN = 'dd-MM-yyyy HH:mm:ss.SSS';

    /**
     * @description Returns the current timestamp shifted backwards
     * by the given number of seconds. Useful to compute "events
     * older than X seconds" cutoffs for the retry queries.
     * @param seconds The number of seconds to subtract from `now()`.
     *                Returns null if seconds is null.
     * @return `System.now() - seconds`, or null when `seconds` is
     *         null.
     */
    public static DateTime removeSecondsIntoCurrentDate(Integer seconds) {
        if (seconds == null) {
            return null;
        }
        return removeSecondsIntoDate(System.now(), seconds);
    }

    /**
     * @description Returns the given timestamp shifted backwards by
     * the given number of seconds.
     * @param timestamp The reference timestamp.
     * @param seconds The number of seconds to subtract.
     * @return `timestamp - seconds`, or null when `seconds` is null.
     */
    public static DateTime removeSecondsIntoDate(DateTime timestamp, Integer seconds) {
        if (seconds == null) {
            return null;
        }
        return timestamp.addSeconds(-1 * seconds);
    }
}
