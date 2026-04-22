/**
 * @description Structured (code + message) representation of a
 * business failure. Pass an instance to
 * `IntegrationBusinessException` so callers can act on the code
 * programmatically.
 *
 * @author Eduardo Ribeiro de Carvalho - @ercarval
 * @author Heitor Araujo
 * @author Marcelo Marsson
 */
public with sharing class IntegrationBusError {
    public String cod;
    public String message;



    /**
     * @description Build a structured business error.
     * @param cod The business error code (free-form, but should be
     *            stable across releases for downstream handling).
     * @param message Human-readable description of the failure.
     */
    public IntegrationBusError(String cod, String message ) {
        this.cod = cod;
        this.message = message;
    }

    /**
     * @description Whether either field is null.
     * @return true if `cod` or `message` is null.
     */
    public boolean isEmpty () {
        return message == null || cod == null;
    }

}
