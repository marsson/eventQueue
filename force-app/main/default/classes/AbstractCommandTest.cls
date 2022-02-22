/**
 * @author: Eduardo Ribeiro de Carvalho - @ercarval
 */
@isTest
public class AbstractCommandTest {

	@isTest
	public static void itShoundBeExecuteAllDecoratedMethods() {

		CommandDecoredMock mock = new CommandDecoredMock();

		mock.execute (EventQueueFixtureFactory.createBaseEvent('SYNC_OUTBOUND'));

		System.assert( mock.executed );
		System.assert( mock.preExecuted );
		System.assert( mock.postExecuted ); 

	}

	@isTest
	public static void itShoundBeNotExecuteDecoratedMethods() {

		CommandMock mock = new CommandMock();

		mock.execute (EventQueueFixtureFactory.createBaseEvent('SYNC_OUTBOUND'));

		System.assert( mock.executed );
		System.assert( !mock.preExecuted );
		System.assert( !mock.postExecuted );

	}

	/**
	 * Only for mock execution
	 */
	public class CommandDecoredMock extends AbstractCommand {

		@TestVisible
		private boolean executed = false;

		@TestVisible
		private boolean preExecuted = false;

		@TestVisible
		private boolean postExecuted = false;

		/**
		 * Decorate execution process
		 */
		override
		public void preExecute() {
			preExecuted = true;
		}

		override
		public void execute () {
			executed = true;

		}

		/**
		 * Decorate execution process
		 */
		override
		public void postExecute() {
			postExecuted = true;
		}

	}


	/**
	 * Only for mock execution
	 */
	public class CommandMock extends AbstractCommand {

		@TestVisible
		private boolean executed = false;

		@TestVisible
		private boolean preExecuted = false;

		@TestVisible
		private boolean postExecuted = false;

		override
		public void execute () {
			executed = true;

		}

	}


}