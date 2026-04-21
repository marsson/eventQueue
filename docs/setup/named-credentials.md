# Named Credentials

Outbound commands (`AbstractOutboundCommand` and anything that uses
`BaseRestProxy` / `RestProxy`) authenticate through Salesforce
**Named Credentials**. The framework **never** accepts raw URLs or
inline secrets.

## How the framework resolves a named credential

1. `Event_Configuration__mdt.NamedCredencial__c` holds the Named
   Credential's developer name (e.g. `BookOutboundHeroku`).
2. `BaseRestProxy(Event_Configuration__mdt config)` stores it.
3. `BaseRestProxy.setup()` validates it via
   `EventQueueHelper.isNamedCredencialValid(name)` (skipped when
   `Test.isRunningTest()`).
4. `this.httpRequest.setEndpoint('callout:<name>')`.

If the named credential doesn't exist, `setup()` throws
`IntegrationException('Invalid Named Credential <name>')`, which
propagates to `EventQueue.process()` as a technical failure
(retryable).

## Creating a named credential

Classic path: **Setup → Named Credentials → New Legacy Named
Credential**.

Modern path (API 49+): **Setup → Named Credentials → External
Credential + Named Credential** (two-object model).

Required pieces for an outbound command:

| Field | Example | Notes |
| --- | --- | --- |
| Label | `BookOutboundHeroku` | Human label. |
| Name (DeveloperName) | `BookOutboundHeroku` | **Must** match `Event_Configuration__mdt.NamedCredencial__c`. |
| URL | `https://api.partner.com/v1/bookings` | The full endpoint path is set here — the framework does **not** append a path. |
| Identity Type | Named Principal / Per User | Per-user for OAuth delegate scenarios. |
| Authentication Protocol | OAuth 2.0 / Password / Anonymous | The proxy is protocol-agnostic — whatever the Named Credential resolves to. |

> Because the framework sets `setEndpoint('callout:<name>')` with no
> path suffix, every different external path needs its own Named
> Credential, **or** you override `BaseRestProxy.setup()` to append
> a path (or override `send()` to compose a different endpoint).

## `Method__c` and HTTP method

`Event_Configuration__mdt.Method__c` is restricted to
`POST / GET / DELETE / SOAP`. `BaseRestProxy.setup()` uses it to
`setMethod(method)`. The `get(Map<String,String>)` convenience
overrides this to `GET`.

There is no `PUT` / `PATCH` in the picklist. If you need one, either:

- Add values to the picklist in a subscriber-org customisation, or
- Override `BaseRestProxy.setup()` in a subclass.

## Content-Type

Default: `application/json; charset=UTF-8`.

To switch to URL-encoded: `setContentType('url')` on the proxy.

> ⚠️ Bug: the `setContentType("json")` branch compares against
> `"son"` in the current code, so calling `setContentType('json')`
> throws `EventObjectException`. Workaround: don't call it for JSON
> (default is already JSON), or patch the source. Tracked in
> [../improvements.md](../improvements.md).

## Retries inside the proxy

`BaseRestProxy.tryToSend` retries the callout up to **3 times** on
`CalloutException` before rethrowing. This is separate from (and
composes with) the outer `RetryCount__c` loop driven by
`JobRetryEventProcessor`.

## Testing outbound flows

Use `HttpMock` (ships with the package):

```apex
Test.setMock(HttpCalloutMock.class, new HttpMock('{"ok":true}', true));
```

`HttpMock(String, Boolean)` — returns HTTP 200 (when true) or HTTP 400
(when false) with the given body.

In `BaseRestProxy.setup()`, Named-Credential validation is skipped
when `Test.isRunningTest()` is true, so tests don't need to create
`NamedCredential` rows.

## Checklist

- [ ] Named Credential created with the exact developer name used in
      `Event_Configuration__mdt.NamedCredencial__c`.
- [ ] Endpoint URL is the full path your command will hit.
- [ ] Authentication protocol configured (OAuth flow completed or
      password saved).
- [ ] `Event_Queue_Running_User` permission set assigned to the
      integration user.
- [ ] `Method__c` matches what the remote service expects.
