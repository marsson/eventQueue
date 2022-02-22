/**
 * Created by marcelowork on 2019-07-06.
 */

public with sharing class EventQueueHelper {

    public static boolean isNamedCredencialValid(String namedCredential){
        Boolean ret = false;
        List<NamedCredential> credentialList = new List <NamedCredential>();
        if (Schema.sObjectType.Queue__c.isAccessible()) {
            credentialList = [Select Id from NamedCredential where DeveloperName = :namedCredential];
        }

        if(credentialList.size()==1){
            ret= true;
        }
            return ret;
    }
}