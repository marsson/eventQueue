/**
 * @description Dynamically instantiates an `ICommand` from its
 * fully qualified Apex class name. Resolution is driven by
 * `Event_Configuration__mdt.CommandClassName__c`.
 *
 * If the class does not exist (or is not accessible), the factory
 * throws `IntegrationBusinessException` with code
 * `COMMAND_NOT_FOUND` — which the dispatcher treats as a
 * non-retryable failure so misconfiguration surfaces immediately
 * instead of cycling through retries.
 *
 * @author Eduardo Ribeiro de Carvalho - @ercarval
 * @author Heitor Araujo
 * @author Marcelo Marsson
 */
public class CommandFactory {

	/**
	 * @description Resolve and instantiate the command class by
	 * name.
	 * @param commandClassName Fully qualified Apex class name
	 *        (must implement `ICommand`).
	 * @return A fresh `ICommand` instance.
	 * @throws IntegrationBusinessException when no class is
	 *         registered under that name in the org.
	 */
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
