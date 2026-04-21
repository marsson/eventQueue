# Personas

Role-based "what do I need to know" manuals. Each persona page is
self-contained but cross-links to the reference docs.

| Persona | Start here | Main concerns |
| --- | --- | --- |
| [Salesforce Administrator](./admin.md) | Install, permission sets, scheduling, triage. | Keep the framework healthy in the org. |
| [Apex Developer](./developer.md) | `ICommand` / `AbstractCommand` / `AbstractOutboundCommand`, `EventBuilder`, testing. | Extend the framework with new commands. |
| [QA / Tester](./qa.md) | Test classes, fixtures, `HttpMock`, smoke recipes. | Verify behaviour under happy-path, retry, and failure conditions. |
| [Support / Ops](./support-ops.md) | Reading `Queue__c`, attachments, manual retry. | Triage failing transactions reported by business users. |
| [Git Maintainer](./maintainer.md) | Repo layout, release process, patterns to preserve. | Own the codebase; review PRs; cut releases. |

If you're not sure which persona you fit, start with
[../README.md](../README.md) for the project overview, then pick the
role that most matches your day-to-day work.
