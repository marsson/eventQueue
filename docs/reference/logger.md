# Logger

Framework-wide logging extension point. Lives in `logger/`, no dependencies on `retention/` or `notifier/`. Unlike the notifier, a concrete default (`DebugLogger`) ships — framework code always gets a non-null logger.

## Contract

```apex
public virtual class AbstractLogger {
    public virtual void debug (String source, String message) {}
    public virtual void info  (String source, String message) {}
    public virtual void warn  (String source, String message) {}
    public virtual void error (String source, String message, Exception thrown) {}
}
```

`source` convention: originating class name (`'QueueRetentionBatch'`, `'JobQueueRetention'`, etc.). Keeps grep / filter ergonomic regardless of transport.

## Usage

```apex
LoggerFactory.getInstance().info('QueueRetentionBatch',
    'processed ' + scope.size() + ' rows');

LoggerFactory.getInstance().error('NotifierFactory',
    'custom notifier threw', caught);
```

`LoggerFactory` is cached per-transaction — repeated `getInstance()` calls return the same instance.

## Shipped default: `DebugLogger`

Wraps `System.debug` with the appropriate `LoggingLevel` and a `[source]` prefix:

```
[QueueRetentionBatch] processed 2000 rows        (LoggingLevel.INFO)
```

Error logs additionally include the exception message and stack trace.

## Plugging in Nebula Logger

```apex
public class NebulaLoggerAdapter extends AbstractLogger {
    public override void debug(String source, String message) {
        Logger.debug('[' + source + '] ' + message);
        Logger.saveLog();
    }
    public override void info(String source, String message) {
        Logger.info('[' + source + '] ' + message);
        Logger.saveLog();
    }
    public override void warn(String source, String message) {
        Logger.warn('[' + source + '] ' + message);
        Logger.saveLog();
    }
    public override void error(String source, String message, Exception thrown) {
        Logger.error('[' + source + '] ' + message, thrown);
        Logger.saveLog();
    }
}
```

Deploy, then set `Logger_Setting__c.ClassName__c = 'NebulaLoggerAdapter'`.

## Plugging in a silent logger

Need to mute all framework logs in production? Ship an empty implementation:

```apex
public class NullLogger extends AbstractLogger {
    // defaults already no-op; no overrides needed.
}
```

Set `Logger_Setting__c.ClassName__c = 'NullLogger'`.

## Resolution + fallback

| `Logger_Setting__c.ClassName__c` | Returned by `LoggerFactory.getInstance()` |
|---|---|
| (blank or no record) | `DebugLogger` |
| Resolvable class extending `AbstractLogger` | configured instance |
| Unknown class name | `DebugLogger` (graceful fallback; never throws) |
| Class throws in constructor | `DebugLogger` (graceful fallback) |

## Migration of existing `System.debug` calls

Retention code (`JobQueueRetention`, `QueueRetentionBatch`, `QueueAdminService`) uses `LoggerFactory.getInstance()` throughout. Existing core framework classes (`EventExecutor`, the three existing `Job*` classes, `EventQueueActiveRecord`) still use raw `System.debug` — migrating them is tracked in `docs/improvements.md` as follow-up work.
