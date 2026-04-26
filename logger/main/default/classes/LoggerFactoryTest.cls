@isTest
private class LoggerFactoryTest {

    public class CapturingLogger extends AbstractLogger {
        public String lastLevel;
        public String lastMessage;
        public override void info (String source, String message) {
            this.lastLevel = 'INFO';
            this.lastMessage = '[' + source + '] ' + message;
        }
    }

    @isTest
    static void noRegistrationsReturnsDebugLogger () {
        LoggerFactory.reset();

        Test.startTest();
        AbstractLogger l = LoggerFactory.getInstance();
        Test.stopTest();

        System.assert(l instanceof DebugLogger, 'zero active registrations → DebugLogger default');
    }

    @isTest
    static void inactiveRegistrationsFallBackToDebug () {
        LoggerFactory.reset();
        insert new Logger_Registration__c(ClassName__c = 'LoggerFactoryTest.CapturingLogger', IsActive__c = false);

        Test.startTest();
        AbstractLogger l = LoggerFactory.getInstance();
        Test.stopTest();

        System.assert(l instanceof DebugLogger, 'inactive rows are ignored');
    }

    @isTest
    static void unknownClassFallsBackToDebug () {
        LoggerFactory.reset();
        insert new Logger_Registration__c(ClassName__c = 'NotARealLogger', IsActive__c = true);

        Test.startTest();
        AbstractLogger l = LoggerFactory.getInstance();
        Test.stopTest();

        System.assert(l instanceof DebugLogger, 'unresolvable class → DebugLogger fallback');
    }

    @isTest
    static void singleActiveReturnsBareInstance () {
        LoggerFactory.reset();
        insert new Logger_Registration__c(ClassName__c = 'LoggerFactoryTest.CapturingLogger', IsActive__c = true);

        Test.startTest();
        AbstractLogger l = LoggerFactory.getInstance();
        Test.stopTest();

        System.assert(l instanceof CapturingLogger, 'single active → bare instance (no composite wrapping)');
    }

    @isTest
    static void multipleActiveReturnsComposite () {
        LoggerFactory.reset();
        insert new Logger_Registration__c(ClassName__c = 'LoggerFactoryTest.CapturingLogger', IsActive__c = true);
        insert new Logger_Registration__c(ClassName__c = 'DebugLogger', IsActive__c = true);

        Test.startTest();
        AbstractLogger l = LoggerFactory.getInstance();
        Test.stopTest();

        System.assert(l instanceof CompositeLogger, 'multiple active → CompositeLogger');
    }

    @isTest
    static void repeatedCallsReturnCachedInstance () {
        LoggerFactory.reset();

        Test.startTest();
        AbstractLogger a = LoggerFactory.getInstance();
        AbstractLogger b = LoggerFactory.getInstance();
        Test.stopTest();

        System.assert(a === b, 'cached per-transaction');
    }

    @isTest
    static void setMockOverridesResolution () {
        CapturingLogger mock = new CapturingLogger();
        LoggerFactory.setMock(mock);

        Test.startTest();
        AbstractLogger l = LoggerFactory.getInstance();
        l.info('unit', 'hello');
        Test.stopTest();

        System.assertEquals('INFO', mock.lastLevel, 'captured via mock');
        System.assertEquals('[unit] hello', mock.lastMessage, 'formatting preserved');
    }

    @isTest
    static void compositeFansOutToAllChildren () {
        CapturingLogger a = new CapturingLogger();
        CapturingLogger b = new CapturingLogger();
        CompositeLogger c = new CompositeLogger(new List<AbstractLogger>{ a, b });

        Test.startTest();
        c.info('src', 'hello');
        Test.stopTest();

        System.assertEquals('[src] hello', a.lastMessage, 'child A received');
        System.assertEquals('[src] hello', b.lastMessage, 'child B received');
    }
}
