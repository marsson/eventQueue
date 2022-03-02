/**
 * Provide template method for ICommand executions
 *
 * How to Use 
 *   	
 *  class PurchaseApprovedCommand extends AbstractCommand {
 *		private Order salesOrder;
 *		
 *      // rewrite init method to initialize attributes	
 *      override
 *		public void init (EventQueue event) {
 *			super.init(event);
 *			salesOrder = (Order) event.getPayloadFromJson( Order.class ); 
 *		}
 *		
 *      // principal execution method
 *		public void execute () {
 *			// implement you logic here
 *		}
 *
 *  } 
 * 
 * @author: Eduardo Ribeiro de Carvalho - @ercarval
 * @author: Marcelo Costa
 *
 * PMD Supression for global as class must be extended outside of the namespace of the unlocked package
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
global abstract with sharing class AbstractCommand implements ICommand {

	protected EventQueue event;
	/**
	 * Template execution for default actions 
	 */
	public void execute(EventQueue event) {
	
		init(event);

		preExecute();

		execute();

		postExecute();

	}	

	virtual
	global void init (EventQueue event) {
		this.event = event;
	}

	/**
	 * Decorate execution process
	 */ 
	virtual
	global void preExecute(){
		//Shoukd be dolved in implementation
		System.debug('pre Execute');
	}

	/**
	 * Decorate execution process
	 */
	virtual
	global void postExecute(){
		System.debug('post Execute');
	}


	global abstract void execute();

}
