@isTest
private class AbstractLoggerTest {

    @isTest
    static void allLevelsAreNoOps () {
        AbstractLogger l = new AbstractLogger();

        Test.startTest();
        l.debug('src', 'd');
        l.info ('src', 'i');
        l.warn ('src', 'w');
        l.error('src', 'e', new System.AsyncException('boom'));
        Test.stopTest();

        System.assert(true, 'no-op defaults must not throw');
    }
}
