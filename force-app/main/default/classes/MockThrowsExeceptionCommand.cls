/**
 * Provide Mock Command for handle exception execution
 * @author: Eduardo Ribeiro de Carvalho - @ercarval
 */
@isTest
public class MockThrowsExeceptionCommand implements ICommand, IUpdatableCommmad {

    public void execute(EventQueue event) {

        event.appendLog ('executed');

        throw new CalloutException ('Unable to process Request');

    }

    public void postUpdateExecute(EventQueue event) {
        System.debug('post Execute');
    }



}