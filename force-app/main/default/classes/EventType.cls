/**
 * @description Registry of known event-type names. Each value
 * documents an event type for which a matching
 * `Event_Configuration__mdt` row should exist (with the same
 * developer name).
 *
 * Naming convention: `<DOMAIN>_<DIRECTION>_SERVICE` in upper snake
 * case. Treat values like constants — never repurpose an existing
 * value for a different business meaning.
 *
 * Add a new value here whenever you introduce a new business
 * process that should be dispatched through the Event Queue.
 *
 * @author Eduardo Ribeiro de Carvalho - @ercarval
 * @author Heitor Araujo
 * @author Marcelo Marsson
 */
public enum EventType {

    BOOK_INBOUND_SERVICE,
    BOOK_OUTBOUND_SERVICE

}
