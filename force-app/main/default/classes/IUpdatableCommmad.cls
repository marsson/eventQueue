/**
 * @description Marker contract for commands that need a second pass
 * after the callout phase, typically to apply DML using the callout
 * response.
 *
 * Apex forbids DML before a callout in the same transaction, so
 * `EventExecutor.processEvents` runs every command's `execute(...)`
 * first and then walks the list a second time to call
 * `postUpdateExecute(...)` on every command that implements this
 * interface. Bulk DML on the queue records is then performed in a
 * single shot at the end of the batch.
 *
 * Note: the spelling `Commmad` (three M's) is preserved for
 * backward compatibility with subscriber-org references.
 *
 * @author Eduardo Ribeiro de Carvalho - @ercarval
 * @author Heitor Araujo
 * @author Marcelo Marsson
 */
public interface IUpdatableCommmad extends ICommand {

    /**
     * @description Apply DML based on the result of the prior
     * callout phase. Invoked after every event in the batch has
     * finished its `execute(...)` call.
     * @param event The event whose callout response should drive
     *              follow-up updates.
     */
    void postUpdateExecute (EventQueue event) ;

}
