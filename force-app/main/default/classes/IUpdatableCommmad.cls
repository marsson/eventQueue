/**
 * @author: Eduardo Ribeiro de Carvalho - @ercarval
 */
public interface IUpdatableCommmad extends ICommand {

    void postUpdateExecute (EventQueue event) ;

}