/**
 * @description Resolves ALL active logger implementations at runtime.
 * Reads `Logger_Registration__c` (one row per registered implementation,
 * toggleable via `IsActive__c`) and instantiates each class.
 *
 * Return value (never null):
 *   - zero active registrations → `DebugLogger` (default — framework
 *     always emits something out of the box)
 *   - exactly one active → that instance
 *   - more than one active → `CompositeLogger` fanning out to each
 *
 * Cached per-transaction so repeated `getInstance()` calls don't
 * re-query or re-instantiate.
 */
public with sharing class LoggerFactory {

    private static AbstractLogger cached;

    public static AbstractLogger getInstance () {
        if (cached != null) return cached;

        List<AbstractLogger> instances = new List<AbstractLogger>();
        for (Logger_Registration__c r : loadActive()) {
            if (String.isBlank(r.ClassName__c)) continue;
            Type t = Type.forName(r.ClassName__c);
            if (t == null) continue;
            try {
                instances.add((AbstractLogger) t.newInstance());
            } catch (Exception e) {
                // Skip — framework falls back to DebugLogger if this leaves us empty.
            }
        }

        if (instances.isEmpty()) {
            cached = new DebugLogger();
        } else if (instances.size() == 1) {
            cached = instances[0];
        } else {
            cached = new CompositeLogger(instances);
        }
        return cached;
    }

    private static List<Logger_Registration__c> loadActive () {
        return [
            SELECT Id, ClassName__c, IsActive__c
            FROM Logger_Registration__c
            WHERE IsActive__c = TRUE
            ORDER BY Name ASC
        ];
    }

    @TestVisible
    private static void setMock (AbstractLogger m) {
        cached = m;
    }

    @TestVisible
    private static void reset () {
        cached = null;
    }
}
