# Persona: QA / Tester

You verify that the Event Queue and its commands behave correctly
under happy-path, retry, and failure conditions. You write Apex test
classes and run `@isTest` suites. You may also run manual smoke tests
from the Developer Console or through UI actions.

## Shipped test classes (one-to-one with production)

| Test class | Covers |
| --- | --- |
| `EventQueueTest` | Happy path, unhandled events, basic builder/save flow. |
| `EventConsumerTest` | Trigger-side batching. |
| `EventExecutorTest` | Synchronous dispatcher, `reprocess`, `processPendingEvents`, `processOldQueuedEvents`, `processErrorEvents`. |
| `AbstractCommandTest` | Template-method invocation order + opt-in decoration. |
| `AbstractOutboundCommandTest` | Outbound command lifecycle with HTTP mocks. |
| `BaseRestProxyTest` | Proxy setup, retry, error handling. |
| `EventBuilderTest` | Fluent builder outputs. |
| `JobPendingEventsTest`, `JobOldQueuedEventsTest`, `JobRetryEventProcessorTest` | Each scheduled job's `start/abort` and delegation. |

## Running tests

### From CLI

```bash
# Full suite with coverage
sf apex run test --target-org queuePOC --code-coverage --result-format human --wait 30

# Specific class
sf apex run test --target-org queuePOC --class-names EventQueueTest --wait 30

# Specific method
sf apex run test --target-org queuePOC --tests EventQueueTest.givenKnowEventWhenProcessThisYourStatusIsSucess --wait 30
```

### From the Developer Console

**Test → New Run**, select classes, Run.

### Coverage expectations

Salesforce requires ≥75% coverage for production deploys. The
package has been packaged for years and meets that bar. When
extending, **every new command** should ship with tests that cover:

- Happy path → `DELIVERED`.
- Business failure → `ERROR` + `IsRetryDisabled = true`.
- Technical failure → `ERROR` + `RetryCount -= 1`.
- If two-phase: `postUpdateExecute` runs and applies DML.

## Test helpers (use these — don't reinvent)

### `EventQueueFixtureFactory`

```apex
EventQueue evt = EventQueueFixtureFactory.createBaseEvent('MY_EVENT_NAME');
```

Pre-populates:

- `businessDocument__c = 'BIZDOC'`
- `businessDocumentCorrelatedNumber__c = 'BIZDOC'`
- `internalId__c = '1234'`
- `sender__c = 'SENDER'`, `receiver__c = 'RECEIVER'`
- `retryCount__c = 10`

### `HttpMock`

```apex
Test.setMock(HttpCalloutMock.class, new HttpMock('{"ok":true}', true));   // HTTP 200
Test.setMock(HttpCalloutMock.class, new HttpMock('bad request', false)); // HTTP 400
```

### `MockThrowsExeceptionCommand` / `EventUnitTestCommand`

Two `@isTest` commands mapped via `Event_Configuration.EventUnitTest`
(no-op) and `Event_Configuration.EventUnitTestThrowsException` (throws).
Use these to exercise the dispatcher's error handling without writing
a real command.

## Manual smoke tests (no Apex writing)

### 1. Happy-path dispatch

```apex
EventQueue evt = EventQueueFixtureFactory.createBaseEvent('EventUnitTest');
evt.process();
System.assertEquals('DELIVERED', evt.getStatus());
```

### 2. Unhandled event

```apex
EventQueue evt = EventQueueFixtureFactory.createBaseEvent('TOTALLY_NOT_A_REAL_EVENT');
evt.process();
System.assertEquals('UNHANDLED', evt.getStatus());
```

### 3. Technical failure + retry decrement

```apex
EventQueue evt = EventQueueFixtureFactory.createBaseEvent('EventUnitTestThrowsException');
Integer before = (Integer) evt.get().RetryCount__c;
evt.process();
System.assertEquals('ERROR', evt.getStatus());
System.assertEquals(before - 1, (Integer) evt.get().RetryCount__c);
System.assertEquals(false, evt.get().IsRetryDisabled__c);
```

### 4. End-to-end trigger path

```apex
Test.startTest();
Queue__c q = new Queue__c(
    EventName__c = 'EventUnitTest',
    Status__c = 'QUEUED',
    RetryCount__c = 10
);
insert q;
Test.stopTest(); // force @future to execute

Queue__c after = [SELECT Status__c FROM Queue__c WHERE Id = :q.Id];
System.assertEquals('DELIVERED', after.Status__c);
```

### 5. Retry loop

```apex
Queue__c q = new Queue__c(
    EventName__c = 'ANYTHING',
    Status__c   = 'ERROR',
    RetryCount__c = 5,
    IsRetryDisabled__c = false,
    ExternalCreationDate__c = System.now().addMinutes(-10)
);
insert q;

Test.startTest();
EventExecutor.processErrorEvents();
Test.stopTest();

Queue__c after = [SELECT Status__c FROM Queue__c WHERE Id = :q.Id];
// Should flip to QUEUED if it matched the filter (age>60s, retryCount>0)
```

## What to verify per command

| Scenario | Expected state | Attachment(s) expected |
| --- | --- | --- |
| Happy path | `DELIVERED`, `StatusMessage__c` empty, `ExceptionStackTrace__c` empty | `ExecutionTrace_*`. If outbound: `REQUEST_PAYLOAD_*`, `RESPONSE_PAYLOAD_*`. |
| Business failure | `ERROR`, `IsRetryDisabled=true`, `RetryCount=0` | `ExecutionTrace_*` with the exception and its `getTypeName()` in `StatusMessage__c`. |
| Technical failure | `ERROR`, `IsRetryDisabled=false`, `RetryCount` decreased by 1 | `ExecutionTrace_*`. |
| Unhandled | `UNHANDLED`, no retry | `ExecutionTrace_*` (just entry/exit lines). |
| Two-phase success | `DELIVERED`, external Salesforce DML executed | Trace shows both `execute` and `postUpdateExecute`. |

## Regression areas to keep an eye on

- **`@future` vs `Queueable` vs `Schedulable` transitions** —
  `EventQueueTriggerHandler` skips itself inside `System.isFuture()`
  or `System.isBatch()`. Changing that guard can cause infinite
  recursion.
- **Callouts-before-DML** — any refactor of `EventExecutor.processEvents`
  must keep the two-pass structure.
- **Named credential validation in tests** —
  `BaseRestProxy.setup()` skips it when `Test.isRunningTest()` is
  true. Tests passing doesn't mean production will find the
  credential.
- **CRUD gates** — `EventQueueActiveRecord` uses
  `Schema.sObjectType.Queue__c.isAccessible()` on nearly every query.
  Running tests as the admin user hides permission problems; consider
  `System.runAs(someLowPrivUser)` for representative coverage.
- **Attachment vs ContentVersion** — payloads are stored as
  `Attachment`. Salesforce has been deprecating Attachment for years.
  If your org has "Enable enhanced file management" turned on in a
  surprising way, the tests may need to adapt.

## How to reproduce a real production incident

1. Export the failing `Queue__c` as JSON.
2. In a sandbox, create a matching row:
   ```apex
   Queue__c q = (Queue__c) JSON.deserialize(json, Queue__c.class);
   insert q;
   ```
3. Run `new EventQueue(q).process();` with the same Named Credential
   setup (or a `HttpMock` replaying the production response body, if
   you have it in `RESPONSE_PAYLOAD_*`).
4. Inspect the resulting `ExecutionTrace_*` attachment.

Production attachments **include the full request body** — never
attach them to a Jira or support ticket without redaction.
