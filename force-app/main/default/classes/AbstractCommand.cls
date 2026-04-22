/**
 * @description Template-method base class for commands. Implements
 * the standard lifecycle invoked by the dispatcher:
 *
 * <pre>
 * execute(event)
 *    -> init(event)
 *    -> preExecute()
 *    -> execute()       // abstract - implemented by subclass
 *    -> postExecute()
 * </pre>
 *
 * Subclasses override the hooks they care about. The only method
 * that MUST be implemented is the no-arg `execute()`.
 *
 * Usage example:
 *
 * <pre>
 * class PurchaseApprovedCommand extends AbstractCommand {
 *     private Order salesOrder;
 *
 *     override
 *     public void init(EventQueue event) {
 *         super.init(event);
 *         salesOrder = (Order) event.getPayloadFromJson(Order.class);
 *     }
 *
 *     public void execute() {
 *         // business logic here
 *     }
 * }
 * </pre>
 *
 * PMD suppression for global: the class must be extendable from
 * outside the package namespace.
 *
 * @author Eduardo Ribeiro de Carvalho - @ercarval
 * @author Marcelo Costa
 * @author Heitor Araujo
 * @author Marcelo Marsson
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
global abstract with sharing class AbstractCommand implements ICommand {

	protected EventQueue event;

	/**
	 * @description Template entry point invoked by the dispatcher.
	 * Runs `init → preExecute → execute → postExecute` in order.
	 * @param event The event being processed.
	 */
	public void execute(EventQueue event) {

		init(event);

		preExecute();

		execute();

		postExecute();

	}

	/**
	 * @description Set up command state. Default implementation
	 * stores the event reference; override to deserialise the
	 * payload into a domain object.
	 * @param event The event being processed.
	 */
	virtual
	global void init (EventQueue event) {
		this.event = event;
	}

	/**
	 * @description Hook invoked before `execute()`. Override to
	 * perform pre-processing (e.g. transform the payload).
	 */
	virtual
	global void preExecute(){
		//Should be solved in implementation
		System.debug('pre Execute');
	}

	/**
	 * @description Hook invoked after `execute()`. Override to
	 * perform post-processing.
	 */
	virtual
	global void postExecute(){
		System.debug('post Execute');
	}


	/**
	 * @description The core business logic for this command.
	 * Subclasses must implement.
	 */
	global abstract void execute();

}
