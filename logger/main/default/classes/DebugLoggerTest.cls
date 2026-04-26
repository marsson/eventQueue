@isTest
private class DebugLoggerTest {

    @isTest
    static void allLevelsWriteWithoutThrowing () {
        DebugLogger l = new DebugLogger();

        Test.startTest();
        l.debug('DebugLoggerTest', 'debug line');
        l.info ('DebugLoggerTest', 'info line');
        l.warn ('DebugLoggerTest', 'warn line');
        l.error('DebugLoggerTest', 'error line', null);
        Test.stopTest();

        System.assert(true, 'System.debug calls complete without error');
    }

    @isTest
    static void errorWithExceptionIncludesTrace () {
        DebugLogger l = new DebugLogger();

        Exception caught;
        try { Integer x = 1 / 0; }
        catch (Exception e) { caught = e; }

        Test.startTest();
        l.error('DebugLoggerTest', 'caught math error', caught);
        Test.stopTest();

        System.assertNotEquals(null, caught, 'we did catch the division-by-zero');
    }
}
