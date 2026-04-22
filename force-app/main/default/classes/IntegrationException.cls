/**
 * @description Technical (retryable) failure raised by the
 * integration layer.
 *
 * Throwing this exception causes the dispatcher to set the event's
 * status to `ERROR` and decrement `RetryCount__c`. The scheduled
 * retry job will re-queue the event until retries are exhausted.
 *
 * Use the `HttpResponse` constructor to derive a useful message
 * from a non-2xx remote call. For permanent business failures use
 * `IntegrationBusinessException` instead — that one disables the
 * retry loop.
 *
 * @author Eduardo Ribeiro de Carvalho - @ercarval
 * @author Heitor Araujo
 * @author Marcelo Marsson
 */
public class IntegrationException extends Exception {

    /**
     * @description Build a technical exception with a message
     * derived from a non-2xx HTTP response.
     * @param httpResponse The failed HTTP response.
     */
    @SuppressWarnings('PMD.AvoidGlobalModifier')
    public IntegrationException (HttpResponse httpResponse) {
        this ( httpResponse.getStatusCode() + ' : ' +  httpResponse.getStatus() + ' [ '+ httpResponse.getBody()  +' ] ' );
    }


}
