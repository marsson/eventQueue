# Metadata Components Reference

All metadata components the package ships with, grouped by type. Use
this page to understand exactly what gets deployed to a subscriber
org.

## Custom Object — `Queue__c`

- Label: **Event Queue** / **Event Queues**
- Name field: autonumber `{0000000000}` tracked for history
- Sharing: `ReadWrite` (internal), Private (external)
- Deployment status: `Deployed`
- Bulk API: enabled • Streaming API: enabled • History: enabled •
  Reports: enabled
- Compact layout: `SYSTEM`
- Description: _"Responsavel por prover garantia de entrega para camada de integração"_

See [data-model.md](../architecture/data-model.md#queue__c-the-event)
for the complete field-level inventory.

List views shipped:

- `All`
- `AllToday`

Web links:

- `Delete` (custom list-view button)

Page layout:

- `Queue__c-EventQueue Layout`

Lightning page:

- `Event_Queue_Record_Page` (FlexiPage)

## Custom Object — `Event_Configuration__mdt`

- Type: Custom Metadata Type
- Visibility: Public
- Fields: `CommandClassName__c`, `DisableDispatcher__c`, `Method__c`,
  `NamedCredencial__c` — see
  [data-model.md](../architecture/data-model.md#event_configuration__mdt-the-mapping-table).

Shipped records (custom metadata):

| File | DeveloperName | Command | Named Credential | Method |
| --- | --- | --- | --- | --- |
| `Event_Configuration.BOOK_INBOUND_SERVICE.md-meta.xml` | `BOOK_INBOUND_SERVICE` | `BookInboundCommand` | — | — |
| `Event_Configuration.BOOK_OUTBOUND_SERVICE.md-meta.xml` | `BOOK_OUTBOUND_SERVICE` | `BookOutboundCommand` | `BookOutboundHeroku` | POST |
| `Event_Configuration.PARK_OUTBOUND_SERVICE.md-meta.xml` | `PARK_OUTBOUND_SERVICE` | `ParkOutboundCommand` | — | POST |
| `Event_Configuration.EventUnitTest.md-meta.xml` | `EventUnitTest` | `EventUnitTestCommand` | `BookOutboundHeroku` | POST |
| `Event_Configuration.EventUnitTestThrowsException.md-meta.xml` | `EventUnitTestThrowsException` | `MockThrowsExeceptionCommand` | — | POST |

> The `BOOK_*` and `PARK_*` records reference command classes
> (`BookInboundCommand`, `BookOutboundCommand`, `ParkOutboundCommand`)
> that are **not** present in the package source. A subscriber org
> must either implement those classes or remove the rows.

Page layout: `Event_Configuration__mdt-Event Configuration Layout`.

## Platform Event — `queueEvent__e`

- Event type: `HighVolume`
- Publish behavior: `PublishAfterCommit`
- Description: _"Platform events for the creation of async event queues."_

Fields:

| API name | Type | Required |
| --- | --- | --- |
| `Event_Type__c` | Text(255) | yes |
| `Payload__c` | LongText(131072) | no |
| `Related_sObject_Id__c` | Text(18) | no |

Subscriber: `queueProcessor.trigger` (**empty** in the package).

## Triggers

| File | On | Event | Logic |
| --- | --- | --- | --- |
| `EventConsumer.trigger` | `Queue__c` | after insert, after update | Instantiates `new EventQueueTriggerHandler()` which batches `QUEUED` records into `@future` dispatch calls. |
| `queueProcessor.trigger` | `queueEvent__e` | after insert | **Empty** — placeholder for subscriber translation. |

## Apex classes

Full list in [apex-classes.md](./apex-classes.md). At deploy time
both permission sets must be assigned for a user/running context to
invoke any of these classes.

## Permission Sets

Two permission sets ship with the package:

### `Event_Queue_Admin`

- Label: **Event Queue Admin**
- Description: _"Permission set for Event Queue admins, that need access to the app, tabs and objects."_
- Application visibility: `Event_Queue` → visible
- Tab settings: `Queue__c` → `Visible`
- Object permissions on `Queue__c`: **Create, Edit, Delete, Read,
  ViewAllRecords, ModifyAllRecords**
- Field permissions: all 14 custom fields of `Queue__c` → readable+editable
- Apex class access: every Apex class in the package (including the
  test classes — this is unusual and called out in
  [improvements.md](../improvements.md)).
- System permissions: `CustomizeApplication`, `ManageCustomPermissions`,
  `ViewRoles`, `ViewSetup`.

### `Event_Queue_Running_User`

- Intended for the integration / automation user that executes the
  scheduled jobs.
- Grants Apex class access to every class in the package.
- **Does not grant** the `Queue__c` tab, app visibility, or record
  permissions (those are admin-only).

Assign this permission set to:

- The user running `JobPendingEvents.start()`,
  `JobOldQueuedEvents.start()`, `JobRetryEventProcessor.start()`.
- Any Apex/REST context that needs to instantiate commands.

## Applications & UI

### Lightning App — `Event_Queue`

- Label: **Event Queue**
- Nav type: Standard (tabbed)
- UI type: Lightning
- Form factors: Small + Large
- Header color: `#0070D2`
- Utility bar: `Event_Queue_UtilityBar`
- Tabs: `Queue__c`

### Tabs

- `Queue__c.tab-meta.xml`

### FlexiPages

- `Event_Queue_Record_Page.flexipage-meta.xml` — record page for a single event.
- `Event_Queue_UtilityBar.flexipage-meta.xml` — utility bar for the app.

### Layouts

- `Queue__c-EventQueue Layout.layout-meta.xml`
- `Event_Configuration__mdt-Event Configuration Layout.layout-meta.xml`

## LWC / Aura

The `lwc/` and `aura/` folders exist but contain **only** lint config
(`.eslintrc.json`, `tsconfig.json`). No components are shipped.

## `.forceignore`, config, and manifest

- `.forceignore` — excludes `.sf/`, `.sfdx/`, `.idea/` etc. from
  deploys.
- `config/project-scratch-def.json` (typical scratch-org definition,
  if present).
- `manifest/` — stock `package.xml` for legacy metadata deploys.
- `sfdx-project.json` — declares two package directories:
  - `Asyncronous Queue` (legacy name, typo preserved).
  - `async_queue` (current, with namespace `async_queue` and aliases
    for 0.1.0-1, 0.1.1-1, 0.1.2-1).

See [../setup/installation.md](../setup/installation.md) for how to
install each package version.
