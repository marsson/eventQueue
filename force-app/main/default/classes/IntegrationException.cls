/**
 * @author: Eduardo Ribeiro de Carvalho - @ercarval
 */
public class IntegrationException extends Exception {
	@SuppressWarnings('PMD.AvoidGlobalModifier')
	public IntegrationException (HttpResponse httpResponse) {
		this ( httpResponse.getStatusCode() + ' : ' +  httpResponse.getStatus() + ' [ '+ httpResponse.getBody()  +' ] ' );
	}


}
