/**
 * @description Contract for inbound REST services that don't
 * originate from a `Queue__c` row. Currently declared but not
 * referenced by the dispatcher; intended as a symmetric counterpart
 * to `AbstractOutboundCommand` for future expansion.
 *
 * @author Eduardo Ribeiro de Carvalho - @ercarval
 * @author Heitor Araujo
 * @author Marcelo Marsson
 */
public interface InboundService {

    /**
     * @description Run the inbound service.
     */
    void execute();
}
