# Apex Class Reference

Every Apex file in `force-app/main/default/classes/` is documented
below, grouped by role. Signatures are copied verbatim; quirks
(typos, `global` markers, `@TestVisible`, dead methods) are called
out.

## Interfaces

### `ICommand`

```apex
public interface ICommand {
    void execute(EventQueue event);
}
```

The single-method root of the command hierarchy. Every class mapped
in `Event_Configuration__mdt.CommandClassName__c` must implement this
interface (directly or transitively).

### `IUpdatableCommmad` (note: intentional typo — three M's)

```apex
public interface IUpdatableCommmad extends ICommand {
    void postUpdateExecute(EventQueue event);
}
```

Marker for commands that need a **second** pass after the callout
phase, typically to apply DML using the callout response. The
dispatcher (`EventExecutor.processEvents`) performs all `execute()`
calls first, then walks the list and invokes `postUpdateExecute()` on
every command that is `instanceof IUpdatableCommmad`.

> ⚠️ The class name is **misspelled** (`Commmad`). Renaming it would
> be a breaking change because `Event_Configuration__mdt` references
> command classes by name and permission sets reference the class.
> Tracked in [../improvements.md](../improvements.md).

### `InboundService`

```apex
public interface InboundService {
    void execute();
}
```

Declared but unused by the dispatcher. Presumably intended as the
symmetric counterpart of `AbstractOutboundCommand` for inbound REST
services that don't start from a `Queue__c` row. Candidate for
removal or promotion — see [improvements.md](../improvements.md).

## Abstract bases

### `AbstractCommand`

`global abstract with sharing class AbstractCommand implements ICommand`

Template-method base. Implements `execute(EventQueue)` as:

```
init(event) → preExecute() → execute() → postExecute()
```

| Member | Signature | Purpose |
| --- | --- | --- |
| `event` | `protected EventQueue` | The current event — stored by `init()`. |
| `init(EventQueue)` | `virtual global void` | Assign `this.event = event`. Subclasses typically `super.init(event)` then deserialise payload. |
| `preExecute()` | `virtual global void` | Hook for pre-processing (default logs `"pre Execute"`). |
| `execute()` | `global abstract void` | **Required.** The business logic. |
| `postExecute()` | `virtual global void` | Hook for post-processing (default logs `"post Execute"`). |
| `execute(EventQueue)` | `public void` | The template. Calls `init → preExecute → execute → postExecute`. |

The class is `global` because extenders live outside the package's
namespace. The javadoc includes a worked example of extending it to
handle a `PurchaseApprovedCommand`.

### `AbstractOutboundCommand`

`global abstract with sharing class AbstractOutboundCommand extends AbstractCommand`

Specialised base for HTTP-callout commands. Overrides every lifecycle
hook to orchestrate a transform → send → process-result flow.

| Member | Signature | Purpose |
| --- | --- | --- |
| `targetObject` | `@TestVisible protected Object` | The outbound DTO. Produced by `tranformToSend()`. |
| `responseObject` | `@TestVisible private Object` | The response DTO. Produced by `send()`. |
| `proxy` | `protected BaseRestProxy` | Built in `init` via `getHttpRequestProxy(event)`. |
| `init(EventQueue)` | `override virtual global void` | Calls `super.init`, then `proxy = getHttpRequestProxy(event)`. |
| `preExecute()` | `override virtual global void` | Calls `tranformToSend()`, stores result into `targetObject`. Logs serialised payload. |
| `execute()` | `override virtual global void` | Adds `REQUEST_PAYLOAD_<now>` attachment, calls `send()`, logs response. |
| `postExecute()` | `override virtual global void` | Calls `processResult(responseObject)`. |
| `send()` | `virtual global Object` | Default: `proxy.send(targetObject)`. Override for bespoke serialisation. |
| `getHttpRequestProxy(EventQueue)` | `virtual global BaseRestProxy` | Factory hook. Default returns `new RestProxy(event)`. Override to inject a custom proxy. |
| `tranformToSend()` | `global abstract Object` | **Required.** Build the DTO to send. Note the typo (`tranform` vs `transform`) — preserved for backward compatibility. |
| `processResult(Object)` | `global abstract void` | **Required.** Handle the response DTO. |

### `EventQueueActiveRecord`

`public abstract with sharing class EventQueueActiveRecord`

Active-record base extended by `EventQueue`. Loads the full
`Event_Configuration__mdt` set once in its constructor and caches it
by `Label` in `configbymetadataName`.

| Member | Signature | Purpose |
| --- | --- | --- |
| `getEventConfiguration(String)` | `public Event_Configuration__mdt` | Look up the config row by event name. |
| `hasHandlerFor(String)` | `public Boolean` | True if a mapping exists for this event name. |
| `save(Queue__c)` | `public Queue__c` | Insert or update one event. |
| `createAll(List<Queue__c>)` | `public static void` | Bulk insert. |
| `updateAll(List<Queue__c>)` | `public static void` | Bulk update. |
| `storePayloads(List<EventQueueFile>)` | `public static void` | Delegates to `EventQueueFileFacade`. Swallows and logs exceptions. |
| `findOne(String)` | `public Queue__c` | Load one `Queue__c` by id (reuses `findQueuedEvents`). |
| `findQueuedEvents(Set<String>)` | `public static List<Queue__c>` | SOQL by id. Returns a projection of common fields. |
| `hasQueuedEventsForBusinessDocument(String,String)` | `public Boolean` | Check if an event with `status = QUEUED` already exists for the same business doc. Used for deduplication. |
| `findLastEventsByNameAndBusinessDocumentNumber(String,String)` | `public List<Queue__c>` | Last 2 events for a business doc. |
| `findPendingQueuedEvents(DateTime, Integer)` | `public static List<Queue__c>` | Shortcut for status `SCHEDULED` older than cutoff. |
| `findPendingQueuedEvents(String[], DateTime, Integer)` | `public static List<Queue__c>` | Same with explicit status filter. |
| `findPendingQueuedEvents(EventQueueStatusType, Integer)` | `public static List<Queue__c>` | By status, no date filter. |
| `findEventsWithError(DateTime, Integer)` | `public static List<Queue__c>` | `status='ERROR'` AND `retryCount>0` AND `IsRetryDisabled=false`. |
| `findLastPayloadProcessedForEvent(String,String)` | `public List<EventQueueFile>` | Reads all `Attachment` records for the event and wraps them. Uses `WITH SECURITY_ENFORCED`. |
| `findEventTypeForObject(String,String)` | `public static List<Queue__c>` | All events of a given type on a given SF record id. |

Every read uses `Schema.sObjectType.*.isAccessible()` as a CRUD
gate; the one exception is `findLastPayloadProcessedForEvent` which
uses `WITH SECURITY_ENFORCED`.

## Domain

### `EventQueue`

`global class EventQueue extends EventQueueActiveRecord`

The core domain object. A rich wrapper around one `Queue__c` record
plus its attachments, in-memory log buffer, and resolved command.

| Member | Purpose |
| --- | --- |
| `event` — `Queue__c` | The underlying SObject. |
| `config` — `Event_Configuration__mdt` | The resolved command config. |
| `payloads` — `List<EventQueueFile>` | Pending attachments to flush on `save()`. |
| `processingLog` — `List<String>` | In-memory log lines. |
| `command` — `ICommand` (private) | The resolved strategy. |
| **Constructors** | `()`, `(Queue__c)`, `(EventType)`, `(Id)` |
| `init()` / `init(Queue__c)` | Initialise fields; copies `Payload__c` to an attachment and clears the field; resolves `config`. |
| `get()` | Return the underlying `Queue__c`. |
| `getPayload()` | Latest attached payload body, as String. |
| `getPayloadFromJson(Type)` | `JSON.deserialize(getPayload(), clazz)`. |
| `addPayload(String, String)` | Queue a new attachment (flushed on save). |
| `setPayload(String)` | Same as `addPayload(eventName, s)` if non-empty. |
| `getEventName()`, `getStatus()`, `getStackTrace()`, `getObjectId()`, `getEventId()` | Delegating getters. |
| `setStatus(String)`, `setObjectId(Id)` | Delegating setters. |
| **`process()`** | The dispatcher entry point. Handles UNHANDLED, builds the command, runs it, handles exceptions, decrements retries. |
| **`postExecute()`** | Runs `postUpdateExecute` on `IUpdatableCommmad` instances. Skipped for `IGNORED` and unhandled events. |
| `hasError()` / `isIgnored()` | Status convenience. |
| `getCommand()` | Instantiates the command via `CommandFactory`. |
| `setToUnhadledEvent()` | Status → `UNHANDLED` (sic: `Unhadled`). |
| `successfullyProcessedEvent()` | Status → `SUCCESS`, clears error fields. |
| `successfullyDeliveyEvent()` | Status → `DELIVERED`, clears error fields. (Only if not `IGNORED`.) |
| `errorProcessingEvent(Exception)` | Status → `ERROR`, persists message + stack trace. |
| `disableRetry()` (private) | `retryCount=0`, `IsRetryDisabled=true`. |
| `decreaseRetry()` (private) | Decrement `retryCount` (floor 0). |
| `isRequestDisabled()` | Returns `config.DisableDispatcher__c`. Not read by the packaged dispatcher. |
| `save()` | Flush log + payloads, insert/update the `Queue__c`. |
| `configEvent()` | Resolve `config` from `EventName__c`. |
| `getLastAttachedPayloadForEvent()` | Latest Attachment body. |
| `toString()` / `getEventInfo()` | `"Event [ <id> | <bizdoc> ] - <name>"`. |
| `log(String)` / `appendLog(String)` | Append to the in-memory buffer + `System.debug`. |
| `appendProcessLogToAttachament()` | Concatenate buffer, attach as `ExecutionTrace_<now>_<bizdoc>`, clear buffer. |
| `createAllEvents(List<EventQueue>)` | Bulk-insert events and their pending payloads. |

Constants:

- `DEQUEUE_QUEUED_BATCH_SIZE = 30`
- `DEQUEUE_ERROR_BATCH_SIZE = 30`

`webservice` fields (`id`, `eventName`, `outboundUrl`, `internalId`,
`sender`, `receiver`, `status`, `statusMessage`,
`businessDocumentNumber`, `businessDocumentCorrelatedNumber`) make the
class SOAP-addressable.

### `EventBuilder`

`public with sharing class EventBuilder`

Fluent builder for `Queue__c` (and, in convenience methods, for
`EventQueue`). See [../usage/enqueueing-events.md](../usage/enqueueing-events.md)
for usage. The class is annotated `@SuppressWarnings('PMD.ExcessivePublicCount')`
because PMD doesn't recognise the builder idiom.

Chainable methods: `createOutboundEventFor`, `createEventFor`,
`createEventBaseOn`, `forEvent`, `forObjectId`, `usingRetryStrategy`
(`retryCount=10`), `disablingRetryStrategy` (`retryCount=0`,
`IsRetryDisabled=true`), `withRetryCount`, `withSender`, `correlatedTo`
(parent lookup), `withSameDocumentNumberForAllIdentifiers`,
`withReceiver`, `withPayload`, `withStatus`, `withStatusMessage`,
`withBusinessDocumentNumber`, `withBusinessDocumentCorrelatedNumber`,
`withInternalID`.

Terminals: `build()` → `Queue__c`, `buildEvent()` → `EventQueue`,
`buildAndSave()` → saved `EventQueue`, `buildExternalEvent()` →
`EventQueue` populated from the builder's external-facing fields
(not persisted).

> ⚠️ `buildAndSave()` has a subtle bug: it declares a local
> `EventQueue event = new EventQueue(event);` which shadows the
> field. Works because the inner `event` resolves to the builder's
> `Queue__c event`, but the readability is poor. Tracked in
> [improvements.md](../improvements.md).

### `CommandFactory`

```apex
public class CommandFactory {
    public static ICommand createInstanceFor(String commandClassName) {
        Type commandType = Type.forName(commandClassName);
        return (ICommand) commandType.newInstance();
    }
}
```

Single static entry point. No caching, no error handling around
missing classes — `Type.forName(...)` returns `null` and
`newInstance()` throws `NullPointerException` if the class does not
exist. The caller (`EventQueue.process()`) catches this as a generic
`Exception` and decrements retry. See
[improvements.md](../improvements.md) for a suggested defensive check.

## Dispatch layer

### `EventQueueTriggerHandler`

`public with sharing class EventQueueTriggerHandler`

Runs in the constructor. Iterates `trigger.new`, filters `status = QUEUED`,
and batches into groups of `EventExecutor.FUTURE_CALL_SIZE` (5)
before calling `EventExecutor.processEvents(Map<String,String>)` per
batch. Skips itself when `System.isBatch()` or `System.isFuture()`
(prevents recursion, since `processEvents` is `@future`).

### `EventExecutor`

`public class EventExecutor implements Queueable, Database.AllowsCallouts`

The dispatcher. Two entry points matter:

1. **`processEvents(Map<String,String>)` `@future(callout=true)`** —
   called from the trigger handler. Loads queued events by id, runs
   the full lifecycle (see Flow 1).
2. **Static reprocess methods** called from scheduled jobs:
   - `processPendingEvents()` — `SCHEDULED` older than 120s → requeue.
   - `processOldQueuedEvents()` — `QUEUED` older than 600s → requeue.
   - `processErrorEvents()` — `ERROR` older than 60s with
     `retryCount>0` → requeue.

Plus a `Queueable.execute` implementation that, if constructed with
no events, finds `WORKFLOW` events and processes them via the future
path.

`processEvents(List<Queue__c>)` is the workhorse:

```
for each queue:
  EventQueue eq = new EventQueue(queue)
  eq.process()            // 1st pass (callout OK)
  events.add(eq)
for each eq:
  eq.postExecute()        // 2nd pass (DML OK)
  eq.appendProcessLogToAttachament()
  payloads += eq.payloads
EventQueueActiveRecord.updateAll(processingQueue)
EventQueueActiveRecord.storePayloads(payloads)
```

Constants:

- `FUTURE_CALL_SIZE = 5`

### Schedulable jobs

All three have the same shape — a `Schedulable` that calls
`EventExecutor.process*Events()` and a static pair
`start()` / `abort()` that wraps `ScheduleHelper`.

| Class | Delegate | Default interval |
| --- | --- | --- |
| `JobPendingEvents` | `EventExecutor.processPendingEvents()` | every 5 min |
| `JobOldQueuedEvents` | `EventExecutor.processOldQueuedEvents()` | every 9 min |
| `JobRetryEventProcessor` | `EventExecutor.processErrorEvents()` | every 8 min |

Each job also has a `public static Integer jobCountForTest = 0;`
field — a test hook to uniquify cron names during `@isTest` runs.

### `ScheduleHelper`

`public with sharing class ScheduleHelper`

Schedules a `Schedulable` at N-minute intervals across the hour by
emitting `60 / N` cron jobs:

```apex
new ScheduleHelper().scheduleIntoMinutesInterval(myJob, 5);
// → jobs at *:00, *:05, *:10, ..., *:55
```

Also exposes `abort(String jobName)` (uses `LIKE jobName%`) and
`findJobsByName(String)`.

## Integration helpers

### `BaseRestProxy`

`global virtual with sharing class BaseRestProxy`

Thin wrapper over `Http` / `HttpRequest`. Named-credential aware. Key
behaviour:

- Default timeout: 120000 ms.
- `setup()` validates the named credential via
  `EventQueueHelper.isNamedCredencialValid` (skipped in tests) and
  sets the endpoint to `callout:<name>`.
- `send(Object)` / `send(String)` / `get(Map<String,String>)` — public
  callout methods. All three go through `tryToSend(HttpRequest)`.
- `tryToSend` retries 3 times on `CalloutException` before
  rethrowing.
- `handleResponseStatus` throws `IntegrationException` for any status
  code != 200. Override `handleIntegrationErrorResponse` to customise
  per-command.
- `setContentType("json"|"url")` switches the Content-Type header.
  Note: the `"json"` branch is actually matched against the string
  `"son"` in the packaged code (bug; see
  [improvements.md](../improvements.md)).

### `RestProxy`

`public virtual class RestProxy extends BaseRestProxy`

Adds one override: `postSend()` attaches the response body to the
parent `EventQueue` as `RESPONSE_PAYLOAD_<now>`. Constructed with a
`Event_Configuration__mdt` or an `EventQueue`; the `EventQueue`
overload stores a back-reference for the attachment.

### Exceptions

| Class | Extends | Purpose |
| --- | --- | --- |
| `IntegrationException` | `Exception` | Technical failure. Ctor that accepts `HttpResponse` formats the message as `<code> : <status> [ <body> ]`. Triggers retry. |
| `IntegrationBusinessException` | `Exception` | Business failure. Ctor accepts an `IntegrationBusError`. Triggers **disable-retry**. |
| `IntegrationBusError` | POJO | `cod` + `message` pair. `isEmpty()` returns true if either is null. |
| `ExceptionType` | enum | `BUSINESS`, `TECHNICAL`. Informational — not referenced by the dispatcher. |

### `EventQueueHelper`

Single static method `isNamedCredencialValid(String)` that SOQLs the
`NamedCredential` object and returns true iff exactly one row matches.
Also (quirk) the CRUD gate is on `Queue__c`, not `NamedCredential`.

## Files / attachments

### `EventQueueFile`

DTO with `title`, `content` (Blob), `parentId`.

### `EventQueueFileFacade`

Single static method `createFilesForEventQueues(List<EventQueueFile>)`
that maps each DTO to an `Attachment` (name = `<title>.txt`,
`ContentType = 'txt'`) and inserts them in one DML.

### `EventQueueFileTitle`

Enum of canonical prefixes: `EXECUTION_TRACE`, `REQUEST_PAYLOAD`,
`RESPONSE_PAYLOAD`. The framework uses the **strings** directly
(concatenated with a timestamp), not the enum values; the enum is
documentation-only.

## Enums

### `EventType`

Registry of known event-type names. Ships with:

```apex
public enum EventType {
    BOOK_INBOUND_SERVICE,
    BOOK_OUTBOUND_SERVICE
}
```

The README instructs extenders to **add to this enum** for each new
event type, then register the matching `Event_Configuration__mdt`.

### `EventQueueStatusType`

Full lifecycle states (broader than the `Status__c` picklist):

```
SUCCESS, ERROR, QUEUED, DEQUEUED, DELIVERED, INVALID, DONE,
WAITING_EXTERNAL_SYSTEM, QUEUED_ON_EXTERNAL_SYSTEM, EMPTY, OVERRIDDEN,
UNHANDLED, WORKFLOW, PROCESSING, SCHEDULED, BATCH, WAITING, IGNORED
```

The dispatcher uses `QUEUED`, `DELIVERED`, `ERROR`, `UNHANDLED`,
`SCHEDULED`, `WORKFLOW`, `IGNORED`. The rest are reserved / unused.
See [status-lifecycle.md](./status-lifecycle.md).

## Test helpers

### `EventQueueFixtureFactory`

`@isTest`. Fixtures for tests:

- `createBaseEvent(String eventName)` — builds a fully populated
  `EventQueue` with `BIZDOC` document numbers, `1234` internal id,
  `SENDER`/`RECEIVER`.
- `createExternalEvent()` — returns a non-persisted `EventQueue` with
  its SOAP fields populated.
- `newB2dEventQueueFromJson()` / `newB2bEventQueueFromJson()` —
  deserialise canned JSON into an `EventQueue`.
- `getOrderInboundResultFromJson()` — canned inbound response.
- `findEventConfigMetadata()` — SOQL one `Event_Configuration__mdt`
  row.

### `HttpMock`

`@isTest global class HttpMock implements HttpCalloutMock`. Ctor
takes `(String response, Boolean success)` and returns 200 (success)
or 400 (failure) with the given body.

### `EventUnitTestCommand`

`@IsTest` command that is a no-op. Mapped via `Event_Configuration.EventUnitTest`.

### `MockThrowsExeceptionCommand`

`@isTest` command that logs and always throws `CalloutException`.
Implements both `ICommand` and `IUpdatableCommmad`. Mapped via
`Event_Configuration.EventUnitTestThrowsException`.

## Utilities

### `DateTimeHelper`

Two static helpers:

- `removeSencondsIntoCurrentDate(Integer s)` → `now - s seconds`.
- `removeSencondsIntoDate(DateTime t, Integer s)` → `t - s seconds`.

Note the typos (`Sencond`). Used by `EventExecutor` for cutoff
timestamps.

## Test classes (not listed above)

These mirror the production classes one-to-one and live next to them:

- `AbstractCommandTest`
- `AbstractOutboundCommandTest`
- `BaseRestProxyTest`
- `EventBuilderTest`
- `EventConsumerTest`
- `EventExecutorTest`
- `EventQueueTest`
- `JobOldQueuedEventsTest`
- `JobPendingEventsTest`
- `JobRetryEventProcessorTest`

See [../personas/qa.md](../personas/qa.md) for how to run them and
what each one covers.
