# Interfaces & Extension Contracts

This page documents the contracts that a developer implements or
extends when plugging into the framework.

## `ICommand` — the primary contract

```apex
public interface ICommand {
    void execute(EventQueue event);
}
```

- **Called by:** `EventQueue.process()` via `CommandFactory`.
- **Parameter:** the event being processed. Never null. `event.event`
  (the underlying `Queue__c`) always has an id.
- **Return:** void. Success is signalled by returning without
  throwing.
- **Failure signalling:**
  - Throw `IntegrationBusinessException` → event goes to `ERROR` and
    `IsRetryDisabled = true` (no retry).
  - Throw any other `Exception` (including `IntegrationException`,
    `CalloutException`, runtime exceptions) → event goes to `ERROR`,
    `RetryCount` is decremented, retry loop may pick it up again.

Implement directly only when neither `AbstractCommand` nor
`AbstractOutboundCommand` fits (e.g. trivial commands that don't need
the template hooks).

## `IUpdatableCommmad` — two-phase commands

```apex
public interface IUpdatableCommmad extends ICommand {
    void postUpdateExecute(EventQueue event);
}
```

Extends `ICommand` with a second pass. Use this when your command
needs to:

1. Make a callout (in `execute`), **then**
2. Update Salesforce records using the response (in
   `postUpdateExecute`).

Apex forbids DML before a callout in the same transaction, so
`EventExecutor.processEvents` walks the list twice — once to run
every `execute()`, then once to run every `postUpdateExecute()` — and
only bulk-updates the queue records at the very end.

> The name is misspelled (`Commmad`, three M's). The typo is
> preserved for backward compatibility; see
> [../improvements.md](../improvements.md).

Relevant call path (from `EventQueue.postExecute()`):

```apex
if (isIgnored() || !hasHandlerFor(getEventName())
        || !(this.command instanceOf IUpdatableCommmad)) {
    return; // skipped
}
IUpdatableCommmad updatableCommand = (IUpdatableCommmad) this.command;
updatableCommand.postUpdateExecute(this);
```

Exceptions thrown from `postUpdateExecute` are caught and handled
exactly like `execute` exceptions.

## `InboundService` (currently unused)

```apex
public interface InboundService {
    void execute();
}
```

Declared but not called by anything in the package. Intended to
model inbound REST services that don't originate from a `Queue__c`
row. Consider it an extension point rather than a mandatory contract.

## Abstract base classes — the recommended extension points

Rather than implementing `ICommand` from scratch, extend one of
these:

### `AbstractCommand` — generic command

Provides the template: `init → preExecute → execute → postExecute`.
Override only the steps you need.

```apex
public with sharing class SendWelcomeEmailCommand extends AbstractCommand {
    private Contact contact;

    override public void init(EventQueue event) {
        super.init(event);
        contact = (Contact) event.getPayloadFromJson(Contact.class);
    }

    override public void execute() {
        Messaging.SingleEmailMessage msg = /* ... */;
        Messaging.sendEmail(new Messaging.SingleEmailMessage[]{ msg });
    }
}
```

### `AbstractOutboundCommand` — HTTP-callout command

Extends `AbstractCommand`. Requires implementing two methods:

```apex
global abstract Object tranformToSend();
global abstract void processResult(Object responseObject);
```

Everything else — proxy construction, request/response attachment,
logging — is done by the base class. Override
`getHttpRequestProxy(EventQueue)` if you need a custom
`BaseRestProxy` subclass (e.g. OAuth token injection, custom retry
semantics).

Example skeleton:

```apex
public with sharing class BookOutboundCommand extends AbstractOutboundCommand {

    override global Object tranformToSend() {
        Booking b = (Booking) event.getPayloadFromJson(Booking.class);
        return new BookingDTO(b);
    }

    override global void processResult(Object responseObject) {
        String body = (String) responseObject;
        BookingResponse r = (BookingResponse) JSON.deserialize(body, BookingResponse.class);
        // ... update Salesforce records here,
        // OR declare `implements IUpdatableCommmad`
        //    and move the DML into postUpdateExecute
    }
}
```

## `Schedulable` (standard Salesforce interface)

The three shipped jobs implement `System.Schedulable`:

- `JobPendingEvents`
- `JobOldQueuedEvents`
- `JobRetryEventProcessor`

Convention: every shipped job has static `start()` / `abort()` helpers
that wrap `ScheduleHelper`. When adding new scheduled jobs, follow
the same shape so that admins can bootstrap/teardown them uniformly.

## `Queueable` + `Database.AllowsCallouts`

`EventExecutor` implements both. This lets the dispatcher chain
itself as a Queueable (via `System.enqueueJob(new EventExecutor())`)
when you want the dispatch off the user's transaction but don't want
to involve the trigger path.

## Extension surface summary

| Contract | When to implement | Base class / interface |
| --- | --- | --- |
| Trivial command | Tight, zero-callout logic. | `ICommand` |
| Generic command with lifecycle hooks | You want `init/preExecute/execute/postExecute` for structure. | `AbstractCommand` |
| HTTP outbound command | You call an external system via Named Credential. | `AbstractOutboundCommand` |
| Two-phase command | You need DML **after** a callout. | Declare `implements IUpdatableCommmad` on your command. |
| Custom HTTP behaviour | You need OAuth / custom retry / custom headers. | Extend `BaseRestProxy` (or `RestProxy`), override `getHttpRequestProxy()`. |
| Custom scheduled job | New recovery/maintenance job. | `Schedulable`, mirror `Job*` convention. |
| Business failure | You want to permanently stop retries. | `throw new IntegrationBusinessException(new IntegrationBusError(code, message))` |
| Technical failure | You want the retry loop to try again. | `throw new IntegrationException(httpResponse)` or any other `Exception`. |
