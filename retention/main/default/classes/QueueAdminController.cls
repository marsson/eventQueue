/**
 * @description @AuraEnabled surface for the Queue Admin Console LWC.
 * Every entry point gates on `Queue_Admin_Console_Access` custom
 * permission and delegates to `QueueAdminService`.
 *
 * MDT writes build `Metadata.CustomMetadata` + `Metadata.CustomMetadataValue`
 * records, stage them on a `Metadata.DeployContainer`, and hand the
 * container to `Metadata.Operations.enqueueDeployment` together with a
 * `QueueAdminDeployCallback`. The callback persists the outcome so the
 * LWC can poll `getDeploymentStatus()` instead of blindly waiting.
 *
 * NOTE: the Metadata API does not support deleting individual custom
 * metadata records from Apex. To remove a policy or event configuration,
 * use Setup → Custom Metadata Types → Manage Records → Del on the
 * relevant type.
 */
public with sharing class QueueAdminController {

    private static void requireAccess () {
        if (!FeatureManagement.checkPermission('Queue_Admin_Console_Access')) {
            AuraHandledException ex = new AuraHandledException('Not authorized: Queue Admin Console');
            ex.setMessage('Not authorized: Queue Admin Console');
            throw ex;
        }
    }

    // AuraHandledException hides the constructor message from the client
    // ("Script-thrown exception") unless setMessage() is also called.
    private static AuraHandledException clientError (String msg) {
        AuraHandledException ex = new AuraHandledException(msg);
        ex.setMessage(msg);
        return ex;
    }

    // ─── overview ───────────────────────────────────────────────────

    @AuraEnabled(cacheable=false)
    public static QueueAdminService.OverviewDTO getOverview () {
        requireAccess();
        try {
            return QueueAdminService.getOverview();
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ─── policies ───────────────────────────────────────────────────

    @AuraEnabled(cacheable=false)
    public static List<QueueAdminService.PolicyDTO> listPolicies () {
        requireAccess();
        try {
            return QueueAdminService.listPolicies();
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=false)
    public static Integer previewPolicyMatch (String developerName) {
        requireAccess();
        try {
            return QueueAdminService.previewPolicyMatch(developerName);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=false)
    public static Id runPolicyNow (String developerName, Boolean dryRun) {
        requireAccess();
        try {
            return QueueAdminService.runPolicyNow(developerName, dryRun);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * @description Upsert an MDT policy. Enqueues a deployment via
     * `Metadata.Operations` with a `QueueAdminDeployCallback` that
     * persists the outcome; LWC polls `getDeploymentStatus()` for
     * completion.
     *
     * NOTE: the Metadata API does not support deleting individual
     * custom metadata records from Apex — remove a policy from
     * Setup → Custom Metadata Types → Queue Retention Policy →
     * Manage Records → Del.
     */
    @AuraEnabled(cacheable=false)
    public static Id upsertPolicy (Map<String, Object> dto) {
        requireAccess();
        try {
            if (dto == null || dto.isEmpty()) {
                throw clientError('Policy payload was empty.');
            }
            // LWC -> Apex bridge: deserialize via JSON to keep the
            // signature LWC-friendly (no inner-class no-arg-ctor trap).
            QueueAdminService.PolicyDTO cleanDto = (QueueAdminService.PolicyDTO) JSON.deserialize(
                JSON.serialize(dto), QueueAdminService.PolicyDTO.class
            );
            if (String.isBlank(cleanDto.developerName)) {
                throw clientError('Developer Name is required.');
            }
            if (String.isBlank(cleanDto.label)) {
                throw clientError('Label is required.');
            }
            if (String.isBlank(cleanDto.status)) {
                throw clientError('Status is required.');
            }
            // D3 uniqueness pre-flight (cheaper than waiting for deploy to reject).
            Queue_Retention_Policy__mdt candidate = new Queue_Retention_Policy__mdt(
                DeveloperName     = cleanDto.developerName,
                Label             = cleanDto.label,
                Status__c         = cleanDto.status,
                RetentionDays__c  = cleanDto.retentionDays,
                IsActive__c       = cleanDto.isActive,
                MaxDeletePerRun__c = cleanDto.maxDeletePerRun,
                DryRun__c         = cleanDto.dryRun,
                Notes__c          = cleanDto.notes
            );
            if (QueueRetentionPolicyProvider.hasActiveConflict(candidate)) {
                throw clientError(
                    'Another active policy already targets status "'
                    + cleanDto.status + '". Deactivate it first (D3 uniqueness rule).'
                );
            }

            Metadata.CustomMetadata record = buildMetadataRecord(cleanDto);
            Metadata.DeployContainer container = new Metadata.DeployContainer();
            container.addMetadata(record);
            return Metadata.Operations.enqueueDeployment(container, new QueueAdminDeployCallback());
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw clientError(e.getMessage());
        }
    }

    public class DeploymentStatusDTO {
        @AuraEnabled public String state;
        @AuraEnabled public String errorMessage;
    }

    /**
     * @description Reads the outcome written by `QueueAdminDeployCallback`
     * from Platform Cache. States: `Pending`, `InProgress`, `Succeeded`,
     * `SucceededPartial`, `Failed`, `Canceled`, `Canceling`, or `Unknown`
     * (the latter signals that the `local.QueueAdminDeploy` cache
     * partition is not allocated — the LWC should fall back to a
     * single-shot refresh rather than polling forever).
     */
    @AuraEnabled(cacheable=false)
    public static DeploymentStatusDTO getDeploymentStatus (Id deploymentId) {
        requireAccess();
        DeploymentStatusDTO d = new DeploymentStatusDTO();
        d.state = 'Pending';
        try {
            Cache.OrgPartition partition = Cache.Org.getPartition(QueueAdminDeployCallback.PARTITION_NAME);
            if (partition == null) {
                d.state = 'Unknown';
                return d;
            }
            Map<String, String> stored = (Map<String, String>) partition.get(
                QueueAdminDeployCallback.cacheKey(String.valueOf(deploymentId))
            );
            if (stored != null) {
                d.state        = stored.get('state');
                d.errorMessage = stored.get('errorMessage');
            }
        } catch (Exception ignored) {
            d.state = 'Unknown';
        }
        return d;
    }

    // ─── purge logs ─────────────────────────────────────────────────

    @AuraEnabled(cacheable=false)
    public static List<Queue_Purge_Log__c> listPurgeLogs (String statusFilter, Integer limitTo) {
        requireAccess();
        try {
            return QueueAdminService.listPurgeLogs(statusFilter, limitTo);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ─── scheduling ─────────────────────────────────────────────────

    @AuraEnabled(cacheable=false)
    public static List<QueueAdminService.ScheduleDTO> getScheduleStatus () {
        requireAccess();
        try {
            return QueueAdminService.getScheduleStatus();
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=false)
    public static void startJob (String className, String cronExpression) {
        requireAccess();
        try {
            QueueAdminService.startJob(className, cronExpression);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=false)
    public static void abortJob (String className) {
        requireAccess();
        try {
            QueueAdminService.abortJob(className);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ─── settings ───────────────────────────────────────────────────

    @AuraEnabled(cacheable=false)
    public static QueueAdminService.SettingsDTO getAllSettings () {
        requireAccess();
        try {
            return QueueAdminService.getAllSettings();
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=false)
    public static void upsertQueueAdminSetting (Queue_Admin_Setting__c setting) {
        requireAccess();
        try {
            setting.SetupOwnerId = UserInfo.getOrganizationId();
            upsert setting;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ─── notifier / logger registrations (instant toggles) ─────────

    @AuraEnabled(cacheable=false)
    public static List<Notifier_Registration__c> listNotifierRegistrations () {
        requireAccess();
        try {
            return QueueAdminService.listNotifierRegistrations();
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=false)
    public static Id upsertNotifierRegistration (Notifier_Registration__c registration) {
        requireAccess();
        try {
            if (!QueueAdminService.classExtends(registration.ClassName__c, 'AbstractNotifier')) {
                throw new AuraHandledException(
                    'Class "' + registration.ClassName__c + '" does not extend AbstractNotifier.'
                );
            }
            upsert registration;
            return registration.Id;
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=false)
    public static void toggleNotifierRegistration (Id registrationId, Boolean isActive) {
        requireAccess();
        try {
            update new Notifier_Registration__c(Id = registrationId, IsActive__c = isActive);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=false)
    public static void deleteNotifierRegistration (Id registrationId) {
        requireAccess();
        try {
            delete new Notifier_Registration__c(Id = registrationId);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=false)
    public static List<Logger_Registration__c> listLoggerRegistrations () {
        requireAccess();
        try {
            return QueueAdminService.listLoggerRegistrations();
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=false)
    public static Id upsertLoggerRegistration (Logger_Registration__c registration) {
        requireAccess();
        try {
            if (!QueueAdminService.classExtends(registration.ClassName__c, 'AbstractLogger')) {
                throw new AuraHandledException(
                    'Class "' + registration.ClassName__c + '" does not extend AbstractLogger.'
                );
            }
            upsert registration;
            return registration.Id;
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=false)
    public static void toggleLoggerRegistration (Id registrationId, Boolean isActive) {
        requireAccess();
        try {
            update new Logger_Registration__c(Id = registrationId, IsActive__c = isActive);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=false)
    public static void deleteLoggerRegistration (Id registrationId) {
        requireAccess();
        try {
            delete new Logger_Registration__c(Id = registrationId);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ─── event configurations (MDT) ─────────────────────────────────

    @AuraEnabled(cacheable=false)
    public static List<QueueAdminService.EventConfigurationDTO> listEventConfigurations () {
        requireAccess();
        try {
            return QueueAdminService.listEventConfigurations();
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * @description Upsert an Event Configuration MDT record. See
     * `upsertPolicy` for the deploy/callback/polling contract. Deleting
     * an Event Configuration must be done from Setup → Custom Metadata
     * Types → Event Configuration → Manage Records → Del.
     */
 @AuraEnabled(cacheable=false)
public static Id upsertEventConfiguration(Map<String, Object> dto) {
    requireAccess();
    try {
        if (dto == null || dto.isEmpty()) {
            throw clientError('Event configuration payload was empty.');
        }
         QueueAdminService.EventConfigurationDTO adto = (QueueAdminService.EventConfigurationDTO) JSON.deserialize(
            JSON.serialize(dto), QueueAdminService.EventConfigurationDTO.class
        );
        if (String.isBlank(adto.developerName)) {
            throw clientError('Developer Name is required.');
        }
        if (String.isBlank(adto.label)) {
            throw clientError('Label is required.');
        }
        Metadata.CustomMetadata record = buildEventConfigMetadata(adto);
        Metadata.DeployContainer container = new Metadata.DeployContainer();
        container.addMetadata(record);
        return Metadata.Operations.enqueueDeployment(container, new QueueAdminDeployCallback());
    } catch (AuraHandledException e) {
        throw e;
    } catch (Exception e) {
        throw clientError(e.getMessage());
    }
}

    // ─── internals ──────────────────────────────────────────────────

    private static Metadata.CustomMetadata buildMetadataRecord (QueueAdminService.PolicyDTO dto) {
        Metadata.CustomMetadata rec = new Metadata.CustomMetadata();
        rec.fullName = 'Queue_Retention_Policy.' + dto.developerName;
        rec.label    = dto.label;
        rec.values   = new List<Metadata.CustomMetadataValue>();

        rec.values.add(field('Status__c',          dto.status));
        rec.values.add(field('RetentionDays__c',   dto.retentionDays));
        rec.values.add(field('IsActive__c',        dto.isActive));
        rec.values.add(field('MaxDeletePerRun__c', dto.maxDeletePerRun));
        rec.values.add(field('DryRun__c',          dto.dryRun));
        rec.values.add(field('Notes__c',           dto.notes));
        return rec;
    }

    private static Metadata.CustomMetadataValue field (String name, Object value) {
        Metadata.CustomMetadataValue v = new Metadata.CustomMetadataValue();
        v.field = name;
        v.value = value;
        return v;
    }

    private static Metadata.CustomMetadata buildEventConfigMetadata (QueueAdminService.EventConfigurationDTO dto) {
        Metadata.CustomMetadata rec = new Metadata.CustomMetadata();
        rec.fullName = 'Event_Configuration.' + dto.developerName;
        rec.label    = dto.label;
        rec.values   = new List<Metadata.CustomMetadataValue>();

        rec.values.add(field('CommandClassName__c',  dto.commandClassName));
        rec.values.add(field('Method__c',            dto.method));
        rec.values.add(field('NamedCredencial__c',   dto.namedCredential));
        rec.values.add(field('DisableDispatcher__c', dto.disableDispatcher));
        return rec;
    }
}
