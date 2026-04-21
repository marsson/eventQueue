# Using the Platform Event `queueEvent__e`

## Why a platform event at all?

`Queue__c` is a standard object — fast enough for most use cases. But:

- An external system might not have DML access to `Queue__c` and
  prefer the Platform Event API (firehose, simpler auth model).
- A producer inside Salesforce might want to publish events **outside**
  its own transaction (no DML rollback semantics), e.g. a trigger
  that fires even if its transaction later fails.
- High-volume publishers benefit from `HighVolume` platform event
  throughput, then let the subscriber throttle into `Queue__c`.

`queueEvent__e` is the ingress channel for these cases. The published
platform event does **not** itself execute business logic — it's
translated into a `Queue__c` row by a subscriber, and the normal
dispatch takes over.

## What ships vs. what you have to add

| Component | Ships with package? |
| --- | --- |
| `queueEvent__e` platform event definition | ✅ yes |
| `queueProcessor.trigger` on `queueEvent__e` | ✅ yes, but **empty** |
| Translation from `queueEvent__e` → `Queue__c` | ❌ **you provide** |

The shipped trigger is:

```apex
trigger queueProcessor on queueEvent__e (after insert) {
    for (queueEvent__e event : Trigger.New) {
    }
}
```

It's a placeholder. A typical implementation:

```apex
trigger queueProcessor on queueEvent__e (after insert) {
    List<Queue__c> rows = new List<Queue__c>();
    for (queueEvent__e evt : Trigger.New) {
        rows.add(new Queue__c(
            EventName__c = evt.Event_Type__c,
            Payload__c = evt.Payload__c,
            ObjectId__c = evt.Related_sObject_Id__c,
            Status__c = EventQueueStatusType.QUEUED.name(),
            RetryCount__c = 10
        ));
    }
    insert rows;
}
```

> Overwriting a packaged trigger's body is not allowed in an unlocked
> package context — in a subscriber org you must either deploy a
> patched version of the package or create a local `@IsTest`
> subscriber pattern. In source-deployed mode (developing the
> framework itself), just edit `queueProcessor.trigger` directly.

## Publishing from Apex

```apex
EventBus.publish(new queueEvent__e(
    Event_Type__c = 'SMS_OUTBOUND_SERVICE',
    Payload__c = JSON.serialize(smsPayload),
    Related_sObject_Id__c = contact.Id
));
```

Because the platform event has `publishBehavior = PublishAfterCommit`,
the event fires **only if** the enclosing transaction commits. This is
good for Salesforce-internal producers that want "publish only when
the DML I just did actually sticks".

## Publishing from an external system

Use the Salesforce streaming/event API:

```
POST /services/data/v60.0/sobjects/queueEvent__e/
{
  "Event_Type__c": "INBOUND_ORDER_SERVICE",
  "Payload__c": "...json...",
  "Related_sObject_Id__c": "a0B.......0001"
}
```

The external producer needs a user with API access and permission to
create `queueEvent__e` (platform events have their own permission
model — add to a permission set if your subscriber org restricts it).

## Ordering guarantees

Platform events provide **no** strict ordering across publishers. If
your integration relies on event ordering, either:

- Publish `Related_sObject_Id__c` and let the subscriber merge;
- Or publish directly to `Queue__c` and rely on
  `ExternalCreationDate__c` to order events at processing time.

## Why not execute directly from `queueProcessor`?

The framework's reliability features (retry, stack-trace storage,
attachments, UI visibility) all live on `Queue__c`. Running the
command straight from the platform event subscriber would mean:

- No persistent audit trail.
- No retry on failure.
- No admin visibility (you can't "see" a platform event record after
  it's processed).

So the subscriber's job is deliberately boring: translate, insert,
let the trigger take over.

## Test recipe

```apex
@isTest
static void publishQueueEvent_createsQueueRow() {
    Test.startTest();

    EventBus.publish(new queueEvent__e(
        Event_Type__c = 'EventUnitTest',
        Payload__c = 'hello'
    ));

    Test.stopTest(); // delivers the platform event synchronously

    Queue__c row = [SELECT EventName__c, Status__c FROM Queue__c LIMIT 1];
    System.assertEquals('EventUnitTest', row.EventName__c);
    // Status depends on whether the trigger also fired the dispatcher
    // in the same test transaction; typically 'DELIVERED' after Test.stopTest.
}
```

## Volume considerations

- `queueEvent__e` is defined as `HighVolume` → up to 250,000
  publishes per day on enterprise edition (check your org's
  entitlement).
- Each translation `queueEvent__e → Queue__c` is one DML, so the
  standard `Queue__c`-side governor limits still apply.
- The trigger handler in `EventQueueTriggerHandler` batches by 5 into
  `@future` calls, so a burst of 1000 events will spawn ~200 future
  invocations. Salesforce limits futures per transaction — monitor
  in high-volume scenarios.
