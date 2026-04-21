# Design Patterns in the Event Queue

The framework is small but pattern-dense. This page catalogues every
pattern in use, where it lives, and why it was chosen. Patterns are
discussed in roughly the order they appear in a request flow.

## 1. Command (GoF)

**Intent:** encapsulate a request as an object so it can be queued,
logged, retried, and undone independently of the caller.

**Where:**

- `ICommand` — the abstract request.
- `IUpdatableCommmad` (note: intentional typo preserved) — extended
  command for work that must be split across callout and DML phases.
- `AbstractCommand` / `AbstractOutboundCommand` — shipped base
  implementations.
- `CommandFactory.createInstanceFor(String)` — resolves the command
  class dynamically from configuration.
- `EventQueue.process()` — the invoker.
- `Queue__c` — the "command log" (the serialised request).

**Why this pattern:** it is the structural reason the framework exists.
By making each unit of work an object that can be serialised to a
record, the system gets persistence, retry, audit, and extension in
one go.

## 2. Template Method (GoF)

**Intent:** fix the skeleton of an algorithm in a base class and let
subclasses override named steps.

**Where:** `AbstractCommand.execute(EventQueue)`:

```
init(event) → preExecute() → execute() → postExecute()
```

Subclasses override any step. `execute()` (no-arg) is the only
`abstract` method, so extenders are forced to implement the core
behaviour. `AbstractOutboundCommand` reuses the same template but
specialises each hook around an HTTP callout:

```
init → build proxy from NamedCredential
preExecute → targetObject = transformToSend()
execute → send() + log REQUEST_PAYLOAD / RESPONSE_PAYLOAD
postExecute → processResult(responseObject)
```

## 3. Abstract Factory (GoF — simplified Factory Method)

**Intent:** produce an `ICommand` without the caller knowing which
concrete class was configured.

**Where:** `CommandFactory.createInstanceFor(String)` uses
`Type.forName(...)` + `newInstance()` to instantiate the class whose
name was read from `Event_Configuration__mdt.CommandClassName__c`.

The "configuration → class name → new instance" indirection is what
makes the framework extensible in a packaged context.

## 4. Strategy (GoF)

**Intent:** interchange algorithms at runtime based on configuration.

**Where:** each Event Type maps to one command class. The same
dispatcher can therefore run any mix of inbound, outbound, or workflow
logic. Metadata flips the strategy without code change.

## 5. Active Record (PoEAA / Fowler)

**Intent:** an object carries both its persistent data and the
behaviour to load/save itself.

**Where:** `EventQueueActiveRecord` (abstract) exposes:

- `findOne`, `findQueuedEvents`, `findEventsWithError`,
  `findPendingQueuedEvents`, `findLastEventsByNameAndBusinessDocumentNumber`
- `save(Queue__c)`, `updateAll(List<Queue__c>)`,
  `createAll(List<Queue__c>)`
- `storePayloads(List<EventQueueFile>)`
- `hasHandlerFor`, `getEventConfiguration`

`EventQueue` extends this so any command receives a rich object that
understands its own persistence.

## 6. Facade (GoF)

**Intent:** expose a coarse-grained API over a subsystem.

**Where:** `EventQueueFileFacade.createFilesForEventQueues(List<EventQueueFile>)`
hides the conversion from `EventQueueFile` → `Attachment` + `insert`.
The rest of the code only sees the DTO and the facade call.

Also, `EventQueue` itself is a facade over `Queue__c` + its
attachments + the command + the log buffer.

## 7. Builder (GoF / fluent interface)

**Intent:** assemble a complex object through chained, readable calls.

**Where:** `EventBuilder` builds a `Queue__c` (and optionally an
`EventQueue`) through a fluent API:

```apex
new EventBuilder()
    .createOutboundEventFor('BOOK_OUTBOUND_SERVICE')
    .forObjectId(order.Id)
    .withBusinessDocumentNumber(order.OrderNumber)
    .withPayload(JSON.serialize(dto))
    .build();
```

Defaults live on the builder (`usingRetryStrategy` sets
`retryCount = 10`; `createOutboundEventFor` also forces `sender =
'SALESFORCE'`).

## 8. Proxy (GoF — with Decorator overlay)

**Intent:** stand in for a remote resource and add cross-cutting
behaviour (logging, retries, content-type handling).

**Where:**

- `BaseRestProxy` — the proxy. Wraps `Http`, `HttpRequest`,
  `HttpResponse`. Handles named-credential resolution, retry on
  `CalloutException` (3 attempts), body serialization, status-code
  handling.
- `RestProxy` — a **decorator** that extends `BaseRestProxy` and
  overrides `postSend()` to attach the raw response body to the
  parent `EventQueue` as a payload file.

## 9. Null Object / Graceful Degradation

`EventQueue.process()` checks `hasHandlerFor(eventName)`. If no
`Event_Configuration__mdt` is found, the event transitions to
`UNHANDLED` instead of crashing. This is effectively a null-object
treatment of "missing command".

## 10. Deferred DML / Unit of Work (light)

`EventExecutor.processEvents(List<Queue__c>)` executes commands in a
first pass (callout-capable), then walks the list again to call
`event.postExecute()` for commands that implement `IUpdatableCommmad`,
and finally `updateAll(processingQueue)` + `storePayloads(payloads)`
in one shot. This keeps DML out of the callout phase (Apex runtime
constraint: no DML before callout unless the prior DML is rolled back).

## 11. Scheduler / Self-Registering Cron

`ScheduleHelper.scheduleIntoMinutesInterval(Schedulable, Integer)`
auto-generates cron expressions that fire every N minutes (e.g.
every 5 minutes → 12 cron jobs at `0 00 * * * ?`, `0 05 * * * ?`,
`0 10 * * * ?`, …).

Each `Job*` class exposes `start()` / `abort()` static methods, so an
admin can schedule/unschedule from the Developer Console with a one-liner.

## 12. Typed Exceptions (Domain vs Technical)

Two exception families signal intent to the retry engine:

- `IntegrationBusinessException` → a **business** failure. The event
  transitions to `ERROR` **and** `IsRetryDisabled__c = true`; no
  automated retry. Typical: validation errors, 4xx business payloads.
- `IntegrationException` / generic `Exception` → a **technical**
  failure. Retry counter is decremented; the scheduler will pick it
  up again until `RetryCount__c = 0`.

The `ExceptionType` enum (`BUSINESS`, `TECHNICAL`) documents the
distinction even though it is not programmatically referenced in the
current dispatcher.

## 13. Enum-as-Registry

- `EventType` — registry of known event-type names. Used as a
  compile-time catalogue (`EventType.BOOK_INBOUND_SERVICE.name()`).
- `EventQueueStatusType` — lifecycle states.
- `EventQueueFileTitle` — canonical attachment-title prefixes
  (`EXECUTION_TRACE`, `REQUEST_PAYLOAD`, `RESPONSE_PAYLOAD`).

## 14. Bulkification pattern (Apex-specific)

`EventQueueTriggerHandler` splits `trigger.new` into sub-batches of
`EventExecutor.FUTURE_CALL_SIZE` (5), because `@future(callout=true)`
is limited to 50 invocations per transaction and each future call has
its own callout limit. This is the "chunk and dispatch" idiom common
in Salesforce integration code.

## Pattern → class map

| Pattern | Primary classes |
| --- | --- |
| Command | `ICommand`, `IUpdatableCommmad`, `AbstractCommand`, `AbstractOutboundCommand` |
| Template Method | `AbstractCommand`, `AbstractOutboundCommand` |
| Factory | `CommandFactory` |
| Strategy | Event Type → Command mapping via `Event_Configuration__mdt` |
| Active Record | `EventQueueActiveRecord`, `EventQueue` |
| Facade | `EventQueueFileFacade`, `EventQueue` |
| Builder | `EventBuilder` |
| Proxy + Decorator | `BaseRestProxy`, `RestProxy` |
| Scheduler | `ScheduleHelper`, `JobPendingEvents`, `JobOldQueuedEvents`, `JobRetryEventProcessor` |
| Typed exceptions | `IntegrationException`, `IntegrationBusinessException`, `IntegrationBusError`, `ExceptionType` |
| Test fixture | `EventQueueFixtureFactory`, `HttpMock`, `MockThrowsExeceptionCommand`, `EventUnitTestCommand` |
