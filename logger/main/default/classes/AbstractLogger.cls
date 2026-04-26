/**
 * @description Framework-wide logger contract. Implementers extend
 * this class and override whichever level methods they care about to
 * route log entries to their backend (Nebula Logger, custom store, etc.).
 *
 * The shipped default is `DebugLogger`, which wraps `System.debug`.
 * Admins register one or more implementations via
 * `Logger_Registration__c` (toggleable via `IsActive__c`). Zero
 * active rows = fallback to `DebugLogger`.
 *
 * `source` is conventionally the originating class name (e.g.
 * `'QueueRetentionBatch'`) so logs remain grep-friendly regardless of
 * transport.
 */
public virtual class AbstractLogger {

    public virtual void debug (String source, String message) {}

    public virtual void info  (String source, String message) {}

    public virtual void warn  (String source, String message) {}

    public virtual void error (String source, String message, Exception thrown) {}
}
