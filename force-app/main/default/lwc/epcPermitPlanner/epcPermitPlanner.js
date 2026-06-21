import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { autoColumns, countLabel } from 'c/epcTableUtils';
import getHseHubData      from '@salesforce/apex/HseHubController.getHseHubData';
import getExpiringPermits from '@salesforce/apex/HseHubController.getExpiringPermits';
import closePermit          from '@salesforce/apex/HseHubController.closePermit';

const ACTIONS = [
    { label: 'View',         name: 'view'    },
    { label: 'Edit',         name: 'edit'    },
    { label: 'Close Permit', name: 'close'   }
];

const STATUSES = ['All','Draft','Approved','Active','Expired','Closed'];
const TYPES    = ['All','Hot Work','Confined Space','Work at Height','Excavation','Electrical'];

export default class EpcPermitPlanner extends NavigationMixin(LightningElement) {
    @api recordId;
    @api projectId;

    @track allPermits      = [];
    @track expiringPermits = [];
    @track isLoading       = true;
    @track error;
    @track filterStatus    = 'Active';
    @track filterType      = 'All';

    get resolvedPid() { return this.recordId || this.projectId || null; }

    get columns() {
        return autoColumns([
            { label: 'Permit #',   fieldName: 'permitLink', type: 'url',
              typeAttributes: { label: { fieldName: 'Name' }, target: '_self' } },
            { label: 'Type',       fieldName: 'Permit_Type__c', type: 'text' },
            { label: 'Status',     fieldName: 'Status__c',      type: 'text',
              cellAttributes: { class: { fieldName: 'statusClass' } } },
            { label: 'Area',       fieldName: 'Area__c',        type: 'text' },
            { label: 'Valid From', fieldName: 'Valid_From__c',  type: 'date',
              typeAttributes: { year: 'numeric', month: 'short', day: '2-digit' } },
            { label: 'Valid To',   fieldName: 'Valid_To__c',    type: 'date',
              typeAttributes: { year: 'numeric', month: 'short', day: '2-digit' },
              cellAttributes: { class: { fieldName: 'expiryClass' } } },
            { label: 'Actions',    type: 'action', typeAttributes: { rowActions: ACTIONS } }
        ]);
    }

    get expiringColumns() {
        return autoColumns([
            { label: 'Permit #', fieldName: 'permitLink', type: 'url',
              typeAttributes: { label: { fieldName: 'Name' }, target: '_self' } },
            { label: 'Type',     fieldName: 'Permit_Type__c', type: 'text' },
            { label: 'Status',   fieldName: 'Status__c',      type: 'text',
              cellAttributes: { class: { fieldName: 'statusClass' } } },
            { label: 'Area',     fieldName: 'Area__c',        type: 'text' },
            { label: 'Valid To', fieldName: 'Valid_To__c',    type: 'date',
              typeAttributes: { year: 'numeric', month: 'short', day: '2-digit' },
              cellAttributes: { class: { fieldName: 'expiryClass' } } }
        ]);
    }

    get statusButtons() {
        return STATUSES.map(s => ({ label: s, value: s, variant: s === this.filterStatus ? 'brand' : 'neutral' }));
    }
    get typeButtons() {
        return TYPES.map(t => ({ label: t, value: t, variant: t === this.filterType ? 'brand' : 'neutral' }));
    }

    get filteredPermits() {
        return this.allPermits.filter(p => {
            const sOk = this.filterStatus === 'All' || p.Status__c === this.filterStatus;
            const tOk = this.filterType   === 'All' || p.Permit_Type__c === this.filterType;
            return sOk && tOk;
        });
    }

    get permitCountLabel() { return countLabel(this.filteredPermits.length, this.allPermits.length, 'permits'); }

    /* KPIs */
    get activeCount()   { return this.allPermits.filter(p => p.Status__c === 'Active').length; }
    get pendingCount()  { return this.allPermits.filter(p => p.Status__c === 'Draft' || p.Status__c === 'Approved').length; }
    get expiredCount()  { return this.allPermits.filter(p => p.Status__c === 'Expired').length; }
    get expiringCount() { return this.expiringPermits.length; }

    connectedCallback() { this._load(); }

    _mapPermit(p) {
        return {
            ...p,
            permitLink:  `/lightning/r/Permit_to_Work__c/${p.Id}/view`,
            statusClass: this._statusClass(p.Status__c),
            expiryClass: p.Status__c === 'Expired' ? 'ptw-expired' : ''
        };
    }

    _load() {
        this.isLoading = true;
        return Promise.all([
            getHseHubData({ projectId: this.resolvedPid }),
            getExpiringPermits({ projectId: this.resolvedPid })
        ]).then(([hubData, expiring]) => {
            this.allPermits = (hubData.permits || []).map(p => this._mapPermit(p));
            this.expiringPermits = (expiring || []).map(p => this._mapPermit(p));
            this.error = null;
        }).catch(err => {
            this.error = err.body?.message || 'Failed to load permits.';
        }).finally(() => { this.isLoading = false; });
    }

    _statusClass(s) {
        return { 'Active': 'ptw-active', 'Draft': 'ptw-draft', 'Approved': 'ptw-approved',
                 'Expired': 'ptw-expired', 'Closed': 'ptw-closed' }[s] || '';
    }

    _toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    handleStatusFilter(event) { this.filterStatus = event.target.dataset.value; }
    handleTypeFilter(event)   { this.filterType   = event.target.dataset.value; }
    handleRefresh() {
        this._load().then(() => {
            if (!this.error) this._toast('Refreshed', 'Permit data updated.', 'success');
        });
    }
    handleNewPermit() { this[NavigationMixin.Navigate]({ type: 'standard__objectPage', attributes: { objectApiName: 'Permit_to_Work__c', actionName: 'new' } }); }

    async handleRowAction(event) {
        const { name } = event.detail.action;
        const row = event.detail.row;
        if (name === 'close') {
            const prevAll = [...this.allPermits];
            const prevExp = [...this.expiringPermits];
            const closed = { ...row, Status__c: 'Closed', statusClass: this._statusClass('Closed') };
            this.allPermits = this.allPermits.map(p => p.Id === row.Id ? closed : p);
            this.expiringPermits = this.expiringPermits.filter(p => p.Id !== row.Id);
            try {
                await closePermit({ permitId: row.Id });
                this._toast('Success', 'Permit closed.', 'success');
            } catch (err) {
                this.allPermits = prevAll;
                this.expiringPermits = prevExp;
                this._toast('Error', err.body?.message || 'Failed to close permit.', 'error');
            }
        } else if (name === 'view') {
            this[NavigationMixin.Navigate]({ type: 'standard__recordPage', attributes: { recordId: row.Id, actionName: 'view' } });
        } else if (name === 'edit') {
            this[NavigationMixin.Navigate]({ type: 'standard__recordPage', attributes: { recordId: row.Id, actionName: 'edit' } });
        }
    }
}
