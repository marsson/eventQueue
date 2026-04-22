/**
 * @description Test command that always throws `CalloutException`.
 * Used to exercise the dispatcher's technical-failure path
 * (status → ERROR, retry counter decremented). Mapped via the
 * `EventUnitTestThrowsException` `Event_Configuration__mdt` record.
 *
 * @author Eduardo Ribeiro de Carvalho - @ercarval
 * @author Heitor Araujo
 * @author Marcelo Marsson
 */
@isTest
public class MockThrowsExeceptionCommand implements ICommand, IUpdatableCommmad {

    /**
     * @description Logs an entry and immediately throws.
     * @param event The event being processed.
     */
    public void execute(EventQueue event) {

        event.appendLog ('executed');

        throw new CalloutException ('Unable to process Request');

    }

    /**
     * @description Required by `IUpdatableCommmad`. No-op.
     * @param event The event being processed.
     */
    public void postUpdateExecute(EventQueue event) {
        System.debug('post Execute');
    }



}
