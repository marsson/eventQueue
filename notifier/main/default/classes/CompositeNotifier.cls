/**
 * @description Fans a single `NotificationEvent` out to multiple
 * child notifiers. Used by `NotifierFactory` when more than one
 * `Notifier_Registration__c` record is active — lets admins send
 * the same event to Slack AND email AND a platform event by just
 * registering three rows.
 *
 * Failures in any one child are swallowed (logged via
 * `LoggerFactory`) so one bad notifier doesn't break the others.
 */
public class CompositeNotifier extends AbstractNotifier {

    private List<AbstractNotifier> children;

    public CompositeNotifier (List<AbstractNotifier> children) {
        this.children = children == null ? new List<AbstractNotifier>() : children;
    }

    public override void notify (NotificationEvent evt) {
        for (AbstractNotifier child : this.children) {
            try {
                child.notify(evt);
            } catch (Exception e) {
                LoggerFactory.getInstance().error(
                    'CompositeNotifier',
                    'child ' + String.valueOf(child).split(':')[0] + ' threw',
                    e
                );
            }
        }
    }
}
