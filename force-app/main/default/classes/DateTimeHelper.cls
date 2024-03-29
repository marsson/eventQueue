/**
 *
 * @author: Eduardo Ribeiro de Carvalho - @ercarval
 */
public with sharing class DateTimeHelper {

    public static final String NOW_LOG_PATTERN = 'dd-MM-yyyy HH:mm:ss.SSS';

    public static DateTime removeSencondsIntoCurrentDate(Integer seconds) {
        if (seconds == null) {
            return null;
        }
        return removeSencondsIntoDate(System.now(), seconds);
    }

    public static DateTime removeSencondsIntoDate(DateTime timestamp, Integer seconds) {
        if (seconds == null) {
            return null;
        }
        return timestamp.addSeconds(-1 * seconds);
    }
}
