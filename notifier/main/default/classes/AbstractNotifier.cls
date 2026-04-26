/**
 * @description Framework-wide notifier contract. Implementers extend
 * this class and override `notify(NotificationEvent)` to route events
 * to their transport of choice (email, Slack, PagerDuty, platform
 * event, etc.). No concrete implementation ships with the framework.
 *
 * Admins register implementations via `Notifier_Registration__c` —
 * one row per implementation, each toggleable via `IsActive__c`.
 * Zero active rows = silent.
 */
public virtual class AbstractNotifier {

    public virtual void notify (NotificationEvent evt) {}
}
