/**
 * @description Root contract for every unit of work the Event Queue
 * can dispatch. A class mapped via `Event_Configuration__mdt.CommandClassName__c`
 * must implement this interface (directly or transitively).
 *
 * Implementations should:
 *  - Throw `IntegrationBusinessException` for permanent (non-retryable)
 *    failures.
 *  - Throw any other `Exception` for transient (retryable) failures.
 *  - Return normally to mark the event as `DELIVERED`.
 *
 * Prefer extending `AbstractCommand` or `AbstractOutboundCommand`
 * over implementing this interface directly.
 *
 * @author Eduardo Ribeiro de Carvalho - @ercarval
 * @author Heitor Araujo
 * @author Marcelo Marsson
 */
public interface ICommand {

    /**
     * @description Execute the business logic for this event.
     * @param event The event being processed. Never null; the
     *              underlying `Queue__c` always has an Id.
     */
    void execute (EventQueue event);
}
