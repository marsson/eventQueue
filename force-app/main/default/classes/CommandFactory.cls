/**
 * @author: Eduardo Ribeiro de Carvalho - @ercarval
 */
public class CommandFactory {

	public static ICommand createInstanceFor (String commandClassName) {
		Type commandType = Type.forName (commandClassName);
		return  (ICommand) commandType.newInstance();
	}

}
