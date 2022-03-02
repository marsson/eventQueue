/**
 * Provide template method for ICommand executions
 *
 *
 * @author: Eduardo Ribeiro de Carvalho - @ercarval
 */

@SuppressWarnings('PMD.AvoidGlobalModifier')
global abstract with sharing class AbstractOutboundCommand extends AbstractCommand  {

	@TestVisible
	protected Object targetObject;

	@TestVisible
	private Object responseObject;

	protected BaseRestProxy proxy;

	//public AbstractOutboundCommand() {
	//}

	//Setup
	virtual
	override
	global void init (EventQueue event) {

		super.init(event);

		proxy = getHttpRequestProxy( event );

		event.appendLog('event Initialized');

	}

	virtual
	override
	global void preExecute() {

		event.appendLog('Apply Event Transformation');

		targetObject = tranformToSend();

		event.appendLog('Transformation Applied ' + JSON.serialize(targetObject));

	}

	virtual
	override
	global void execute () {

		event.appendLog('Send Message to Target System from named credentials:'+event.config.NamedCredencial__c );

		event.addPayload ( 'REQUEST_PAYLOAD_' + System.now() , JSON.serialize(targetObject) );

		responseObject = send ();

		event.appendLog('Target System Response ' + JSON.serialize( responseObject ) );

	}


	//
	virtual
	global Object send 	() {
		return proxy.send(  targetObject );
	}

	virtual
	override
	global void postExecute () {

		event.appendLog('Processing Response ');

		processResult(responseObject);

		event.appendLog('Response Processed');

	}

	virtual
	global BaseRestProxy getHttpRequestProxy (EventQueue event) {
		return new RestProxy( event );
	}

	global abstract Object tranformToSend ();

	global abstract void processResult (Object responseObject);

}
