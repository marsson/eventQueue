# Permissions

The package ships two permission sets. Assign one or both depending
on the user.

| Permission set | Who gets it | What it grants |
| --- | --- | --- |
| `Event_Queue_Admin` | Humans: admins, developers, support. | App + tab + object + field + Apex class + system permissions. |
| `Event_Queue_Running_User` | Automation: integration users, running user for scheduled jobs. | Apex class access only (no UI access). |

## `Event_Queue_Admin` — details

- **App:** `Event_Queue` visible.
- **Tab:** `Queue__c` visible.
- **Object:** `Queue__c` — Create, Read, Edit, Delete, View All, Modify All.
- **Fields:** all 14 custom fields of `Queue__c` editable+readable.
- **Apex class access:** every Apex class in the package (production
  and test).
- **System permissions:** `CustomizeApplication`,
  `ManageCustomPermissions`, `ViewRoles`, `ViewSetup`.

Typical recipients:

- Salesforce administrators.
- Developers extending the framework.
- Tier-2 support who need to triage and retry failed events.

## `Event_Queue_Running_User` — details

- **Apex class access:** every Apex class in the package.
- **No** object, field, tab, or app visibility.

Typical recipients:

- The integration / automation user that runs `start()` for the
  three scheduled jobs. The running user executes the scheduled
  `Schedulable`, which reaches into `EventExecutor` and therefore
  every packaged class.
- The user associated with Named Credentials if they also invoke the
  framework (e.g. a REST service layer).

## Assignment

Via the UI: **Setup → Permission Sets → Event Queue Admin →
Manage Assignments → Add Assignments**.

Via CLI:

```bash
sf org assign permset --name Event_Queue_Admin --target-org queuePOC
sf org assign permset --name Event_Queue_Running_User --target-org queuePOC
```

## Object-level access hardening

The framework's dispatcher runs `with sharing` and uses
`Schema.sObjectType.Queue__c.isAccessible()` as a defensive gate on
every SOQL. In practice this means:

- A user **without** `Queue__c` read access will see empty result
  sets from the active-record queries. The dispatcher will silently
  skip work rather than throw.
- For callouts via `BaseRestProxy`, the framework validates the
  Named Credential exists via SOQL on `NamedCredential` — again
  gated on `Queue__c.isAccessible()` (quirk — see
  [../improvements.md](../improvements.md)).

The safest posture is: **only the running integration user reads/writes
`Queue__c`**. Humans who need to inspect events should use the
`Event_Queue_Admin` permission set.

## Sharing model

`Queue__c.sharingModel = ReadWrite`, `externalSharingModel = Private`.
Internal users can see all events by default; external (partner/
community) users see none.

If you need tighter internal sharing — e.g. hide failed events from
most users — change the sharing model to `Private` and add a sharing
rule. The packaged code does not assume org-wide default values.

## Field-level security

All `Queue__c` custom fields are set to readable+editable by the
`Event_Queue_Admin` permission set. If a subscriber org restricts FLS
on any of:

- `Status__c`
- `StatusMessage__c`
- `RetryCount__c`
- `IsRetryDisabled__c`
- `Payload__c`

…the dispatcher will fail to update the record and the event will
stay in `QUEUED`. The fix is to grant FLS to the running user.

## Hardening recommendation

The packaged `Event_Queue_Admin` grants access to **all** test
classes (`*Test`, `HttpMock`, `MockThrowsExeceptionCommand`,
`EventUnitTestCommand`, `EventQueueFixtureFactory`). There is no
functional reason to do this in a subscriber org, and it creates
noise in the org-level Apex class list.

Consider creating a `Event_Queue_Admin_Clean` permission set in your
own repo with only production classes, and assigning that instead.
Tracked in [../improvements.md](../improvements.md).
