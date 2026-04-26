/**
 * @description Resolves ALL active notifier implementations at
 * runtime. Reads `Notifier_Registration__c` (one row per registered
 * implementation, toggleable via `IsActive__c`) and instantiates each
 * class.
 *
 * Return value:
 *   - `null` — no active registrations (notifications silent)
 *   - single `AbstractNotifier` — when exactly one registration is active
 *   - `CompositeNotifier` — fans out to every active registration
 *
 * Admins register new implementations via the Queue Admin Console →
 * Notifiers tab, or by inserting rows into `Notifier_Registration__c`.
 */
public with sharing class NotifierFactory {

    @TestVisible private static AbstractNotifier mock;

    /**
     * @description Build the notifier for this transaction.
     */
    public static AbstractNotifier createInstance () {
        if (mock != null) return mock;

        List<AbstractNotifier> instances = new List<AbstractNotifier>();
        for (Notifier_Registration__c r : loadActive()) {
            if (String.isBlank(r.ClassName__c)) continue;
            Type t = Type.forName(r.ClassName__c);
            if (t == null) continue;
            try {
                instances.add((AbstractNotifier) t.newInstance());
            } catch (Exception e) {
                // Unresolvable class — skip silently; admin UI flags it on save.
            }
        }

        if (instances.isEmpty()) return null;
        if (instances.size() == 1) return instances[0];
        return new CompositeNotifier(instances);
    }

    private static List<Notifier_Registration__c> loadActive () {
        return [
            SELECT Id, ClassName__c, IsActive__c
            FROM Notifier_Registration__c
            WHERE IsActive__c = TRUE
            ORDER BY Name ASC
        ];
    }

    @TestVisible
    private static void setMock (AbstractNotifier m) {
        mock = m;
    }
}
