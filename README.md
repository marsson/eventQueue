# Event Queue

> **The async execution backbone Salesforce shipped without.**
> Persisted, retryable, traceable business logic — no middleware required.

<!-- Hero banner. Replace with a real screenshot/diagram when assets land. -->
<p align="center">
  <img src="docs/assets/hero.png" alt="Event Queue — Admin Console hero" width="820" />
</p>

---

## Why Event Queue

If you've ever owned a Salesforce integration in production, you've owned this exact pager rotation:

- A nightly batch dies on row 47,312 — and you have nothing to retry.
- A REST callout times out — and the originating record has no breadcrumb of what was tried.
- A platform event handler quietly fails a subscriber — and your only signal is a customer phone call.
- You need an audit trail of *which business action ran, against which payload, and what the system replied* — and your debug logs were rotated out an hour ago.

**Event Queue solves this.** It turns every unit of critical business logic into a first-class, persisted record (`Queue__c`) with status, retry budget, payload, response, processing log, and an attachable execution trace. Failures are routable, retries are configurable, and every step is observable from a Lightning admin console.

It's the framework you reach for when you need **business-process reliability on a platform that doesn't ship one** — and it shines especially bright in orgs **without middleware** (no MuleSoft, no Boomi, no Workato), where the integration layer *is* Salesforce.

<!-- Feature collage. Drop screenshots of: admin console, retention tab, event timeline. -->
<p align="center">
  <img src="docs/assets/console-overview.png" alt="Admin Console — overview tab" width="820" />
</p>

---

## Problems it solves

| Problem | What Event Queue gives you |
| --- | --- |
| **Critical business logic runs once and disappears.** | A persisted `Queue__c` row per execution, with status, retry counter, payload, and response. |
| **Failures are silent until a user complains.** | First-class `ERROR` status with stack trace, status message, and a pluggable `AbstractNotifier` (Slack, email, PagerDuty, custom). |
| **Retries are bespoke per integration.** | Built-in retry loop with configurable budget per event type and a scheduled re-driver — no per-integration rewrites. |
| **Debug logs rot in 24 hours.** | Per-event processing log persisted as an `ExecutionTrace_*` attachment, plus a pluggable `AbstractLogger` (Nebula, Splunk, custom). |
| **No middleware, but you still need orchestration.** | A trigger + queueable dispatcher + platform-event firehose, all in-platform. |
| **Volume spikes blow callout limits.** | `queueEvent__e` fan-in turns sync DML producers into async fire-and-forget. |
| **Storage bloat from old queue rows.** | Configurable retention policies (`Queue_Retention_Policy__mdt`) with dry-run, per-status caps, and an Admin-Console UI. |

---

## When to reach for it

Event Queue is the right tool when you have **systems with critical business logic that must execute reliably, with logging, retries, and observability** — particularly when:

- You operate **without a middleware layer** and Salesforce is the system of record.
- You're integrating Salesforce with one or more external systems via callouts (REST/SOAP) and need durable retries.
- You have inbound webhooks / Apex REST endpoints that must idempotently land work.
- You have asynchronous business processes (approvals, state transitions, fan-out notifications) that must survive partial failures.
- You need a **paper trail** for compliance/audit — what ran, when, against what, with what result.

Skip it when: your problem is a single sync DML in a UI flow, or when you already own a robust middleware (MuleSoft / Boomi / Kafka) that does the same job.

---

## Architecture at a glance

<p align="center">
  <img src="docs/assets/architecture.png" alt="Event Queue — high-level architecture" width="820" />
</p>

Event Queue is a small, opinionated set of components that compose into a full async execution layer:

- **`Queue__c`** — the durable record of one unit of work (status, payload, retry budget, response, processing log).
- **`Event_Configuration__mdt`** — maps an event type (e.g. `BOOK_OUTBOUND_SERVICE`) to an Apex command class. Configurable from the Admin Console.
- **Dispatcher** — the trigger + `EventExecutor` queueable that moves a `QUEUED` event through `init → preExecute → execute → postExecute`, separating callouts from DML to respect Apex's mixed-DML rules.
- **`ICommand` / `AbstractCommand`** — the Command-pattern surface where your business logic lives. Subclass it, override `execute()`, and let the framework do everything else.
- **Retry loop** — three scheduled jobs (`JobPendingEvents`, `JobOldQueuedEvents`, `JobRetryEventProcessor`) re-queue stuck or errored events on a configurable cadence.
- **Platform-event firehose (`queueEvent__e`)** — a bulk producer surface for high-volume callers that don't want to commit DML first.
- **Pluggable framework facades**:
  - **`AbstractLogger`** + `LoggerFactory` — register one or more `Logger_Registration__c` rows to fan logs out to your sink of choice (defaults to `System.debug` via `DebugLogger`).
  - **`AbstractNotifier`** + `NotifierFactory` — register one or more `Notifier_Registration__c` rows to route severity-tagged events (purge errors, dispatch failures) to Slack/email/PagerDuty.
- **Retention** — `Queue_Retention_Policy__mdt`-driven `QueueRetentionBatch` keeps storage in check, with global-cap, dry-run, and per-policy-status semantics.
- **Admin Console (LWC)** — a Lightning app for configuring event mappings, scheduling jobs, registering loggers/notifiers, defining retention policies, and inspecting purge history — all without redeploying.

<p align="center">
  <img src="docs/assets/event-lifecycle.png" alt="Event lifecycle — QUEUED → DELIVERED / ERROR" width="820" />
</p>

---

## Quick start

```bash
# 1. Install the package into your org
sfdx force:package:install \
    --package 04t4x000000hwXZAAY \
    --wait 30 \
    --target-org <your-org-alias>

# 2. Assign the running-user permission set
sfdx force:user:permset:assign \
    --perm-set-name Event_Queue_Running_User \
    --target-org <your-org-alias>

# 3. Open the Event Queue admin console app
sfdx force:org:open --path lightning/app/Event_Queue --target-org <your-org-alias>
```

Or via the Setup UI:
**Subscriber Package Version Id:** `04t4x000000hwXZAAY`
**Install URL:** https://test.salesforce.com/packaging/installPackage.apexp?p0=04t4x000000hwXZAAY

For full setup including retention scheduling and permission-set assignment, see [`docs/setup/installation.md`](docs/setup/installation.md).

---

## Documentation

The full documentation lives in [`docs/`](docs/README.md). Highlights:

- **Architecture** — [`docs/architecture/overview.md`](docs/architecture/overview.md) (design principles, execution flow, data model)
- **Implementing a command** — [`docs/usage/implementing-a-command.md`](docs/usage/implementing-a-command.md)
- **Admin Console** — [`docs/reference/queue-admin-console.md`](docs/reference/queue-admin-console.md)
- **Retention** — [`docs/setup/retention-configuration.md`](docs/setup/retention-configuration.md), [`docs/architecture/retention.md`](docs/architecture/retention.md)
- **Loggers / Notifiers** — [`docs/reference/logger.md`](docs/reference/logger.md), [`docs/reference/notifier.md`](docs/reference/notifier.md)
- **Debugging a failed event** — [`docs/debugging.md`](docs/debugging.md)
- **By role** — [`docs/personas/`](docs/personas/) (admin, developer, support-ops)

---

## Package metadata

| | |
| --- | --- |
| Package name | `async_queue` |
| Latest version alias | `async_queue@0.1.2-1` → `04t4x000000hwXZAAY` |
| API version | 63.0 |
| License | See [LICENSE](LICENSE) if present in the repo, otherwise contact the maintainers. |

---

<p align="center">
  <em>Built for Salesforce orgs that need a real async execution layer — without leaving the platform.</em>
</p>
