/**
 * @description DTO carried by the framework-wide notifier. Any
 * subsystem (retention, retry, dispatch, custom extensions) builds
 * a `NotificationEvent` and hands it to the configured
 * `AbstractNotifier` via `NotifierFactory.createInstance()`.
 *
 * Implementers of `AbstractNotifier` branch on `source` / `severity`
 * / `eventType` to decide what to do.
 */
public class NotificationEvent {

    public String  source;
    public String  severity;
    public String  eventType;
    public String  title;
    public String  message;
    public Map<String, Object> context;
    public Exception thrown;
    public Datetime occurredAt;
    public Id       userId;

    public NotificationEvent () {
        this.occurredAt = System.now();
        this.userId     = UserInfo.getUserId();
        this.context    = new Map<String, Object>();
    }
}
