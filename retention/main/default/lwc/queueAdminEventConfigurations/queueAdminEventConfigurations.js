import { LightningElement, track } from 'lwc';
import listEventConfigurations from '@salesforce/apex/QueueAdminController.listEventConfigurations';
import upsertEventConfiguration from '@salesforce/apex/QueueAdminController.upsertEventConfiguration';
import getDeploymentStatus from '@salesforce/apex/QueueAdminController.getDeploymentStatus';

const POLL_INTERVAL_MS = 2000;
const POLL_MAX_MS = 60000;
const UNKNOWN_FALLBACK_MS = 30000;

const unwrap = (obj) => JSON.parse(JSON.stringify(obj));

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
            await new Promise(r => setTimeout(r, UNKNOWN_FALLBACK_MS));
            return { state: 'Unknown', errorMessage: null };
        }
    }
    return { state: 'Timeout', errorMessage: 'Deployment did not complete within 60 seconds.' };
}

const METHOD_OPTIONS = [
    { label: 'POST',   value: 'POST' },
    { label: 'GET',    value: 'GET' },
    { label: 'DELETE', value: 'DELETE' },
    { label: 'SOAP',   value: 'SOAP' }
];

const COLUMNS = [
    { label: 'Label', fieldName: 'label' },
    { label: 'DevName', fieldName: 'developerName' },
    { label: 'Command Class', fieldName: 'commandClassName' },
    { label: 'Method', fieldName: 'method', initialWidth: 100 },
    { label: 'Named Credential', fieldName: 'namedCredential' },
    { label: 'Disabled', fieldName: 'disableDispatcher', type: 'boolean', initialWidth: 100 },
    {
        type: 'action',
        typeAttributes: { rowActions: [{ label: 'Edit', name: 'edit' }] }
    }
];

export default class QueueAdminEventConfigurations extends LightningElement {
    @track rows = [];
    @track loading = false;
    @track errorMessage;
    @track showModal = false;
    @track deploying = false;
    @track deploymentMessage;
    @track editForm = {};

    columns = COLUMNS;
    methodOptions = METHOD_OPTIONS;

    connectedCallback() {
        this.load();
    }

    async load() {
        this.loading = true;
        try {
            this.rows = await listEventConfigurations();
            this.errorMessage = undefined;
        } catch (e) {
            this.errorMessage = (e && e.body && e.body.message) || String(e);
        } finally {
            this.loading = false;
        }
    }

    handleRowAction(event) {
        const row = event.detail.row;
        this.editForm = Object.assign({}, row);
        this.showModal = true;
    }

    handleNew() {
        this.editForm = {
            developerName: '',
            label: '',
            commandClassName: '',
            method: 'POST',
            namedCredential: '',
            disableDispatcher: false
        };
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
            } else {
                const v = el.value;
                dto[f] = typeof v === 'string' ? v.trim() : v;
            }
        });
        return dto;
    }

    async handleSave() {
        console.group('[QueueAdminEventConfigurations] handleSave');
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
        console.error("HERE");
        console.log(unwrap(dto));
        console.log(unwrap(cleanDto));
        try {
            const deployId = await upsertEventConfiguration({ dto: cleanDto });
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
                await this.load();
                return;
            }
            this.deploymentMessage = result.state === 'Unknown'
                ? 'Deploy ' + deployId + ' submitted (status cache not allocated — '
                    + 'confirm in Setup → Deployment Status).'
                : 'Deploy ' + deployId + ' succeeded. Refreshing…';
            await this.load();
            this.showModal = false;
            this.deploymentMessage = undefined;
        } catch (e) {
            console.error('[handleSave] Apex error:', e);
            this.deploymentMessage = (e && e.body && e.body.message) || String(e);
        } finally {
            this.deploying = false;
        }
    }

    handleCloseModal() {
        this.showModal = false;
        this.deploymentMessage = undefined;
    }
}
