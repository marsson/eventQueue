/**
 * @author: Eduardo Ribeiro de Carvalho - @ercarval
 */
public class CommandFactory {

	public static ICommand createInstanceFor (String commandClassName) {
		Type commandType = Type.forName (commandClassName);
		if (commandType == null) {
			throw new IntegrationBusinessException(
				new IntegrationBusError(
					'COMMAND_NOT_FOUND',
					'No Apex class named "' + commandClassName + '" exists or is not accessible in this org'
				)
			);
		}
		return  (ICommand) commandType.newInstance();
	}

}
