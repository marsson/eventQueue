import { LightningElement, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getOverview from '@salesforce/apex/QueueAdminController.getOverview';

export default class QueueAdminOverview extends LightningElement {
    @track overview;
    @track loading = false;
    @track errorMessage;

    connectedCallback() {
        this.loadOverview();
    }

    async loadOverview() {
        this.loading = true;
        this.errorMessage = undefined;
        try {
            this.overview = await getOverview();
        } catch (e) {
            this.errorMessage = (e && e.body && e.body.message) || String(e);
        } finally {
            this.loading = false;
        }
    }

    handleRefresh() {
        this.loadOverview();
    }

    get enabledBadgeVariant() {
        return this.overview && this.overview.retentionEnabled ? 'success' : 'inverse';
    }

    get enabledLabel() {
        return this.overview && this.overview.retentionEnabled ? 'Retention ENABLED' : 'Retention DISABLED';
    }

    get dryRunBadgeVariant() {
        return this.overview && this.overview.globalDryRun ? 'warning' : 'inverse';
    }

    get dryRunLabel() {
        return this.overview && this.overview.globalDryRun ? 'GLOBAL DRY RUN' : 'Live mode';
    }

    get hasStatusBreakdown() {
        return this.overview && this.overview.statusBreakdown && this.overview.statusBreakdown.length > 0;
    }
}
