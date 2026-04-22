/**
 * @description Classification labels for exceptions raised by
 * commands. Documents the framework's distinction between
 * non-retryable business failures and retryable technical failures.
 *
 * Informational only — the dispatcher routes by exception class
 * (`IntegrationBusinessException` vs everything else), not by this
 * enum value.
 *
 * @author Eduardo Ribeiro de Carvalho - @ercarval
 * @author Heitor Araujo
 * @author Marcelo Marsson
 */
public enum  ExceptionType {

    BUSINESS, TECHNICAL
}
