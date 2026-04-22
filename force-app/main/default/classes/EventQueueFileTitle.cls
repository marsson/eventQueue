/**
 * @description Canonical prefixes used when naming attachments
 * stored against a `Queue__c` event:
 *  - `EXECUTION_TRACE` — the processing log appended via
 *    `event.appendLog(...)`.
 *  - `REQUEST_PAYLOAD` — outbound request body persisted by
 *    `AbstractOutboundCommand.execute()`.
 *  - `RESPONSE_PAYLOAD` — raw HTTP response body persisted by
 *    `RestProxy.postSend()`.
 *
 * Currently used as documentation only — the framework concatenates
 * the literal strings with a timestamp rather than calling
 * `name()` on the enum. Treat this enum as the contract for
 * attachment-title prefixes.
 *
 * @author Eduardo Ribeiro de Carvalho - @ercarval
 * @author Heitor Araujo
 * @author Marcelo Marsson
 */
public enum EventQueueFileTitle {

    EXECUTION_TRACE,
    REQUEST_PAYLOAD,
    RESPONSE_PAYLOAD
}
