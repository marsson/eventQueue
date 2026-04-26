import { LightningElement, track } from 'lwc';
import listPolicies from '@salesforce/apex/QueueAdminController.listPolicies';
import upsertPolicy from '@salesforce/apex/QueueAdminController.upsertPolicy';
import runPolicyNow from '@salesforce/apex/QueueAdminController.runPolicyNow';
import previewPolicyMatch from '@salesforce/apex/QueueAdminController.previewPolicyMatch';
import getDeploymentStatus from '@salesforce/apex/QueueAdminController.getDeploymentStatus';

const POLL_INTERVAL_MS = 2000;
const POLL_MAX_MS = 60000;
const UNKNOWN_FALLBACK_MS = 30000;

async function waitForDeploy(deployId) {
    const deadline = Date.now() + POLL_MAX_MS;
    while (Date.now() < deadline) {
        await new Promise(r => setTimeout(r, POLL_INTERVAL_MS));
        let status;
        try {
            status = await getDeploymentStatus({ deploymentId: deployId });
        } catch (e) {
            continue;
        }
        const state = status && status.state;
        if (!state) continue;
        if (state === 'Succeeded' || state === 'SucceededPartial') return status;
        if (state === 'Failed' || state === 'Canceled') return status;
        if (state === 'Unknown') {
            // Platform Cache partition not allocated — single blind wait, then refresh.
            await new Promise(r => setTimeout(r, UNKNOWN_FALLBACK_MS));
            return { state: 'Unknown', errorMessage: null };
        }
    }
    return { state: 'Timeout', errorMessage: 'Deployment did not complete within 60 seconds.' };
}

const QUEUE_STATUS_OPTIONS = [
    'DELIVERED', 'ERROR', 'QUEUED', 'SUCCESS', 'INVALID',
    'DONE', 'PROCESSING', 'UNHANDLED', 'BATCH', 'SCHEDULED'
].map(v => ({ label: v, value: v }));

const COLUMNS = [
    { label: 'Label', fieldName: 'label' },
    { label: 'DevName', fieldName: 'developerName' },
    { label: 'Status', fieldName: 'status' },
    { label: 'Days', fieldName: 'retentionDays', type: 'number', initialWidth: 80 },
    { label: 'Active', fieldName: 'isActive', type: 'boolean', initialWidth: 90 },
    { label: 'Dry Run', fieldName: 'dryRun', type: 'boolean', initialWidth: 90 },
    { label: 'Max/Run', fieldName: 'maxDeletePerRun', type: 'number', initialWidth: 110 },
    { label: 'Last Run', fieldName: 'lastRunAt', type: 'date', initialWidth: 160 },
    { label: 'Last Status', fieldName: 'lastRunStatus', initialWidth: 140 },
    {
        type: 'action',
        typeAttributes: {
            rowActions: [
                { label: 'Run now', name: 'run' },
                { label: 'Run now (dry)', name: 'run_dry' },
                { label: 'Preview matches', name: 'preview' },
                { label: 'Edit', name: 'edit' }
            ]
        }
    }
];

export default class QueueAdminRetentionPolicies extends LightningElement {
    @track policies = [];
    @track loading = false;
    @track errorMessage;
    @track showModal = false;
    @track deploying = false;
    @track deploymentMessage;
    @track previewResult;
    @track editForm = {};

    columns = COLUMNS;
    statusOptions = QUEUE_STATUS_OPTIONS;

    connectedCallback() {
        this.loadPolicies();
    }

    async loadPolicies() {
        this.loading = true;
        try {
            this.policies = await listPolicies();
            this.errorMessage = undefined;
        } catch (e) {
            this.errorMessage = (e && e.body && e.body.message) || String(e);
        } finally {
            this.loading = false;
        }
    }

    handleRowAction(event) {
        const action = event.detail.action.name;
        const row = event.detail.row;
        switch (action) {
            case 'run':     this.runPolicy(row.developerName, false); break;
            case 'run_dry': this.runPolicy(row.developerName, true);  break;
            case 'preview': this.preview(row.developerName);          break;
            case 'edit':    this.openEdit(row);                       break;
            default:
        }
    }

    handleNew() {
        this.editForm = {
            developerName:   '',
            label:           '',
            status:          'DELIVERED',
            retentionDays:   30,
            isActive:        false,
            maxDeletePerRun: 10000,
            dryRun:          true,
            notes:           ''
        };
        this.showModal = true;
    }

    openEdit(row) {
        this.editForm = Object.assign({}, row);
        this.showModal = true;
    }

    handleModalChange(event) {
        const field = event.target.dataset.field;
        if (!field) return;
        const value = event.target.type === 'checkbox' ? event.target.checked : event.target.value;
        this.editForm = Object.assign({}, this.editForm, { [field]: value });
    }

    readFormFromDom() {
        const dto = Object.assign({}, this.editForm);
        const selectors = 'lightning-input[data-field], lightning-combobox[data-field], lightning-textarea[data-field]';
        const nodes = this.template.querySelectorAll(selectors);
        console.log('[readFormFromDom] matched elements:', nodes.length);
        nodes.forEach(el => {
            const f = el.dataset.field;
            const tag = el.tagName && el.tagName.toLowerCase();
            const rawValue = el.value;
            const rawChecked = el.checked;
            const rawType = el.type;
            console.log('[readFormFromDom] field=', f, 'tag=', tag, 'type=', rawType,
                'value=', JSON.stringify(rawValue), 'checked=', rawChecked);
            if (!f) return;
            if (el.type === 'checkbox') {
                dto[f] = !!el.checked;
            } else if (el.type === 'number') {
                const n = el.value;
                dto[f] = n === '' || n === null || n === undefined ? null : Number(n);
            } else {
                const v = el.value;
                dto[f] = typeof v === 'string' ? v.trim() : v;
            }
        });
        return dto;
    }

    async handleSave() {
        console.group('[QueueAdminRetentionPolicies] handleSave');
        console.log('editForm BEFORE readFormFromDom:', JSON.parse(JSON.stringify(this.editForm || {})));
        const dto = this.readFormFromDom();
        console.log('dto AFTER readFormFromDom:', JSON.parse(JSON.stringify(dto)));
        console.log('developerName typeof=', typeof dto.developerName, 'value=', JSON.stringify(dto.developerName));
        console.log('label typeof=', typeof dto.label, 'value=', JSON.stringify(dto.label));
        console.groupEnd();
        if (!dto.developerName || !dto.label) {
            this.deploymentMessage = 'DeveloperName and Label are required. DEBUG: '
                + JSON.stringify({
                    editForm: this.editForm,
                    dtoFromDom: dto,
                    devNameType: typeof dto.developerName,
                    labelType: typeof dto.label
                });
            return;
        }
        this.editForm = dto;
        this.deploying = true;
        this.deploymentMessage = 'Deploying metadata… (10–60s — don\'t refresh)';
        // Strip any LWC ReactiveMembrane proxy wrappers before crossing the
        // @AuraEnabled boundary. `Object.assign({}, proxy)` can return something
        // whose enumerable own-props confuse the Aura serializer, arriving at
        // Apex as a DTO with null strings.
        const cleanDto = JSON.parse(JSON.stringify(dto));
        console.log('[handleSave] dto sent to Apex:', cleanDto);
        try {
            const deployId = await upsertPolicy({ dto: cleanDto });
            console.log('[handleSave] deployId returned:', deployId);
            this.deploymentMessage = 'Deploy ' + deployId
                + ' submitted. Track it in Setup → Deployment Status.';
            const result = await waitForDeploy(deployId);
            if (result.state === 'Failed' || result.state === 'Canceled') {
                this.deploymentMessage = 'Deploy ' + deployId + ' ' + result.state.toLowerCase()
                    + ': ' + (result.errorMessage || '(no detail — see Setup → Deployment Status)');
                return;
            }
            if (result.state === 'Timeout') {
                this.deploymentMessage = 'Deploy ' + deployId + ': ' + result.errorMessage
                    + ' — see Setup → Deployment Status.';
                await this.loadPolicies();
                return;
            }
            this.deploymentMessage = result.state === 'Unknown'
                ? 'Deploy ' + deployId + ' submitted (status cache not allocated — '
                    + 'confirm in Setup → Deployment Status).'
                : 'Deploy ' + deployId + ' succeeded. Refreshing…';
            await this.loadPolicies();
            this.showModal = false;
            this.deploymentMessage = undefined;
        } catch (e) {
            console.error('[handleSave] Apex error:', e);
            this.deploymentMessage = (e && e.body && e.body.message) || String(e);
        } finally {
            this.deploying = false;
        }
    }

    async runPolicy(developerName, dryRun) {
        try {
            const jobId = await runPolicyNow({ developerName, dryRun });
            this.deploymentMessage = `Batch enqueued (job ${jobId}). Watch Purge History for results.`;
        } catch (e) {
            this.deploymentMessage = (e && e.body && e.body.message) || String(e);
        }
    }

    async preview(developerName) {
        try {
            this.previewResult = undefined;
            const n = await previewPolicyMatch({ developerName });
            this.previewResult = `${developerName}: ${n} row(s) would be purged right now.`;
        } catch (e) {
            this.previewResult = (e && e.body && e.body.message) || String(e);
        }
    }

    handleCloseModal() {
        this.showModal = false;
        this.deploymentMessage = undefined;
    }
}
