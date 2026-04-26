import { LightningElement, track } from 'lwc';
import listNotifierRegistrations from '@salesforce/apex/QueueAdminController.listNotifierRegistrations';
import upsertNotifierRegistration from '@salesforce/apex/QueueAdminController.upsertNotifierRegistration';
import toggleNotifierRegistration from '@salesforce/apex/QueueAdminController.toggleNotifierRegistration';
import deleteNotifierRegistration from '@salesforce/apex/QueueAdminController.deleteNotifierRegistration';

const COLUMNS = [
    { label: '#', fieldName: 'Name', initialWidth: 130 },
    { label: 'Class Name', fieldName: 'ClassName__c' },
    { label: 'Description', fieldName: 'Description__c' },
    {
        label: 'Active',
        fieldName: 'IsActive__c',
        type: 'boolean',
        initialWidth: 90
    },
    {
        type: 'action',
        typeAttributes: {
            rowActions: [
                { label: 'Toggle on/off', name: 'toggle' },
                { label: 'Delete', name: 'delete' }
            ]
        }
    }
];

export default class QueueAdminNotifiers extends LightningElement {
    @track rows = [];
    @track loading = false;
    @track errorMessage;
    @track showModal = false;
    @track editForm = {};

    columns = COLUMNS;

    connectedCallback() {
        this.load();
    }

    async load() {
        this.loading = true;
        try {
            this.rows = await listNotifierRegistrations();
            this.errorMessage = undefined;
        } catch (e) {
            this.errorMessage = (e && e.body && e.body.message) || String(e);
        } finally {
            this.loading = false;
        }
    }

    handleNew() {
        this.editForm = { ClassName__c: '', Description__c: '', IsActive__c: true };
        this.showModal = true;
    }

    handleModalChange(event) {
        const field = event.target.dataset.field;
        const value = event.target.type === 'checkbox' ? event.target.checked : event.target.value;
        this.editForm = Object.assign({}, this.editForm, { [field]: value });
    }

    async handleSave() {
        if (!this.editForm.ClassName__c) {
            this.errorMessage = 'Class name is required.';
            return;
        }
        try {
            await upsertNotifierRegistration({ registration: this.editForm });
            this.showModal = false;
            this.errorMessage = undefined;
            await this.load();
        } catch (e) {
            this.errorMessage = (e && e.body && e.body.message) || String(e);
        }
    }

    async handleRowAction(event) {
        const action = event.detail.action.name;
        const row = event.detail.row;
        try {
            if (action === 'toggle') {
                await toggleNotifierRegistration({ registrationId: row.Id, isActive: !row.IsActive__c });
            } else if (action === 'delete') {
                // eslint-disable-next-line no-alert
                if (!confirm(`Delete registration for ${row.ClassName__c}?`)) return;
                await deleteNotifierRegistration({ registrationId: row.Id });
            }
            await this.load();
        } catch (e) {
            this.errorMessage = (e && e.body && e.body.message) || String(e);
        }
    }

    handleCloseModal() {
        this.showModal = false;
    }
}
