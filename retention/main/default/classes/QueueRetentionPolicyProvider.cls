/**
 * @description MDT cache + test seam for `Queue_Retention_Policy__mdt`.
 * Mirrors the `EventQueueActiveRecord` MDT-caching idiom — one SOQL
 * at first read, in-memory thereafter, `setMock(...)` for tests that
 * can't rely on deployed MDT records.
 */
public with sharing class QueueRetentionPolicyProvider {

    @TestVisible private static List<Queue_Retention_Policy__mdt> mock;
    private static List<Queue_Retention_Policy__mdt> cached;

    /**
     * @description Returns every policy in the org (active + inactive).
     */
    public static List<Queue_Retention_Policy__mdt> getAll () {
        if (mock != null) return mock;
        if (cached != null) return cached;

        cached = [
            SELECT DeveloperName, Label, Status__c, RetentionDays__c,
                   IsActive__c, MaxDeletePerRun__c, DryRun__c, Notes__c
            FROM Queue_Retention_Policy__mdt
        ];
        return cached;
    }

    /**
     * @description Returns only the active policies — what the
     * scheduled job iterates at runtime.
     */
    public static List<Queue_Retention_Policy__mdt> getActive () {
        List<Queue_Retention_Policy__mdt> actives = new List<Queue_Retention_Policy__mdt>();
        for (Queue_Retention_Policy__mdt p : getAll()) {
            if (p.IsActive__c == true) actives.add(p);
        }
        return actives;
    }

    /**
     * @description Lookup by DeveloperName.
     * @param developerName Key of the policy.
     * @return Matching policy, or `null` if not found.
     */
    public static Queue_Retention_Policy__mdt getByDeveloperName (String developerName) {
        for (Queue_Retention_Policy__mdt p : getAll()) {
            if (p.DeveloperName == developerName) return p;
        }
        return null;
    }

    /**
     * @description True when another active policy already targets the
     * same `Status__c` as the candidate. Used by the upsert path to
     * enforce D3 uniqueness before hitting `Metadata.Operations`.
     * @param candidate Policy about to be upserted.
     * @return true when a conflict exists.
     */
    public static Boolean hasActiveConflict (Queue_Retention_Policy__mdt candidate) {
        if (candidate == null || candidate.IsActive__c != true) return false;
        for (Queue_Retention_Policy__mdt p : getActive()) {
            if (p.DeveloperName == candidate.DeveloperName) continue;
            if (p.Status__c == candidate.Status__c) return true;
        }
        return false;
    }

    @TestVisible
    private static void setMock (List<Queue_Retention_Policy__mdt> m) {
        mock = m;
    }

    @TestVisible
    private static void reset () {
        mock = null;
        cached = null;
    }
}
