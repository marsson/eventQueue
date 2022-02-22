/**
 * Provide template method for ICommand executions
 *
 *
 * @author: Eduardo Ribeiro de Carvalho - @ercarval
 */
public abstract with sharing class AbstractOutboundCommand extends AbstractCommand  {

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
	public void init (EventQueue event) {

		super.init(event);

		proxy = getHttpRequestProxy( event );

		event.appendLog('event Initialized');

	}

	virtual
	override
	public void preExecute() {

		event.appendLog('Apply Event Transformation');

		targetObject = tranformToSend();

		event.appendLog('Transformation Applied ' + JSON.serialize(targetObject));

	}

	virtual
	override
	public  void execute () {

		event.appendLog('Send Message to Target System from named credentials:'+event.config.NamedCredencial__c );

		event.addPayload ( 'REQUEST_PAYLOAD_' + System.now() , JSON.serialize(targetObject) );

		responseObject = send ();

		event.appendLog('Target System Response ' + JSON.serialize( responseObject ) );

	}


	//
	virtual
	public Object send 	() {
		return proxy.send(  targetObject );
	}

	virtual
	override
	public void postExecute () {

		event.appendLog('Processing Response ');

		processResult(responseObject);

		event.appendLog('Response Processed');

	}

	virtual
	public BaseRestProxy getHttpRequestProxy (EventQueue event) {
		return new RestProxy( event );
	}

	public abstract Object tranformToSend ();

	public abstract void processResult (Object responseObject);

}