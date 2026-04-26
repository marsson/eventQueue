/**
 * @description Fans a single log entry out to multiple child loggers.
 * Used by `LoggerFactory` when more than one
 * `Logger_Registration__c` record is active — lets admins send the
 * same framework log line to both `DebugLogger` (System.debug) AND a
 * `NebulaLoggerAdapter` by just registering two rows.
 *
 * Failures in any one child are swallowed so one bad logger doesn't
 * break the others.
 */
public class CompositeLogger extends AbstractLogger {

    private List<AbstractLogger> children;

    public CompositeLogger (List<AbstractLogger> children) {
        this.children = children == null ? new List<AbstractLogger>() : children;
    }

    public override void debug (String source, String message) {
        for (AbstractLogger child : this.children) {
            try { child.debug(source, message); } catch (Exception e) {}
        }
    }

    public override void info (String source, String message) {
        for (AbstractLogger child : this.children) {
            try { child.info(source, message); } catch (Exception e) {}
        }
    }

    public override void warn (String source, String message) {
        for (AbstractLogger child : this.children) {
            try { child.warn(source, message); } catch (Exception e) {}
        }
    }

    public override void error (String source, String message, Exception thrown) {
        for (AbstractLogger child : this.children) {
            try { child.error(source, message, thrown); } catch (Exception e) {}
        }
    }
}
