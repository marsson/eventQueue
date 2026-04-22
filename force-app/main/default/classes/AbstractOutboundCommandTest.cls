/**
 * @description Tests for `AbstractOutboundCommand`. Uses an inner
 * mock subclass that overrides `send()` to bypass the HTTP layer
 * and verifies that `tranformToSend`, `execute` and
 * `processResult` run in the expected order.
 *
 * @author Eduardo Ribeiro de Carvalho - @ercarval
 * @author Heitor Araujo
 * @author Marcelo Marsson
 */
@isTest
private class AbstractOutboundCommandTest {
		
	@isTest	
	public static void givenOutboundEventThenGenericOutboundCommandTransformAndSendRequest () {

		EventQueue event = EventQueueFixtureFactory.createBaseEvent('EventUnitTest');

		OutboundCommandMock outboundMock = new OutboundCommandMock();

		outboundMock.execute(event);

		System.assert( outboundMock.targetObject instanceOf Contact );
		System.assertEquals( outboundMock.targetObject , outboundMock.MOCK_OBJ );
		System.assert( outboundMock.postResultExecuted );

	}	


	public class OutboundCommandMock extends AbstractOutboundCommand {

		public final Contact MOCK_OBJ = new Contact (email='Bisso'); 

		@TestVisible
		private String toBeTransformed = '{"attributes":{"type":"Contact"},"Email":"Bisso"}';

		@TestVisible
		private Contact mockResponse;

		
		@TestVisible
		private boolean postResultExecuted;

		override
		public Object send() {
			return MOCK_OBJ;
		}

		override
		public Object tranformToSend () {
			return JSON.deserialize( toBeTransformed , Contact.class );
		}

		override
		public void processResult (Object responseObject) {
			postResultExecuted = true;
		}	

	}


}