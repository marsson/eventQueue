import { LightningElement, track } from 'lwc';
import getScheduleStatus from '@salesforce/apex/QueueAdminController.getScheduleStatus';
import startJob from '@salesforce/apex/QueueAdminController.startJob';
import abortJob from '@salesforce/apex/QueueAdminController.abortJob';

export default class QueueAdminScheduling extends LightningElement {
    @track jobs = [];
    @track loading = false;
    @track errorMessage;
    @track customCron = '';

    connectedCallback() {
        this.load();
    }

    async load() {
        this.loading = true;
        try {
            this.jobs = await getScheduleStatus();
            this.errorMessage = undefined;
        } catch (e) {
            this.errorMessage = (e && e.body && e.body.message) || String(e);
        } finally {
            this.loading = false;
        }
    }

    handleCronChange(event) {
        this.customCron = event.target.value;
    }

    async handleStart(event) {
        const className = event.target.dataset.className;
        try {
            await startJob({ className, cronExpression: this.customCron || null });
            await this.load();
        } catch (e) {
            this.errorMessage = (e && e.body && e.body.message) || String(e);
        }
    }

    async handleAbort(event) {
        const className = event.target.dataset.className;
        try {
            await abortJob({ className });
            await this.load();
        } catch (e) {
            this.errorMessage = (e && e.body && e.body.message) || String(e);
        }
    }
}
