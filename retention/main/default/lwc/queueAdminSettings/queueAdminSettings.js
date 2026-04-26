import { LightningElement, track } from 'lwc';
import getAllSettings from '@salesforce/apex/QueueAdminController.getAllSettings';
import upsertQueueAdminSetting from '@salesforce/apex/QueueAdminController.upsertQueueAdminSetting';
import abortJob from '@salesforce/apex/QueueAdminController.abortJob';

export default class QueueAdminSettings extends LightningElement {
    @track loading = false;
    @track errorMessage;
    @track savedMessage;
    @track queueAdmin = {};

    connectedCallback() {
        this.load();
    }

    async load() {
        this.loading = true;
        try {
            const settings = await getAllSettings();
            this.queueAdmin = Object.assign({}, settings.queueAdmin || {});
            this.errorMessage = undefined;
        } catch (e) {
            this.errorMessage = (e && e.body && e.body.message) || String(e);
        } finally {
            this.loading = false;
        }
    }

    handleQueueAdminChange(event) {
        const field = event.target.dataset.field;
        const value = event.target.type === 'checkbox' ? event.target.checked : event.target.value;
        this.queueAdmin = Object.assign({}, this.queueAdmin, { [field]: value });
    }

    async saveQueueAdmin() {
        this.savedMessage = undefined;
        try {
            await upsertQueueAdminSetting({ setting: this.queueAdmin });
            this.savedMessage = 'Queue Admin settings saved.';
            await this.load();
        } catch (e) {
            this.errorMessage = (e && e.body && e.body.message) || String(e);
        }
    }

    async abortAllJobs() {
        try {
            await abortJob({ className: 'JobQueueRetention' });
            await abortJob({ className: 'JobPendingEvents' });
            await abortJob({ className: 'JobOldQueuedEvents' });
            await abortJob({ className: 'JobRetryEventProcessor' });
            this.savedMessage = 'All jobs aborted.';
        } catch (e) {
            this.errorMessage = (e && e.body && e.body.message) || String(e);
        }
    }
}
