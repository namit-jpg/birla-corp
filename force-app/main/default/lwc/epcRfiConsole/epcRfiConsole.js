import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { autoColumns, countLabel } from 'c/epcTableUtils';
import getRfis from '@salesforce/apex/EpcRfiConsoleController.getRfis';

const RFI_ACTIONS = [
    { label: 'View Details', name: 'view' },
    { label: 'Edit',         name: 'edit' },
    { label: 'Close RFI',   name: 'close' }
];

const COLUMNS = [
    { label: 'RFI #',    fieldName: 'rfiLink', type: 'url',
      typeAttributes: { label: { fieldName: 'Name' }, target: '_self' }, initialWidth: 120 },
    { label: 'Subject',  fieldName: 'Subject__c',   type: 'text', initialWidth: 200,
      cellAttributes: { class: { fieldName: 'overdueClass' } } },
    { label: 'Status',   fieldName: 'Status__c',    type: 'text', initialWidth: 120,
      cellAttributes: { class: { fieldName: 'statusClass' } } },
    { label: 'Priority', fieldName: 'Priority__c',  type: 'text', initialWidth: 100,
      cellAttributes: { class: { fieldName: 'priorityClass' } } },
    { label: 'Discipline', fieldName: 'Discipline__c', type: 'text', initialWidth: 130 },
    { label: 'Days Open', fieldName: 'Days_Open__c', type: 'number', initialWidth: 100,
      cellAttributes: { class: { fieldName: 'daysClass' }, alignment: 'left' } },
    { label: 'Due Date', fieldName: 'Due_Date__c',  type: 'date', initialWidth: 120,
      cellAttributes: { class: { fieldName: 'dueDateClass' } } },
    { label: 'Actions',  type: 'action', typeAttributes: { rowActions: RFI_ACTIONS } }
];

export default class EpcRfiConsole extends NavigationMixin(LightningElement) {
    @api recordId;

    @track allRfis    = [];
    @track isLoading  = true;
    @track error;
    @track filterStatus = 'Open';

    columns = autoColumns(COLUMNS);

    filterButtons = [
        { label: 'All',          value: 'all' },
        { label: 'Open',         value: 'Open' },
        { label: 'Under Review', value: 'Under Review' },
        { label: 'Overdue',      value: 'overdue' },
        { label: 'Answered',     value: 'Answered' },
        { label: 'Closed',       value: 'Closed' }
    ];

    get today() { return new Date().toISOString().split('T')[0]; }

    connectedCallback() { this._load(false); }

    get hasFilteredData() { return this.filteredRfis.length > 0; }
    get countLabelText()  { return countLabel(this.filteredRfis.length, this.allRfis.length, 'RFIs'); }

    _load(refresh = false) {
        this.isLoading = true;
        getRfis({ projectId: this.recordId || null })
            .then(data => {
                this.allRfis = data.map(r => {
                    const overdue = r.Due_Date__c && r.Due_Date__c < this.today
                        && r.Status__c !== 'Closed' && r.Status__c !== 'Answered';
                    return {
                        ...r,
                        rfiLink:      `/lightning/r/RFI__c/${r.Id}/view`,
                        overdueClass: overdue ? 'rfi-overdue' : '',
                        statusClass:  this._statusClass(r.Status__c),
                        priorityClass: this._priorityClass(r.Priority__c),
                        daysClass:    overdue ? 'rfi-overdue' : '',
                        dueDateClass: overdue ? 'rfi-overdue' : '',
                        _overdue: overdue
                    };
                });
                this.error = null;
            })
            .catch(err => { this.error = err.body?.message || 'Failed to load RFIs.'; })
            .finally(() => {
                this.isLoading = false;
                if (refresh && !this.error) {
                    this.dispatchEvent(new ShowToastEvent({
                        title: 'Refreshed',
                        message: `${this.allRfis.length} RFIs loaded.`,
                        variant: 'success'
                    }));
                }
            });
    }

    _statusClass(s) {
        return { 'Open': 'rfi-status-open', 'Under Review': 'rfi-status-review',
                 'Answered': 'rfi-status-answered', 'Closed': 'rfi-status-closed',
                 'Draft': 'rfi-status-draft' }[s] || '';
    }

    _priorityClass(p) {
        return { 'High': 'rfi-priority-high', 'Medium': 'rfi-priority-medium',
                 'Low': 'rfi-priority-low' }[p] || '';
    }

    get filteredRfis() {
        if (this.filterStatus === 'all')     return this.allRfis;
        if (this.filterStatus === 'overdue') return this.allRfis.filter(r => r._overdue);
        return this.allRfis.filter(r => r.Status__c === this.filterStatus);
    }

    get filterButtonsWithVariant() {
        return this.filterButtons.map(b => ({
            ...b,
            variant: b.value === this.filterStatus ? 'brand' : 'neutral'
        }));
    }

    /* KPIs */
    get openCount()     { return this.allRfis.filter(r => r.Status__c === 'Open' || r.Status__c === 'Under Review').length; }
    get answeredCount() { return this.allRfis.filter(r => r.Status__c === 'Answered').length; }
    get overdueCount()  { return this.allRfis.filter(r => r._overdue).length; }
    get closedCount()   { return this.allRfis.filter(r => r.Status__c === 'Closed').length; }

    handleFilter(event) { this.filterStatus = event.target.dataset.value; }
    handleRefresh()     { this._load(true); }
    handleNewRFI()      { this[NavigationMixin.Navigate]({ type: 'standard__objectPage', attributes: { objectApiName: 'RFI__c', actionName: 'new' } }); }

    handleRowAction(event) {
        const { name } = event.detail.action;
        const row = event.detail.row;
        if (name === 'view') {
            this[NavigationMixin.Navigate]({ type: 'standard__recordPage', attributes: { recordId: row.Id, actionName: 'view' } });
        } else if (name === 'edit') {
            this[NavigationMixin.Navigate]({ type: 'standard__recordPage', attributes: { recordId: row.Id, actionName: 'edit' } });
        } else if (name === 'close') {
            this.dispatchEvent(new ShowToastEvent({ title: 'Close RFI', message: 'Open the record to update the status to Closed.', variant: 'info' }));
            this[NavigationMixin.Navigate]({ type: 'standard__recordPage', attributes: { recordId: row.Id, actionName: 'edit' } });
        }
    }
}
