/**
 * @description Default `AbstractLogger` implementation. Writes to
 * `System.debug` with the appropriate `LoggingLevel` and a
 * `[source]` prefix so entries can be filtered via grep on debug logs.
 *
 * Used automatically by `LoggerFactory.getInstance()` when no active
 * `Logger_Registration__c` record exists — the framework always has
 * a working logger out of the box.
 */
public class DebugLogger extends AbstractLogger {

    public override void debug (String source, String message) {
        System.debug(LoggingLevel.DEBUG, '[' + source + '] ' + message);
    }

    public override void info (String source, String message) {
        System.debug(LoggingLevel.INFO, '[' + source + '] ' + message);
    }

    public override void warn (String source, String message) {
        System.debug(LoggingLevel.WARN, '[' + source + '] ' + message);
    }

    public override void error (String source, String message, Exception thrown) {
        String line = '[' + source + '] ' + message;
        if (thrown != null) {
            line += ' | ' + thrown.getMessage() + '\n' + thrown.getStackTraceString();
        }
        System.debug(LoggingLevel.ERROR, line);
    }
}
