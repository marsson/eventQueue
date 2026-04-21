# Persona: Apex Developer

You're writing or extending commands — the business logic plugged
into the framework. You care about the extension contracts, the
testing helpers, and the pitfalls that Apex-specific limits impose.

## The short version

1. Add a value to `EventType`.
2. Write a class extending `AbstractCommand` or
   `AbstractOutboundCommand` (or implementing `ICommand`).
3. Map it via `Event_Configuration__mdt`.
4. Enqueue via `EventBuilder`.
5. Write a test that uses `EventQueueFixtureFactory.createBaseEvent`
   and (for callouts) `HttpMock`.

Detailed walkthrough:
[../usage/implementing-a-command.md](../usage/implementing-a-command.md).

## The mental model

```
Producer -> Queue__c (QUEUED)
         -> EventConsumer trigger
         -> EventExecutor.processEvents (@future callout=true)
         -> EventQueue.process()
         -> CommandFactory.createInstanceFor(config.CommandClassName__c)
         -> YOUR CLASS.execute(event)
         -> (IUpdatableCommmad) YOUR CLASS.postUpdateExecute(event)
         -> update Queue__c + attach logs
```

Full sequence: [../architecture/execution-flows.md](../architecture/execution-flows.md).

## What each base class gives you

| Base | Free machinery | When to use |
| --- | --- | --- |
| `ICommand` | nothing — just the contract. | Trivial one-liners. |
| `AbstractCommand` | `init / preExecute / execute / postExecute` template. | Local logic. |
| `AbstractOutboundCommand` | All of the above + `RestProxy` construction, payload logging, 3x callout retry, 2xx validation. | Any HTTP outbound. |
| + `implements IUpdatableCommmad` | A post-callout DML pass via `postUpdateExecute`. | When the response drives a DML update. |

## The callouts-before-DML rule

Apex won't let you DML then callout. `EventExecutor.processEvents`
solves this by splitting the two into separate passes:

```
pass 1: for each event -> command.execute()         (callout OK, no DML)
pass 2: for each event -> command.postUpdateExecute() (DML OK)
pass 3: updateAll(queueRecords); storePayloads(attachments);
```

**Practical rule:** if your command makes a callout, do **no** DML in
`execute()`. Put DML in `postUpdateExecute` and declare `implements
IUpdatableCommmad`.

## Payload handling

The packaged lifecycle:

1. Producer sets `Queue__c.Payload__c` or calls
   `event.addPayload(...)`.
2. On `save()`, the inline field is cleared; the payload is written
   as an `Attachment`.
3. Your command reads it with `event.getPayload()` (latest) or
   `event.getPayloadFromJson(MyClass.class)`.

This means the command always reads from the Attachment, regardless
of how the producer supplied it. Don't try to read `Queue__c.Payload__c`
directly.

## Logging

```apex
event.appendLog('Calling inventory API with orderId=' + order.Id);
```

- Written to `System.debug` synchronously.
- Buffered in `processingLog` until `save()` /
  `appendProcessLogToAttachament()` flushes the buffer into an
  `ExecutionTrace_<now>_<bizdoc>.txt` attachment.
- Keeps the trace available even when debug logs are off in prod.

## Error signalling

| To do | Throw |
| --- | --- |
| Retryable failure | `IntegrationException` (or any `Exception`) |
| Non-retryable (business) failure | `IntegrationBusinessException(new IntegrationBusError(code, message))` |
| Skip — treat as handled, no error | `event.setStatus('IGNORED')` + return |

## Testing

- `EventQueueFixtureFactory.createBaseEvent('EventUnitTest')` — a
  ready-made `EventQueue` you can call `.process()` on.
- `EventQueueFixtureFactory.newB2dEventQueueFromJson()` — deserialises
  a canned JSON body into an `EventQueue`.
- `HttpMock(body, isSuccess)` — simple mock for `BaseRestProxy`.
- `MockThrowsExeceptionCommand` — for exception-path coverage.
- `Test.startTest()` / `Test.stopTest()` — make sure future/queueable
  work executes inside your test.
- The default `Event_Configuration.EventUnitTest` metadata points at
  `EventUnitTestCommand` (no-op). Use it for generic pipeline tests.

## Coding conventions (enforced by the codebase)

- `@SuppressWarnings('PMD.AvoidGlobalModifier')` — the public API is
  `global` because subclasses live outside the namespace. Follow the
  same pattern when adding new classes meant for extension.
- `with sharing` is used consistently. Stay consistent unless you
  have a documented reason not to.
- CRUD gates: `if (Schema.sObjectType.<Obj>.isAccessible()) { ... }`
  around SOQL. `WITH SECURITY_ENFORCED` is used in some paths. Pick
  one approach and stick with it per query.
- Factories / builders have static `start()`, `abort()`, `build()`
  style methods. Mirror this in new helpers.

## Pitfalls (real, observed)

- **Don't amend the Apex enum `EventType` with arbitrary names** —
  the README's convention is `<DOMAIN>_<DIRECTION>_SERVICE`. The
  dispatcher doesn't actually consume the enum (it uses strings from
  `Event_Configuration__mdt`), but keeping the enum in sync is the
  agreed convention.
- **Don't assume `EventQueue` is only a wrapper around `Queue__c`** —
  it also owns the in-memory log and the list of pending attachments.
  Instantiating a second `EventQueue(queueRecord)` gives you a fresh
  log/payload list.
- **Don't call `event.save()` from inside your command** — the
  dispatcher bulk-saves at the end of a batch. Calling it yourself
  either creates duplicate attachments or splits the trace across
  two files.
- **`buildAndSave()` has a shadowed local `event`** in `EventBuilder`.
  Works, but if you need to subclass the builder, be careful.
- **Named-credential validation is skipped in tests** (`Test.isRunningTest()`
  check in `BaseRestProxy.setup()`). Your tests don't need to create
  `NamedCredential` rows, but also won't catch an invalid credential
  name until prod.
- **`setContentType("json")` is broken** (bug in `BaseRestProxy`;
  compares against `"son"`). Default is already JSON, so don't call
  it unless you're switching to URL-encoded.
- **`IUpdatableCommmad` is misspelled.** Don't "fix" the spelling —
  `Event_Configuration__mdt` references commands by string name and
  the permission set references the class. Renames are a breaking
  change.

## Cross-referenced reading

- [Apex class reference](../reference/apex-classes.md)
- [Interfaces & extension contracts](../reference/interfaces.md)
- [Data model](../architecture/data-model.md)
- [Status lifecycle](../reference/status-lifecycle.md)
- [Debugging](../debugging.md)
- [Improvements / revamp backlog](../improvements.md) — tech-debt
  notes worth reading before touching core classes.
