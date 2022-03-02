/**
 * @author: Eduardo Ribeiro de Carvalho - @ercarval
*/
@SuppressWarnings('PMD.AvoidGlobalModifier')
global class IntegrationBusinessException extends Exception {


	public IntegrationBusinessException (IntegrationBusError e) {
		this (e.message);
	}



}
