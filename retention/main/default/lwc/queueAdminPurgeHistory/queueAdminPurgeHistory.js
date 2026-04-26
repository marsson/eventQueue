import { LightningElement, track } from 'lwc';
import listPurgeLogs from '@salesforce/apex/QueueAdminController.listPurgeLogs';

const COLUMNS = [
    { label: '#', fieldName: 'Name', initialWidth: 140 },
    { label: 'Started', fieldName: 'RunStartedAt__c', type: 'date' },
    { label: 'Policy', fieldName: 'PolicyLabel__c' },
    { label: 'Status', fieldName: 'Status__c' },
    { label: 'Deleted', fieldName: 'RecordsDeleted__c', type: 'number' },
    { label: 'Skipped', fieldName: 'RecordsSkipped__c', type: 'number' },
    { label: 'Duration (s)', fieldName: 'DurationSeconds__c', type: 'number' },
    { label: 'Triggered By', fieldName: 'TriggeredBy__c' },
    { label: 'Strategy', fieldName: 'DeleteStrategy__c' }
];

const STATUS_OPTIONS = [
    { label: 'All', value: '' },
    { label: 'SUCCESS', value: 'SUCCESS' },
    { label: 'PARTIAL', value: 'PARTIAL' },
    { label: 'ERROR', value: 'ERROR' },
    { label: 'DRY_RUN', value: 'DRY_RUN' },
    { label: 'SKIPPED_GLOBAL_CAP', value: 'SKIPPED_GLOBAL_CAP' }
];

export default class QueueAdminPurgeHistory extends LightningElement {
    @track logs = [];
    @track loading = false;
    @track errorMessage;
    @track statusFilter = '';

    columns = COLUMNS;
    statusOptions = STATUS_OPTIONS;

    connectedCallback() {
        this.load();
    }

    async load() {
        this.loading = true;
        try {
            this.logs = await listPurgeLogs({ statusFilter: this.statusFilter || null, limitTo: 200 });
            this.errorMessage = undefined;
        } catch (e) {
            this.errorMessage = (e && e.body && e.body.message) || String(e);
        } finally {
            this.loading = false;
        }
    }

    handleFilterChange(event) {
        this.statusFilter = event.detail.value;
        this.load();
    }
}
