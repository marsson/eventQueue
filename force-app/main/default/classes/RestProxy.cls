/**
 * @description `BaseRestProxy` subclass that decorates the
 * response-handling step: after every successful call, persists the
 * response body as a `RESPONSE_PAYLOAD_<now>` attachment on the
 * parent `EventQueue`. This makes outbound flows auditable without
 * any extra bookkeeping from the command.
 *
 * @author Eduardo Ribeiro de Carvalho - @ercarval
 * @author Heitor Araujo
 * @author Marcelo Marsson
 */
public virtual class RestProxy extends BaseRestProxy {

    protected EventQueue event;

    /**
     * @description Default constructor. No named credential; the
     * proxy cannot make callouts until further configuration.
     */
    public RestProxy() {
        super();
    }

    /**
     * @description Build a proxy from a configuration row.
     * @param config The `Event_Configuration__mdt` whose
     *               `NamedCredencial__c` and `Method__c` drive the
     *               outbound call.
     */
    public RestProxy(Event_Configuration__mdt config) {
        super(config);
    }

    /**
     * @description Build a proxy bound to an `EventQueue`. Uses
     * the event's config to drive the outbound call and stores a
     * back-reference so `postSend()` can attach the response.
     * @param event The event being processed.
     */
    public RestProxy(EventQueue event) {
        this(event.config);
        this.event = event;
    }


    /**
     * @description Override of `BaseRestProxy.postSend()` that
     * appends a `RESPONSE_PAYLOAD_<now>` attachment with the raw
     * response body.
     */
    override
    public void postSend() {

        super.postSend();

        this.event.addPayload ( 'RESPONSE_PAYLOAD_' + System.now() ,  httpResponse.getBody() );
    }
}
