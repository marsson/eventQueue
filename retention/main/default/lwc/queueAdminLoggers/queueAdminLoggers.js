import { LightningElement, track } from 'lwc';
import listLoggerRegistrations from '@salesforce/apex/QueueAdminController.listLoggerRegistrations';
import upsertLoggerRegistration from '@salesforce/apex/QueueAdminController.upsertLoggerRegistration';
import toggleLoggerRegistration from '@salesforce/apex/QueueAdminController.toggleLoggerRegistration';
import deleteLoggerRegistration from '@salesforce/apex/QueueAdminController.deleteLoggerRegistration';

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

export default class QueueAdminLoggers extends LightningElement {
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
            this.rows = await listLoggerRegistrations();
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

    handleRegisterDefault() {
        this.editForm = {
            ClassName__c: 'DebugLogger',
            Description__c: 'Default debug logger — writes to System.debug with level prefix.',
            IsActive__c: true
        };
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
            await upsertLoggerRegistration({ registration: this.editForm });
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
                await toggleLoggerRegistration({ registrationId: row.Id, isActive: !row.IsActive__c });
            } else if (action === 'delete') {
                // eslint-disable-next-line no-alert
                if (!confirm(`Delete registration for ${row.ClassName__c}?`)) return;
                await deleteLoggerRegistration({ registrationId: row.Id });
            }
            await this.load();
        } catch (e) {
            this.errorMessage = (e && e.body && e.body.message) || String(e);
        }
    }

    handleCloseModal() {
        this.showModal = false;
    }

    get showEmptyStateBanner() {
        return !this.loading && this.rows.length === 0;
    }
}
