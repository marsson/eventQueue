/**
 * @description Business logic for the Queue Admin Console. Sits
 * between `QueueAdminController` (@AuraEnabled entry points) and the
 * engine classes so the controller stays a thin authorization +
 * marshalling layer.
 */
public with sharing class QueueAdminService {

    private static final String SRC = 'QueueAdminService';
    private static final Set<String> SCHEDULABLE_WHITELIST = new Set<String>{
        'JobPendingEvents', 'JobOldQueuedEvents', 'JobRetryEventProcessor', 'JobQueueRetention'
    };

    // ─── overview ───────────────────────────────────────────────────

    public class QueueStatusRow {
        @AuraEnabled public String status;
        @AuraEnabled public Integer total;
        @AuraEnabled public Datetime oldestCreatedDate;
    }

    public class OverviewDTO {
        @AuraEnabled public Boolean retentionEnabled;
        @AuraEnabled public Boolean globalDryRun;
        @AuraEnabled public Datetime nextRetentionFireAt;
        @AuraEnabled public String nextRetentionCronExpression;
        @AuraEnabled public Queue_Purge_Log__c lastPurge;
        @AuraEnabled public List<QueueStatusRow> statusBreakdown;
    }

    public static OverviewDTO getOverview () {
        OverviewDTO dto = new OverviewDTO();

        Queue_Admin_Setting__c s = Queue_Admin_Setting__c.getOrgDefaults();
        dto.retentionEnabled = s != null && s.IsRetentionEnabled__c == true;
        dto.globalDryRun     = s != null && s.GlobalDryRun__c == true;

        List<CronTrigger> jobs = [
            SELECT NextFireTime, CronExpression, CronJobDetail.Name
            FROM CronTrigger
            WHERE CronJobDetail.Name LIKE 'JobQueueRetention%'
            ORDER BY NextFireTime ASC
            LIMIT 1
        ];
        if (!jobs.isEmpty()) {
            dto.nextRetentionFireAt         = jobs[0].NextFireTime;
            dto.nextRetentionCronExpression = jobs[0].CronExpression;
        }

        List<Queue_Purge_Log__c> recent = [
            SELECT Id, Name, RunStartedAt__c, PolicyLabel__c, Status__c, RecordsDeleted__c
            FROM Queue_Purge_Log__c
            ORDER BY RunStartedAt__c DESC
            LIMIT 1
        ];
        if (!recent.isEmpty()) dto.lastPurge = recent[0];

        List<AggregateResult> agg = [
            SELECT Status__c status, COUNT(Id) total, MIN(CreatedDate) oldest
            FROM Queue__c
            GROUP BY Status__c
        ];
        dto.statusBreakdown = new List<QueueStatusRow>();
        for (AggregateResult a : agg) {
            QueueStatusRow row = new QueueStatusRow();
            row.status            = (String) a.get('status');
            row.total             = ((Decimal) a.get('total')).intValue();
            row.oldestCreatedDate = (Datetime) a.get('oldest');
            dto.statusBreakdown.add(row);
        }
        return dto;
    }

    // ─── policies ───────────────────────────────────────────────────

    public class PolicyDTO {
        @AuraEnabled public String developerName;
        @AuraEnabled public String label;
        @AuraEnabled public String status;
        @AuraEnabled public Integer retentionDays;
        @AuraEnabled public Boolean isActive;
        @AuraEnabled public Integer maxDeletePerRun;
        @AuraEnabled public Boolean dryRun;
        @AuraEnabled public String notes;

        // Derived from latest Queue_Purge_Log__c for this policy
        @AuraEnabled public Datetime lastRunAt;
        @AuraEnabled public String lastRunStatus;
        @AuraEnabled public Integer lastRunDeleted;
    }

    public static List<PolicyDTO> listPolicies () {
        List<Queue_Retention_Policy__mdt> policies = QueueRetentionPolicyProvider.getAll();
        Map<String, Queue_Purge_Log__c> latestByPolicy = latestLogByPolicy();

        List<PolicyDTO> out = new List<PolicyDTO>();
        for (Queue_Retention_Policy__mdt p : policies) {
            PolicyDTO d = new PolicyDTO();
            d.developerName   = p.DeveloperName;
            d.label           = p.Label;
            d.status          = p.Status__c;
            d.retentionDays   = p.RetentionDays__c == null ? null : Integer.valueOf(p.RetentionDays__c);
            d.isActive        = p.IsActive__c == true;
            d.maxDeletePerRun = p.MaxDeletePerRun__c == null ? null : Integer.valueOf(p.MaxDeletePerRun__c);
            d.dryRun          = p.DryRun__c == true;
            d.notes           = p.Notes__c;

            Queue_Purge_Log__c last = latestByPolicy.get(p.DeveloperName);
            if (last != null) {
                d.lastRunAt      = last.RunStartedAt__c;
                d.lastRunStatus  = last.Status__c;
                d.lastRunDeleted = last.RecordsDeleted__c == null ? 0 : Integer.valueOf(last.RecordsDeleted__c);
            }
            out.add(d);
        }
        return out;
    }

    private static Map<String, Queue_Purge_Log__c> latestLogByPolicy () {
        Map<String, Queue_Purge_Log__c> result = new Map<String, Queue_Purge_Log__c>();
        for (Queue_Purge_Log__c l : [
            SELECT Id, PolicyDeveloperName__c, RunStartedAt__c, Status__c, RecordsDeleted__c
            FROM Queue_Purge_Log__c
            WHERE PolicyDeveloperName__c != NULL
            ORDER BY RunStartedAt__c DESC
            LIMIT 1000
        ]) {
            if (!result.containsKey(l.PolicyDeveloperName__c)) {
                result.put(l.PolicyDeveloperName__c, l);
            }
        }
        return result;
    }

    // ─── runtime actions ────────────────────────────────────────────

    public static Id runPolicyNow (String developerName, Boolean dryRun) {
        Queue_Retention_Policy__mdt p = QueueRetentionPolicyProvider.getByDeveloperName(developerName);
        if (p == null) {
            throw new AuraHandledException('Policy not found: ' + developerName);
        }

        // Clone the policy so we don't mutate the cached MDT record.
        Queue_Retention_Policy__mdt runCopy = p.clone(false, true, false, false);
        if (dryRun == true) runCopy.DryRun__c = true;

        String triggerSource = (dryRun == true) ? 'DRY_RUN_MANUAL' : 'MANUAL';
        Integer chunk = resolveChunkSize();

        LoggerFactory.getInstance().info(SRC,
            'run-now: policy=' + developerName + ' dryRun=' + dryRun + ' trigger=' + triggerSource);

        return Database.executeBatch(
            new QueueRetentionBatch(runCopy, new List<Queue_Retention_Policy__mdt>(), triggerSource, UserInfo.getUserId(), 0),
            chunk
        );
    }

    public static Integer previewPolicyMatch (String developerName) {
        Queue_Retention_Policy__mdt p = QueueRetentionPolicyProvider.getByDeveloperName(developerName);
        if (p == null) throw new AuraHandledException('Policy not found: ' + developerName);

        DateTime cutoff = System.now().addDays(-Integer.valueOf(p.RetentionDays__c));
        String status = p.Status__c;
        Integer cap = p.MaxDeletePerRun__c == null ? 10000 : Integer.valueOf(p.MaxDeletePerRun__c);

        return [SELECT COUNT() FROM Queue__c WHERE Status__c = :status AND CreatedDate < :cutoff LIMIT :cap];
    }

    public static List<Queue_Purge_Log__c> listPurgeLogs (String statusFilter, Integer limitTo) {
        Integer cap = limitTo == null ? 200 : Math.min(limitTo, 2000);
        if (String.isBlank(statusFilter)) {
            return [
                SELECT Id, Name, RunStartedAt__c, RunCompletedAt__c, DurationSeconds__c,
                       PolicyDeveloperName__c, PolicyLabel__c, Status__c,
                       RecordsEvaluated__c, RecordsDeleted__c, RecordsSkipped__c,
                       ChunkCount__c, TriggeredBy__c, DeleteStrategy__c
                FROM Queue_Purge_Log__c
                ORDER BY RunStartedAt__c DESC
                LIMIT :cap
            ];
        }
        return [
            SELECT Id, Name, RunStartedAt__c, RunCompletedAt__c, DurationSeconds__c,
                   PolicyDeveloperName__c, PolicyLabel__c, Status__c,
                   RecordsEvaluated__c, RecordsDeleted__c, RecordsSkipped__c,
                   ChunkCount__c, TriggeredBy__c, DeleteStrategy__c
            FROM Queue_Purge_Log__c
            WHERE Status__c = :statusFilter
            ORDER BY RunStartedAt__c DESC
            LIMIT :cap
        ];
    }

    // ─── scheduling ─────────────────────────────────────────────────

    public class ScheduleDTO {
        @AuraEnabled public String className;
        @AuraEnabled public Boolean scheduled;
        @AuraEnabled public Datetime nextFire;
        @AuraEnabled public String cronExpression;
        @AuraEnabled public Datetime previousFire;
    }

    public static List<ScheduleDTO> getScheduleStatus () {
        List<ScheduleDTO> out = new List<ScheduleDTO>();
        Map<String, List<CronTrigger>> byPrefix = new Map<String, List<CronTrigger>>();
        for (String p : SCHEDULABLE_WHITELIST) byPrefix.put(p, new List<CronTrigger>());

        for (CronTrigger t : [
            SELECT Id, NextFireTime, PreviousFireTime, CronExpression, CronJobDetail.Name
            FROM CronTrigger
            WHERE CronJobDetail.Name LIKE 'Job%'
            ORDER BY NextFireTime ASC
        ]) {
            for (String prefix : SCHEDULABLE_WHITELIST) {
                if (t.CronJobDetail.Name.startsWith(prefix)) {
                    byPrefix.get(prefix).add(t);
                    break;
                }
            }
        }

        for (String className : SCHEDULABLE_WHITELIST) {
            ScheduleDTO d = new ScheduleDTO();
            d.className = className;
            List<CronTrigger> matches = byPrefix.get(className);
            d.scheduled = !matches.isEmpty();
            if (!matches.isEmpty()) {
                d.nextFire        = matches[0].NextFireTime;
                d.cronExpression  = matches[0].CronExpression;
                d.previousFire    = matches[0].PreviousFireTime;
            }
            out.add(d);
        }
        return out;
    }

    public static void startJob (String className, String cronExpression) {
        requireWhitelisted(className);
        switch on className {
            when 'JobQueueRetention' {
                if (String.isBlank(cronExpression)) JobQueueRetention.start();
                else                                JobQueueRetention.start(cronExpression);
            }
            when 'JobPendingEvents'      { JobPendingEvents.start(); }
            when 'JobOldQueuedEvents'    { JobOldQueuedEvents.start(); }
            when 'JobRetryEventProcessor'{ JobRetryEventProcessor.start(); }
        }
    }

    public static void abortJob (String className) {
        requireWhitelisted(className);
        switch on className {
            when 'JobQueueRetention'     { JobQueueRetention.abort(); }
            when 'JobPendingEvents'      { JobPendingEvents.abort(); }
            when 'JobOldQueuedEvents'    { JobOldQueuedEvents.abort(); }
            when 'JobRetryEventProcessor'{ JobRetryEventProcessor.abort(); }
        }
    }

    // ─── event configurations ───────────────────────────────────────

    public class EventConfigurationDTO {
        @AuraEnabled public String developerName;
        @AuraEnabled public String label;
        @AuraEnabled public String commandClassName;
        @AuraEnabled public String method;
        @AuraEnabled public String namedCredential;
        @AuraEnabled public Boolean disableDispatcher;
    }

    public static List<EventConfigurationDTO> listEventConfigurations () {
        List<EventConfigurationDTO> out = new List<EventConfigurationDTO>();
        for (Event_Configuration__mdt c : [
            SELECT DeveloperName, Label, CommandClassName__c, Method__c, NamedCredencial__c, DisableDispatcher__c
            FROM Event_Configuration__mdt
            ORDER BY Label ASC
        ]) {
            EventConfigurationDTO d = new EventConfigurationDTO();
            d.developerName     = c.DeveloperName;
            d.label             = c.Label;
            d.commandClassName  = c.CommandClassName__c;
            d.method            = c.Method__c;
            d.namedCredential   = c.NamedCredencial__c;
            d.disableDispatcher = c.DisableDispatcher__c == true;
            out.add(d);
        }
        return out;
    }

    // ─── settings ───────────────────────────────────────────────────

    public class SettingsDTO {
        @AuraEnabled public Queue_Admin_Setting__c queueAdmin;
    }

    public static SettingsDTO getAllSettings () {
        SettingsDTO d = new SettingsDTO();
        d.queueAdmin = Queue_Admin_Setting__c.getOrgDefaults();
        return d;
    }

    // ─── notifier / logger registrations ────────────────────────────

    public static List<Notifier_Registration__c> listNotifierRegistrations () {
        return [
            SELECT Id, Name, ClassName__c, IsActive__c, Description__c
            FROM Notifier_Registration__c
            ORDER BY Name ASC
        ];
    }

    public static List<Logger_Registration__c> listLoggerRegistrations () {
        return [
            SELECT Id, Name, ClassName__c, IsActive__c, Description__c
            FROM Logger_Registration__c
            ORDER BY Name ASC
        ];
    }

    // ─── helpers ────────────────────────────────────────────────────

    private static Integer resolveChunkSize () {
        Queue_Admin_Setting__c s = Queue_Admin_Setting__c.getOrgDefaults();
        if (s != null && s.ChunkSize__c != null) return Integer.valueOf(s.ChunkSize__c);
        return 2000;
    }

    private static void requireWhitelisted (String className) {
        if (!SCHEDULABLE_WHITELIST.contains(className)) {
            throw new AuraHandledException('Class not allowed: ' + className);
        }
    }

    public static Boolean classExtends (String className, String abstractClassName) {
        if (String.isBlank(className)) return true;  // blank is a valid "no-op" config
        Type t = Type.forName(className);
        if (t == null) return false;
        try {
            Object instance = t.newInstance();
            if (abstractClassName == 'AbstractNotifier') return instance instanceof AbstractNotifier;
            if (abstractClassName == 'AbstractLogger')   return instance instanceof AbstractLogger;
        } catch (Exception e) {
            return false;
        }
        return false;
    }
}
