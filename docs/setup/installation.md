# Installation

The Event Queue is distributed as an unlocked SFDX package under the
namespace `async_queue`.

## Package versions

Declared in `sfdx-project.json`:

| Alias | Subscriber Package Version Id |
| --- | --- |
| `async_queue@0.1.0-1` | `04t4x000000hwXFAAY` |
| `async_queue@0.1.1-1` | `04t4x000000hwXUAAY` |
| `async_queue@0.1.2-1` | `04t4x000000hwXZAAY` (current) |

Package name: `async_queue` (id `0Ho4x000000blbuCAA`).

## Option 1 — install via URL

Open the package-install URL in the target org:

```
https://login.salesforce.com/packaging/installPackage.apexp?p0=04t4x000000hwXZAAY
# Sandbox:
https://test.salesforce.com/packaging/installPackage.apexp?p0=04t4x000000hwXZAAY
```

Enter the installation key when prompted (historical key: `VaiCurintia`
— coordinate with the package owner for current orgs).

## Option 2 — install via CLI

Using the modern `sf` CLI:

```bash
sf package install \
  --package 04t4x000000hwXZAAY \
  --installation-key VaiCurintia \
  --wait 30 \
  --target-org queuePOC
```

Or with the legacy `sfdx`:

```bash
sfdx force:package:install \
  -p 04t4x000000hwXZAAY \
  -w 30 \
  -u queuePOC \
  --installationkey VaiCurintia
```

## Option 3 — deploy the source directly

From a freshly cloned repo:

```bash
# authenticate
sf org login web --alias queuePOC

# deploy
sf project deploy start --source-dir force-app --target-org queuePOC

# run tests
sf apex run test --target-org queuePOC --code-coverage --result-format human
```

This is the path to use when iterating on the framework itself (no
package version bump needed), or when deploying to a scratch org.

## Post-install steps

After the metadata is in the org, **these are mandatory** before the
framework works:

1. **Assign permission sets** — see
   [permissions.md](./permissions.md).
2. **Schedule the retry jobs** — see
   [scheduling.md](./scheduling.md).
3. **Configure at least one `Event_Configuration__mdt` record** that
   points at a real Apex command class — see
   [configuration.md](./configuration.md).
4. **Create a Named Credential** if you plan to use
   `AbstractOutboundCommand` — see
   [named-credentials.md](./named-credentials.md).

You can validate the installation with a smoke test:

```apex
EventQueue evt = EventQueueFixtureFactory.createBaseEvent('EventUnitTest');
evt.process();
System.assertEquals('DELIVERED', evt.getStatus());
```

If this returns `DELIVERED`, the dispatcher, `CommandFactory`,
`Event_Configuration__mdt`, and permission sets are all wired up.

## Uninstalling

Uninstalling the package removes the Apex classes, triggers, objects,
and metadata — **but the `Queue__c` records stay** until the package
uninstall chooses to delete them (Salesforce prompts). If you have
valuable audit trail on `Queue__c`, export before uninstalling.

The scheduled jobs must be aborted **before** uninstall:

```apex
JobPendingEvents.abort();
JobOldQueuedEvents.abort();
JobRetryEventProcessor.abort();
```

Otherwise the uninstall will fail with "scheduled Apex exists".

## Version compatibility

- Source API version: **53.0** (`sfdx-project.json`).
- The package uses `with sharing`, `@future(callout=true)`,
  `Schedulable`, `Queueable`, `Database.AllowsCallouts`,
  `HttpCalloutMock`. No dependencies beyond standard Apex.
- No managed-package dependencies. Requires Lightning Experience.
