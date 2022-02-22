/**
 * @author: Eduardo Ribeiro de Carvalho - @ercarval
*/

public with sharing class IntegrationBusError {
    public String cod;
    public String message;



    public IntegrationBusError(String cod, String message ) {
        this.cod = cod;
        this.message = message;
    }

    public boolean isEmpty () {
        return message == null || cod == null;
    }

}
