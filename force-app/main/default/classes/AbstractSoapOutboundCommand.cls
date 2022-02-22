/**
 * @author: Heitor Araujo
 */

public abstract with sharing class AbstractSoapOutboundCommand extends AbstractCommand{

    @TestVisible
    private Object responseObject;

    //public AbstractSoapOutboundCommand() {
    //}

    //Setup
    virtual
    override
    public void init (EventQueue event) {

        super.init(event);

        event.appendLog('event Initialized');

    }

    virtual
    override
    public void preExecute() {

        event.appendLog('Apply Event Transformation');

        initiateSoapObjectRequest();

    }

    virtual
    override
    public  void execute () {

        event.appendLog('Send SOAP Message to Target System');

        responseObject = send ();

        event.appendLog('Target System Response ' + JSON.serialize( responseObject ) );

    }


    //
    public abstract Object send 	();

    virtual
    override
    public void postExecute () {

        event.appendLog('Processing Response ');

        this.event.addPayload ( 'RESPONSE_PAYLOAD_' + System.now() ,  JSON.serialize( responseObject ) );

        processResult(responseObject);

        event.appendLog('Response Processed');

    }

    public abstract void initiateSoapObjectRequest ();

    public abstract void processResult (Object responseObject);
}