# Notifier

Framework-wide notification extension point. Lives in `notifier/`, no dependencies on `retention/` or `logger/`.

## Contract

```apex
public virtual class AbstractNotifier {
    public virtual void notify(NotificationEvent evt) {}
}

public class NotificationEvent {
    public String  source;       // 'PURGE', 'RETRY', 'DISPATCH', …
    public String  severity;     // 'INFO' | 'WARN' | 'ERROR'
    public String  eventType;    // e.g. 'PURGE_SUCCESS', 'PURGE_SKIPPED_GLOBAL_CAP'
    public String  title;
    public String  message;
    public Map<String, Object> context;
    public Exception thrown;
    public Datetime occurredAt;  // auto-set
    public Id       userId;      // auto-set
}
```

Callers build a `NotificationEvent` and call `NotifierFactory.createInstance()?.notify(evt)`. Blank `Notifier_Setting__c.ClassName__c` → factory returns `null` → notifications silent.

## Per-source payload conventions

| Source | eventType values | context fields |
|--------|------------------|----------------|
| `PURGE` | `PURGE_SUCCESS`, `PURGE_PARTIAL`, `PURGE_ERROR`, `PURGE_DRY_RUN`, `PURGE_SKIPPED_GLOBAL_CAP` | `purgeLogId`, `purgeLogName`, `policyDeveloperName`, `recordsEvaluated`, `recordsDeleted`, `recordsSkipped`, `durationSeconds`, `triggeredBy`, `deleteStrategy` |

Future subsystems add their own `source` values + context conventions here.

## Implementation examples

### Email via `Messaging.sendEmail`

```apex
public class EmailNotifier extends AbstractNotifier {
    public override void notify(NotificationEvent evt) {
        if (evt.severity != 'ERROR') return;
        Messaging.SingleEmailMessage m = new Messaging.SingleEmailMessage();
        m.setToAddresses(new List<String>{'admin@example.com'});
        m.setSubject('[' + evt.source + '] ' + evt.title);
        m.setPlainTextBody(evt.message + '\n\n' + JSON.serialize(evt.context));
        Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ m });
    }
}
```

### Slack webhook

```apex
public class SlackNotifier extends AbstractNotifier {
    public override void notify(NotificationEvent evt) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:Slack_Webhook');   // Named Credential
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(JSON.serialize(new Map<String,Object>{
            'text'   => '[' + evt.source + '] ' + evt.title,
            'fields' => evt.context
        }));
        new Http().send(req);
    }
}
```

### Platform Event publisher

```apex
public class PlatformEventNotifier extends AbstractNotifier {
    public override void notify(NotificationEvent evt) {
        EventBus.publish(new queuePurgeCompleted__e(
            Source__c   = evt.source,
            Severity__c = evt.severity,
            Payload__c  = JSON.serialize(evt.context)
        ));
    }
}
```

## Wiring

1. Deploy your notifier class to the org.
2. Set `Notifier_Setting__c.ClassName__c` = fully-qualified class name (via Queue Admin Console → Settings → Notifier tab, or Setup → Custom Settings).
3. `NotifierFactory` resolves on first call; misconfigured class names return `null` without throwing.

## Failure isolation

Every `notifier.notify(evt)` call in framework code is wrapped in `try/catch`. A failing notifier logs its error via `LoggerFactory.getInstance().error(...)` but never propagates — the underlying subsystem (purge, retry, etc.) always records its own success/failure based on its real outcome.
