# Enqueueing Events

There are four supported ways to create a `Queue__c` event. Pick the
one that matches your producer.

## 1. `EventBuilder` — from Apex (recommended)

The fluent builder is the idiomatic path:

```apex
EventQueue evt = new EventBuilder()
    .createOutboundEventFor('BOOK_OUTBOUND_SERVICE')
    .forObjectId(order.Id)
    .withBusinessDocumentNumber(order.OrderNumber)
    .withBusinessDocumentCorrelatedNumber(order.OriginalOrderNumber__c)
    .withInternalID(order.ExternalId__c)
    .withReceiver('HEROKU')
    .withPayload(JSON.serialize(new OrderDTO(order)))
    .buildAndSave();
```

Notes:

- `createOutboundEventFor(...)` defaults `sender = 'SALESFORCE'` and
  `retryCount = 10`.
- `createEventFor(...)` is the raw constructor — same things,
  without the sender/retry defaults.
- `buildAndSave()` returns a persisted `EventQueue` — the row is
  inserted and the `EventConsumer` trigger fires.
- `build()` returns a `Queue__c` SObject for when you want to batch
  DML yourself.

## 2. `EventQueue` constructors

Sometimes you already have a `Queue__c` record (from Flow, from a
REST endpoint, from an integration object). Wrap it:

```apex
EventQueue evt = new EventQueue(queueRow);
evt.setPayload(rawPayload);
evt.save();
```

Available constructors:

| Signature | Use |
| --- | --- |
| `new EventQueue()` | Empty container. Set fields and call `save()`. |
| `new EventQueue(Queue__c queue)` | Wrap an existing SObject. |
| `new EventQueue(EventType type)` | Create a new row with `EventName__c = type.name()`. |
| `new EventQueue(Id id)` | Load an existing row by id. |

## 3. Direct DML on `Queue__c`

Anything that ends up inserting a `Queue__c` with `Status__c = 'QUEUED'`
triggers the dispatcher. Perfectly valid from:

- **Flow / Process Builder** — "Create Records" action, target
  `Queue__c`, set `Status__c = QUEUED`.
- **Apex** — `insert new Queue__c(EventName__c = 'X', Status__c = 'QUEUED', Payload__c = '{...}')`.
- **REST** — a custom `@RestResource` that maps JSON to `Queue__c`
  and inserts.

Use this path when you want to avoid the Apex dependency on
`EventBuilder`.

## 4. Platform event `queueEvent__e`

For high-volume or external producers that can't/shouldn't commit DML
directly on `Queue__c`:

```apex
EventBus.publish(new queueEvent__e(
    Event_Type__c = 'SMS_OUTBOUND_SERVICE',
    Payload__c = JSON.serialize(smsPayload),
    Related_sObject_Id__c = contact.Id
));
```

The subscriber is `queueProcessor.trigger`. The package ships it
empty — you must add the translation from platform event to
`Queue__c` yourself. See [platform-events.md](./platform-events.md).

## Required fields on insert

| Field | Required? | Source if you don't set it |
| --- | --- | --- |
| `EventName__c` | **yes** | — |
| `Status__c` | must be `QUEUED` for the dispatcher to act | defaults to blank — the dispatcher won't process a blank-status row |
| `RetryCount__c` | no | field default: **10** |
| `IsRetryDisabled__c` | no | field default: false |
| `ExternalCreationDate__c` | no | field default: `NOW()` |

Set `Payload__c` on insert; the framework moves it to an Attachment
on first `save()` and clears the field.

## Chaining events (`parentEvent__c`)

When one business process produces multiple events, link them via the
self-lookup:

```apex
Queue__c parent = /* ... */;
new EventBuilder()
    .createEventFor('STOCK_RESERVATION_SERVICE')
    .correlatedTo(parent.Id)
    .build();
```

`parentEvent__c` uses `SetNull` delete semantics and the relationship
name is `correlateds` (so you can SOQL `Queue__c.correlateds`).

## Deduplication

The framework ships a primitive dedup helper:

```apex
boolean alreadyQueued = new EventQueueActiveRecord()
    // ... use the public hasQueuedEventsForBusinessDocument instance
    ;
```

Specifically:

```apex
EventQueue probe = new EventQueue(new Queue__c());
if (probe.hasQueuedEventsForBusinessDocument('BOOK_OUTBOUND_SERVICE', orderNumber)) {
    return; // already pending
}
```

This only checks for **`QUEUED`** events. If your concern is "don't
fire the same event while one is already in-flight", this is the
check you want. If you need idempotency across `DELIVERED` events
too, you have to write your own SOQL.

## Setting the payload

Two ways, they do the same thing:

```apex
// builder
.withPayload(jsonString)

// post-build
evt.setPayload(jsonString);
evt.save();

// programmatic (multiple named payloads)
evt.addPayload('BOOKING_INPUT', jsonString);
```

The framework always stores payloads as `Attachment` records on the
`Queue__c`. The inline `Payload__c` field is an ingest channel only —
it's cleared on save.

## Turning a stored payload back into an object

Inside your command:

```apex
override public void init(EventQueue event) {
    super.init(event);
    this.order = (OrderDTO) event.getPayloadFromJson(OrderDTO.class);
}
```

`getPayloadFromJson(Type)` reads the latest Attachment via
`findLastPayloadProcessedForEvent(...)` and deserialises it.

## Smoke-test recipe

```apex
EventQueue evt = new EventBuilder()
    .createEventFor('EventUnitTest')
    .withPayload('ping')
    .buildAndSave();

System.debug(evt.getEventId()); // a real Id
// Wait a few seconds, then:
Queue__c row = [SELECT Status__c FROM Queue__c WHERE Id = :evt.getEventId()];
System.assertEquals('DELIVERED', row.Status__c);
```
