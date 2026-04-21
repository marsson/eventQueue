# Configuration

Everything dynamic about the framework lives in the
`Event_Configuration__mdt` custom metadata type. Each row maps one
event type to one Apex command.

## Step 1 — Register the event type in the `EventType` enum

Open `force-app/main/default/classes/EventType.cls` and add a value.
The name is the contract — it's the string that will appear in
`Queue__c.EventName__c` and in the `Event_Configuration__mdt` label.

```apex
public enum EventType {
    BOOK_INBOUND_SERVICE,
    BOOK_OUTBOUND_SERVICE,
    SMS_OUTBOUND_SERVICE  // <-- new
}
```

Naming rules (from the README):

- Upper snake case.
- Treat like a constant: `<DOMAIN>_<DIRECTION>_SERVICE`.
- Inbound ≠ Outbound: use two values for a round-trip integration.

## Step 2 — Implement the command class

Decide which base class to extend:

| Need | Base class |
| --- | --- |
| Local logic, no HTTP | `AbstractCommand` |
| Outbound HTTP callout | `AbstractOutboundCommand` |
| Callout **then** DML | `AbstractOutboundCommand` + `implements IUpdatableCommmad` |
| Something weird | Implement `ICommand` directly |

See
[../usage/implementing-a-command.md](../usage/implementing-a-command.md)
for worked examples.

## Step 3 — Create the `Event_Configuration__mdt` record

Three ways, same result.

### 3a — Via Setup UI

1. **Setup → Custom Metadata Types → Event Configuration → Manage Records → New**.
2. Label = DeveloperName = the Event Type key (e.g.
   `SMS_OUTBOUND_SERVICE`).
3. Fill:
   - `CommandClassName__c` — your Apex class name.
   - `DisableDispatcher__c` — leave unchecked unless you want a
     kill-switch.
   - `Method__c` — `POST` / `GET` / `DELETE` / `SOAP` (outbound only,
     ignored for inbound).
   - `NamedCredencial__c` — the developer name of the Named
     Credential (outbound only).
4. Save. The record deploys immediately in the current org.

### 3b — Via SFDX source

Create a file at:

```
force-app/main/default/customMetadata/Event_Configuration.SMS_OUTBOUND_SERVICE.md-meta.xml
```

```xml
<?xml version="1.0" encoding="UTF-8"?>
<CustomMetadata xmlns="http://soap.sforce.com/2006/04/metadata"
                xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                xmlns:xsd="http://www.w3.org/2001/XMLSchema">
    <label>SMS_OUTBOUND_SERVICE</label>
    <protected>false</protected>
    <values>
        <field>CommandClassName__c</field>
        <value xsi:type="xsd:string">SmsOutboundCommand</value>
    </values>
    <values>
        <field>DisableDispatcher__c</field>
        <value xsi:type="xsd:boolean">false</value>
    </values>
    <values>
        <field>Method__c</field>
        <value xsi:type="xsd:string">POST</value>
    </values>
    <values>
        <field>NamedCredencial__c</field>
        <value xsi:type="xsd:string">SmsProvider</value>
    </values>
</CustomMetadata>
```

Then `sf project deploy start`.

### 3c — Via Metadata API / Tooling API

Use `CustomMetadata` in a deployment. Useful for automated environment
provisioning.

## Step 4 — Confirm with the smoke test

```apex
EventQueue evt = new EventBuilder()
    .createEventFor('SMS_OUTBOUND_SERVICE')
    .withPayload('{"to":"+15551234567","body":"hi"}')
    .buildEvent();

evt.save();
System.debug(evt.getStatus()); // 'QUEUED', then the trigger fires
```

Wait a few seconds, then re-query:

```apex
Queue__c row = [SELECT Status__c, StatusMessage__c FROM Queue__c WHERE Id = :evt.getEventId()];
System.debug(row.Status__c);
```

Expected outcome is `DELIVERED` (happy path) or `ERROR` with a status
message you can act on.

## Gotchas

- **Label ≠ DeveloperName.** The Apex lookup in `EventQueueActiveRecord`
  keys by `Label`:
  ```apex
  configbymetadataName.put(conf.Label, conf);
  ```
  Always set Label == DeveloperName so the two remain in sync. The
  custom metadata UI defaults the two to match when you create the
  record, but they can diverge if edited.
- **The `DisableDispatcher__c` flag is hinted, not enforced.**
  `EventQueue.isRequestDisabled()` returns the value, but nothing in
  the packaged dispatcher short-circuits on it. To honour it, check
  the flag in your command's `execute()` and call `event.setStatus('IGNORED')`.
- **Field name typo:** `NamedCredencial__c` (Portuguese spelling).
  Keep it typed that way until the typo is fixed in a breaking
  release.
- **`Method__c` is restricted.** Values: `POST` (default), `GET`,
  `DELETE`, `SOAP`. `PUT`/`PATCH` are not in the picklist — if you
  need one, either add it to the picklist or override
  `BaseRestProxy.setup()` in a subclass.
