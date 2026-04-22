/**
 * @description Lifecycle states for a `Queue__c` event. The set
 * here is broader than the picklist on `Queue__c.Status__c`; values
 * not present on the picklist are reserved for use by custom
 * commands that need to park events in intermediate states.
 *
 * Used by the dispatcher: `QUEUED`, `DELIVERED`, `ERROR`,
 * `UNHANDLED`, `SCHEDULED`, `WORKFLOW`, `IGNORED`. The remaining
 * values are documented as extension points.
 *
 * See `docs/reference/status-lifecycle.md` for the complete
 * picklist-vs-enum mapping.
 *
 * @author Eduardo Ribeiro de Carvalho - @ercarval
 * @author Heitor Araujo
 * @author Marcelo Marsson
 */
public enum EventQueueStatusType {
    SUCCESS
    , ERROR
    , QUEUED
    , DEQUEUED
    , DELIVERED
    , INVALID
    , DONE
    , WAITING_EXTERNAL_SYSTEM
    , QUEUED_ON_EXTERNAL_SYSTEM
    , EMPTY
    , OVERRIDDEN
    , UNHANDLED
    , WORKFLOW
    , PROCESSING
    , SCHEDULED
    , BATCH
    , WAITING
    , IGNORED
}
