/**
 * Decorete Response  with event.addPayload();
 * @author: Eduardo Ribeiro de Carvalho - @ercarval
 */
public virtual class RestProxy extends BaseRestProxy {

    protected EventQueue event;

    public RestProxy() {
        super(); 
    }

    public RestProxy(Event_Configuration__mdt config) {
        super(config);
    }

    public RestProxy(EventQueue event) {
        this(event.config);
        this.event = event;
    }


    override
    public void postSend() {

        super.postSend();

        this.event.addPayload ( 'RESPONSE_PAYLOAD_' + System.now() ,  httpResponse.getBody() );
    }
}