/**
 * @description `Metadata.DeployCallback` invoked asynchronously once the
 * Metadata API finishes applying an MDT write enqueued by the Queue
 * Admin Console. Persists the outcome to Platform Cache so
 * `QueueAdminController.getDeploymentStatus(deploymentId)` can surface
 * it back to the LWC.
 *
 * The cache partition (`local.QueueAdminDeploy`) is optional — if the
 * org has not allocated capacity to it, writes are swallowed and the
 * controller falls back to the fixed-wait refresh the LWC already
 * performs.
 *
 * NOTE: The Metadata API exposes no delete operation for individual
 * custom metadata records from Apex. Removal must be performed from
 * Setup → Custom Metadata Types → Manage Records → Del.
 */
public without sharing class QueueAdminDeployCallback implements Metadata.DeployCallback {

    private static final String SRC = 'QueueAdminDeployCallback';
    public static final String PARTITION_NAME = 'local.QueueAdminDeploy';

    public void handleResult (Metadata.DeployResult result, Metadata.DeployCallbackContext ctx) {
        if (result == null) return;

        AbstractLogger log = LoggerFactory.getInstance();
        String deployId = result.id;
        String state    = String.valueOf(result.status);
        String error    = summariseErrors(result);

        try {
            Cache.OrgPartition partition = Cache.Org.getPartition(PARTITION_NAME);
            partition.put(cacheKey(deployId), new Map<String, String>{
                'state'        => state,
                'errorMessage' => error
            });
        } catch (Exception e) {
            log.warn(SRC,
                'cache partition unavailable (' + PARTITION_NAME
                + '), result not persisted: ' + e.getMessage());
        }

        log.info(SRC,
            'id=' + deployId + ' state=' + state
            + (String.isBlank(error) ? '' : ' error=' + error));
    }

    public static String cacheKey (String deploymentId) {
        return 'deploy_' + deploymentId;
    }

    private String summariseErrors (Metadata.DeployResult result) {
        if (result.details == null || result.details.componentFailures == null
                || result.details.componentFailures.isEmpty()) {
            return null;
        }
        List<String> parts = new List<String>();
        for (Metadata.DeployMessage m : result.details.componentFailures) {
            parts.add(m.fullName + ': ' + m.problem);
        }
        return String.join(parts, ' | ');
    }
}
