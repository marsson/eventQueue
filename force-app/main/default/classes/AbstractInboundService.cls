/**
 * How to Use
 *
 * Create Concrete Class extending AbstractInboundService and overriging eventHandler, setPayload methods by default.
 *
 * global CreateSalesOrderInboundService extends AbsractInboundService {
 *     //
 *     public CreateSalesOrderInboundService (Event event, Order order) {
 *         super (event);
 *         this.order = order;
 *     }
 *
 *     overriding
 *     public void handleEvent() {
 *          //implement your logic here.
 *     }
 *
 *     webservice
 *     public static void create (Event event, Order order) {
 *         CreateSalesOrderInboundService service = new CreateSalesOrderInboundService(event,contract);
 *         service.execute();
 *     }
 * }
 *
 * @author: Eduardo Ribeiro de Carvalho - @ercarval
 *
 */
public with sharing abstract class AbstractInboundService
    implements InboundService {

    protected EventQueue event;

    //public AbstractInboundService () {
    //}

    public AbstractInboundService (EventQueue event) {
        this.event = event;
    }

    private void initEvent () {

        event.init (
            new EventBuilder().createEventFor( event.eventName )
            .withBusinessDocumentNumber (event.businessDocumentNumber)
            .withBusinessDocumentCorrelatedNumber( event.businessDocumentCorrelatedNumber )
            .withInternalID (event.internalId)
            .withSender (event.sender)
            .withReceiver (event.receiver)
            .withStatus(EventQueueStatusType.PROCESSING.name())
            .build() );

        setEventPayload();

    }

    virtual
    public void execute() {

        try {

            initEvent();

            event.save();

            handleEvent();

            event.successfullyProcessedEvent();

        } catch (DmlException e) {

            event.errorProcessingEvent(e);

        } catch (Exception e) {

            event.errorProcessingEvent(e);

        } finally {

            event.save();

        }
    }

    public abstract void handleEvent();

    public abstract void setEventPayload();

}