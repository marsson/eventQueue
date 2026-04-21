# Persona: Git Maintainer (project owner / committer)

You own this repository. You decide what goes into the next version,
you review PRs, you cut releases. You need the full technical picture,
including the skeletons in the closet.

## The 10-minute project tour

- **One custom object.** `Queue__c` is the event. Every other moving
  part exists to get a row to `DELIVERED` or tell you why it didn't.
- **One mapping table.** `Event_Configuration__mdt` maps an event
  name to an Apex class. That's the extension point.
- **One strategy interface.** `ICommand.execute(EventQueue)`.
  Everything runs through it. Sibling interface `IUpdatableCommmad`
  adds a second pass for post-callout DML.
- **Two execution paths into the dispatcher.** A trigger on
  `Queue__c` (synchronous dispatch via `@future`) and three scheduled
  jobs (retry loop / stuck-event safety net).
- **One platform event for high-volume ingress.** `queueEvent__e`
  with an empty subscriber trigger; the translation to `Queue__c` is
  left to the subscriber org (deliberate extension point).

Full architecture: [../architecture/overview.md](../architecture/overview.md).
Every flow drawn as a sequence diagram:
[../architecture/execution-flows.md](../architecture/execution-flows.md).

## Repo layout

```
force-app/main/default/
  applications/     Event_Queue app
  aura/             empty (lint config only)
  classes/          all Apex
  customMetadata/   shipped Event_Configuration__mdt rows
  flexipages/       Lightning record pages
  layouts/          page layouts
  lwc/              empty (lint config only)
  objects/
    Queue__c/
    Event_Configuration__mdt/
    queueEvent__e/
  permissionsets/   Event_Queue_Admin, Event_Queue_Running_User
  tabs/
  triggers/         EventConsumer, queueProcessor
  ...
config/             scratch-org def
manifest/           legacy package.xml
sfdx-project.json   namespace + package aliases
```

## Package identity

```json
"namespace": "async_queue",
"packageAliases": {
    "async_queue":         "0Ho4x000000blbuCAA",
    "async_queue@0.1.0-1": "04t4x000000hwXFAAY",
    "async_queue@0.1.1-1": "04t4x000000hwXUAAY",
    "async_queue@0.1.2-1": "04t4x000000hwXZAAY"
}
```

Two package directory entries exist: `Asyncronous Queue` (typo, kept
for compatibility) and `async_queue`. Both point at `force-app/`;
`async_queue` is the active one.

## Hot paths — where to look first when something changes

| Change area | Primary files | Things to re-test |
| --- | --- | --- |
| Dispatch behaviour | `EventExecutor.cls`, `EventQueueTriggerHandler.cls`, `EventConsumer.trigger`, `EventQueue.process()` | `EventExecutorTest`, `EventConsumerTest`, `EventQueueTest`. |
| Retry loop | `Job*.cls`, `ScheduleHelper.cls` | `Job*Test`, and a manual `start()/abort()` in a scratch org. |
| Callout behaviour | `BaseRestProxy.cls`, `RestProxy.cls` | `BaseRestProxyTest`, `AbstractOutboundCommandTest`. |
| Data model | `Queue__c/` object + fields, `Event_Configuration__mdt/` | All Apex tests (they rely on field APIs). Permission sets (new fields need to be added). |
| Permissions | `permissionsets/*.permissionset-meta.xml` | Manual `runAs` test for low-privilege users. |

## The skeletons (read before you merge)

The full list is in [../improvements.md](../improvements.md). The
load-bearing ones:

- **`IUpdatableCommmad`** — three M's. A rename is a breaking change:
  `Event_Configuration__mdt` strings and permission sets reference
  it by name. Deferred until a 1.0 release.
- **`EventQueueActiveRecord` keys by `Label`, not `DeveloperName`.**
  The two must match for the lookup to work. Drift silently fails as
  `UNHANDLED`.
- **`setToUnhadledEvent`** — typo (`Unhadled`). Status constant still
  spelled `UNHANDLED` correctly — the typo is in the method name only.
- **`tranformToSend`** — typo (`tranform`). Abstract method;
  subclasses everywhere in partner orgs have this spelling baked in.
- **`DateTimeHelper.removeSencondsIntoCurrentDate`** — typo
  (`Sencond`). Referenced from `EventExecutor`.
- **`BaseRestProxy.setContentType("json")` is broken** (compares
  against the string literal `"son"`). Calling it with `"json"`
  throws `EventObjectException`. Default is JSON so it's rarely hit.
- **`CommandFactory` has no defensive null check.** Unknown class
  name → `NullPointerException` → caught as a technical failure →
  swallowed as a retry. Errors look flaky instead of being
  diagnostic.
- **`EventQueueHelper.isNamedCredencialValid`** checks `Queue__c`
  accessibility but queries `NamedCredential` — a confused CRUD gate.
- **`EventBuilder.buildAndSave()`** shadows the field `event` with a
  local named `event`. Works by accident.
- **`queueProcessor.trigger` is empty.** This is documented as an
  extension point in this docs set, but if you ship another version
  of the package you may want to inline a minimal translator trigger
  behind a custom-metadata flag.
- **`EventType` enum and custom metadata labels must stay in sync.**
  There's no enforcement. If someone renames an enum value but
  forgets the metadata (or vice versa), runtime lookups return
  `UNHANDLED` with no compile-time warning.
- **Permission sets grant access to every test class.** Noise, not
  a bug — but signals intent is unclear.

## Release checklist (when cutting a new package version)

- [ ] All tests pass (`sf apex run test --code-coverage`).
- [ ] Coverage ≥75% overall, 100% on production classes you changed.
- [ ] New `EventType` enum values match any new
      `Event_Configuration__mdt` labels.
- [ ] New Apex classes added to **both** permission sets.
- [ ] New `Queue__c` fields (if any) added to `Event_Queue_Admin`'s
      field permissions.
- [ ] `sfdx-project.json` version number bumped.
- [ ] `sf package version create` run, alias added to
      `packageAliases`.
- [ ] README install URL updated.
- [ ] Changelog / release notes written (you decide where — this
      repo doesn't have a CHANGELOG file today).

## Patterns to preserve when refactoring

- The two-pass dispatcher (callout then DML).
- The active-record pattern (`EventQueue` extends
  `EventQueueActiveRecord`).
- `with sharing` on every class.
- CRUD gates on SOQL.
- `global` on classes meant for extension.
- `Job*.start() / .abort()` pairing for scheduled jobs.
- Persistent execution trace as an Attachment on `Queue__c`.

If your refactor breaks any of those without a considered reason, an
integrator in a subscriber org is going to have a bad Monday.

## Where to think about the revamp

Start with [../improvements.md](../improvements.md) — it lists every
smell I found while writing these docs, grouped by risk and revamp
priority. Read those before planning a new major version.
