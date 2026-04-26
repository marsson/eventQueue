# Event Queue Documentation

This folder is the entry point for all technical and functional documentation
for the Event Queue Salesforce package (`async_queue`).

The Event Queue is a Salesforce-native asynchronous execution framework built
on the Command design pattern. It turns any unit of business logic into a
persisted, retryable, traceable record so that integrations and critical
processes can fail safely and recover on their own.

## How the docs are organised

| Folder | What it covers | Who it's primarily for |
| --- | --- | --- |
| [architecture/](./architecture/) | High-level design, patterns, execution flows, data model. | Developers, maintainers, architects. |
| [reference/](./reference/) | Field-by-field / class-by-class reference for Apex, metadata, triggers, scheduled jobs and permission sets. | Maintainers, developers, admins. |
| [setup/](./setup/) | Install the package, configure metadata, schedule the retry jobs, assign permissions. | Admins, maintainers. |
| [usage/](./usage/) | How to enqueue events, implement a new command, use platform events. | Developers. |
| [personas/](./personas/) | Role-based "what do I need to know" manuals. | Everyone — jump here first. |
| [debugging.md](./debugging.md) | Where to look when things go wrong, how to replay events, how to read the processing log. | Support/Ops, developers, QA. |
| [improvements.md](./improvements.md) | Smells, dead code, typos, and revamp candidates. | Maintainers planning the revamp. |

## Where to start

- **New to the project?** Read [architecture/overview.md](./architecture/overview.md), then pick your persona in [personas/](./personas/).
- **Installing the package?** → [setup/installation.md](./setup/installation.md).
- **Writing a new command?** → [usage/implementing-a-command.md](./usage/implementing-a-command.md).
- **Triaging a failed event?** → [debugging.md](./debugging.md).
- **Configuring retention / the Admin Console?** → [setup/retention-configuration.md](./setup/retention-configuration.md), [reference/queue-admin-console.md](./reference/queue-admin-console.md).
- **Adding a notifier or logger implementation?** → [reference/notifier.md](./reference/notifier.md), [reference/logger.md](./reference/logger.md).
- **Planning the revamp?** → [improvements.md](./improvements.md).

## Glossary (quick reference)

| Term | Meaning |
| --- | --- |
| **Event** | A single `Queue__c` record representing one unit of asynchronous work. |
| **Event Type** | The logical name of the event (e.g. `BOOK_OUTBOUND_SERVICE`). Also stored as a value in `Queue__c.EventName__c`. |
| **Command** | An Apex class implementing `ICommand` that the framework invokes to process an event. |
| **Event Configuration** | A `Event_Configuration__mdt` custom metadata record mapping an Event Type to a Command class. |
| **Dispatcher** | The mechanism (trigger + queueable) that moves a `QUEUED` event to `DELIVERED` / `ERROR`. |
| **Retry loop** | The scheduled jobs that re-queue events stuck in `QUEUED`/`SCHEDULED`/`ERROR`. |
| **Platform event (`queueEvent__e`)** | High-volume fire-and-forget trigger channel used to enqueue events from external systems without committing DML first. |

---

**Package:** `async_queue` (namespace `async_queue`)
**Latest package version alias:** `async_queue@0.1.2-1` → `04t4x000000hwXZAAY`
**API version:** 63.0
