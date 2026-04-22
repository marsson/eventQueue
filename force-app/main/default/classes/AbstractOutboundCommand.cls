/**
 * @description Template-method base class for commands that make
 * an outbound HTTP callout via a Named Credential.
 *
 * Overrides each lifecycle hook in `AbstractCommand` to
 * orchestrate: build proxy → transform payload → send → log
 * request/response → process the result.
 *
 * Subclasses must implement:
 *  - `tranformToSend()` — produces the outbound DTO.
 *  - `processResult(Object)` — handles the decoded response.
 *
 * If the command also needs to apply DML using the response, the
 * subclass should declare `implements IUpdatableCommmad` and move
 * the DML into `postUpdateExecute`.
 *
 * PMD suppression for global: the class must be extendable from
 * outside the package namespace.
 *
 * @author Eduardo Ribeiro de Carvalho - @ercarval
 * @author Heitor Araujo
 * @author Marcelo Marsson
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
global abstract with sharing class AbstractOutboundCommand extends AbstractCommand  {

	@TestVisible
	protected Object targetObject;

	@TestVisible
	private Object responseObject;

	protected BaseRestProxy proxy;

	/**
	 * @description Initialise the command and its REST proxy.
	 * @param event The event being processed.
	 */
	virtual
	override
	global void init (EventQueue event) {

		super.init(event);

		proxy = getHttpRequestProxy( event );

		event.appendLog('event Initialized');

	}

	/**
	 * @description Transform the event payload into the outbound
	 * DTO. Stores the result in `targetObject`.
	 */
	virtual
	override
	global void preExecute() {

		event.appendLog('Apply Event Transformation');

		targetObject = tranformToSend();

		event.appendLog('Transformation Applied ' + JSON.serialize(targetObject));

	}

	/**
	 * @description Send the outbound request via the proxy and
	 * persist `REQUEST_PAYLOAD_<now>` as an attachment. The
	 * response is stored in `responseObject`.
	 */
	virtual
	override
	global void execute () {

		event.appendLog('Send Message to Target System from named credentials:'+event.config.NamedCredencial__c );

		event.addPayload ( 'REQUEST_PAYLOAD_' + System.now() , JSON.serialize(targetObject) );

		responseObject = send ();

		event.appendLog('Target System Response ' + JSON.serialize( responseObject ) );

	}


	/**
	 * @description Perform the actual HTTP call. Defaults to
	 * `proxy.send(targetObject)`; override for bespoke
	 * serialisation or auth flows.
	 * @return The response body (or deserialised DTO) from the
	 *         proxy.
	 */
	virtual
	global Object send 	() {
		return proxy.send(  targetObject );
	}

	/**
	 * @description Handoff the response DTO to
	 * `processResult(...)`.
	 */
	virtual
	override
	global void postExecute () {

		event.appendLog('Processing Response ');

		processResult(responseObject);

		event.appendLog('Response Processed');

	}

	/**
	 * @description Factory hook for the REST proxy. Default
	 * returns `new RestProxy(event)`. Override to inject a custom
	 * `BaseRestProxy` subclass (e.g. OAuth token injection).
	 * @param event The event being processed.
	 * @return The proxy instance to use for this request.
	 */
	virtual
	global BaseRestProxy getHttpRequestProxy (EventQueue event) {
		return new RestProxy( event );
	}

	/**
	 * @description Build the outbound DTO from the event payload.
	 * Subclasses must implement.
	 * @return The object to serialise into the request body.
	 */
	global abstract Object tranformToSend ();

	/**
	 * @description Handle the response produced by `send()`.
	 * Subclasses must implement.
	 * @param responseObject Response DTO or body returned by the
	 *                       proxy.
	 */
	global abstract void processResult (Object responseObject);

}
