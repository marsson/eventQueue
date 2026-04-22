/**
 * @description Tests for `AbstractCommand`'s template method.
 * Verifies that the lifecycle hooks (`preExecute`, `execute`,
 * `postExecute`) are invoked when overridden, and skipped
 * otherwise (default no-ops still run, but observable side
 * effects only occur on overrides).
 *
 * @author Eduardo Ribeiro de Carvalho - @ercarval
 * @author Heitor Araujo
 * @author Marcelo Marsson
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