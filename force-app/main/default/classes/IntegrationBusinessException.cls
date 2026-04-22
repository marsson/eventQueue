/**
 * @description Business (non-retryable) failure raised by a
 * command. Signals that the event is permanently invalid and
 * automated retries should not be attempted.
 *
 * Throwing this exception causes the dispatcher to set the event's
 * status to `ERROR`, set `IsRetryDisabled__c = true`, and zero
 * the retry counter. Human intervention is required to re-queue
 * the event.
 *
 * @author Eduardo Ribeiro de Carvalho - @ercarval
 * @author Heitor Araujo
 * @author Marcelo Marsson
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
global class IntegrationBusinessException extends Exception {


    /**
     * @description Build a business exception from an
     * `IntegrationBusError` describing the code and message of the
     * failure.
     * @param e The structured business error to surface.
     */
    public IntegrationBusinessException (IntegrationBusError e) {
        this (e.message);
    }



}
