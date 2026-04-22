/**
 * @description No-op `ICommand` used by the test suite to exercise
 * the dispatcher's happy path without invoking real business logic.
 * Mapped via the `EventUnitTest` `Event_Configuration__mdt` record.
 *
 * @author Heitor Araujo
 * @author Marcelo Marsson
 */
@IsTest
public with sharing class EventUnitTestCommand implements ICommand{

    /**
     * @description No-op execution.
     * @param event The event being processed (ignored).
     */
    public void execute(EventQueue event){
        return;
    }

}
