/**
 * @author: Eduardo Ribeiro de Carvalho - @ercarval
*/
public class IntegrationBusinessException extends Exception {


	public IntegrationBusinessException (IntegrationBusError e) {
		this (e.message);
	}



}