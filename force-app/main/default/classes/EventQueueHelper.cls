/**
 * @description Validation utilities used by the integration layer.
 * Currently provides a single check: whether a Named Credential
 * with the supplied developer name exists in the org.
 *
 * Skipped at runtime when `Test.isRunningTest()` is true so unit
 * tests don't need to provision real Named Credential rows.
 *
 * @author Eduardo Ribeiro de Carvalho - @ercarval
 * @author Heitor Araujo
 * @author Marcelo Marsson
 */
public with sharing class EventQueueHelper {

    /**
     * @description Verify that exactly one Named Credential exists
     * with the given developer name.
     * @param namedCredential Developer name of the Named Credential
     *                        to look up.
     * @return true if exactly one matching Named Credential exists
     *         and is accessible to the running user; false otherwise.
     */
    public static boolean isNamedCredencialValid(String namedCredential){
        Boolean ret = false;
        List<NamedCredential> credentialList = new List <NamedCredential>();
        if (Schema.sObjectType.NamedCredential.isAccessible()) {
            credentialList = [Select Id from NamedCredential where DeveloperName = :namedCredential];
        }

        if(credentialList.size()==1){
            ret= true;
        }
            return ret;
    }
}
