import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { autoColumns, countLabel } from 'c/epcTableUtils';
import getConstructionBoardData from '@salesforce/apex/ConstructionBoardController.getConstructionBoardData';
import getDefaultProjectId from '@salesforce/apex/ConstructionBoardController.getDefaultProjectId';

const NCR_ACTIONS = [
    { label: 'View Details', name: 'view' },
    { label: 'Edit',         name: 'edit' },
    { label: 'Close NCR',    name: 'close' }
];
const DPR_ACTIONS = [
    { label: 'View Details', name: 'view' },
    { label: 'Edit',         name: 'edit' }
];

const NCR_COLUMNS = [
    { label: 'NCR #',        fieldName: 'link',            type: 'url',  typeAttributes: { label: { fieldName: 'Name' }, target: '_self' }, initialWidth: 120 },
    { label: 'Severity',     fieldName: 'Severity__c',     type: 'text', initialWidth: 100,
      cellAttributes: { class: { fieldName: 'sevClass' } } },
    { label: 'Category',     fieldName: 'Category__c',     type: 'text', initialWidth: 130 },
    { label: 'Status',       fieldName: 'Status__c',       type: 'text', initialWidth: 110,
      cellAttributes: { class: { fieldName: 'statusClass' } } },
    { label: 'Identified',   fieldName: 'Identified_Date__c', type: 'date', initialWidth: 110 },
    { label: 'Target Close', fieldName: 'Closed_Date__c',  type: 'date', initialWidth: 110 },
    { label: 'Vendor',       fieldName: 'vendorName',      type: 'text' },
    { label: 'Actions',      type: 'action', typeAttributes: { rowActions: NCR_ACTIONS } }
];

const DPR_COLUMNS = [
    { label: 'DPR #',         fieldName: 'link',             type: 'url',    typeAttributes: { label: { fieldName: 'Name' }, target: '_self' }, initialWidth: 120 },
    { label: 'Date',          fieldName: 'Date__c',          type: 'date',   initialWidth: 110 },
    { label: 'Work Package',  fieldName: 'wpName',           type: 'text',   initialWidth: 160 },
    { label: 'Qty Installed', fieldName: 'Qty_Installed__c', type: 'number', initialWidth: 110 },
    { label: 'Planned Qty',   fieldName: 'Planned_Quantity__c', type: 'number', initialWidth: 110 },
    { label: 'Hours',         fieldName: 'Hours_Worked__c',  type: 'number', initialWidth: 80 },
    { label: 'Crew',          fieldName: 'Crew_Size__c',     type: 'number', initialWidth: 70 },
    { label: 'Safety Inc.',   fieldName: 'Safety_Incidents__c', type: 'number', initialWidth: 90,
      cellAttributes: { class: { fieldName: 'safetyClass' } } },
    { label: 'Actions',       type: 'action', typeAttributes: { rowActions: DPR_ACTIONS } }
];

const SEV_CLASS = { Critical: 'badge-critical', High: 'badge-high', Medium: 'badge-medium', Low: 'badge-low' };
const STATUS_CLASS = { Closed: 'badge-closed', Open: 'badge-open', 'In Progress': 'badge-inprogress' };

export default class EpcSiteExecutionBoard extends NavigationMixin(LightningElement) {
    @api recordId;
    @track projectId;
    @track ncrs = [];
    @track workFronts = [];
    @track recentProgress = [];
    @track filterStatus = 'open';
    @track isLoading = true;
    @track error;

    ncrColumns = autoColumns(NCR_COLUMNS);
    dprColumns = autoColumns(DPR_COLUMNS);

    ncrFilterButtons = [
        { label: 'Open', value: 'open' },
        { label: 'All',  value: 'all'  }
    ];

    connectedCallback() {
        const pid = this.recordId || null;
        if (pid) {
            this.projectId = pid;
            this.loadData();
        } else {
            getDefaultProjectId()
                .then(id => { this.projectId = id; this.loadData(); })
                .catch(err => { this.error = err.body?.message || 'Cannot load project.'; this.isLoading = false; });
        }
    }

    loadData(showToast = false) {
        this.isLoading = true;
        this.error = null;
        return getConstructionBoardData({ projectId: this.projectId })
            .then(result => {
                this.ncrs = (result.ncrs || []).map(n => ({
                    ...n,
                    link:        `/lightning/r/NCR__c/${n.Id}/view`,
                    sevClass:    'badge ' + (SEV_CLASS[n.Severity__c] || ''),
                    statusClass: 'badge ' + (STATUS_CLASS[n.Status__c] || ''),
                    vendorName:  n.Vendor__r?.Name || '—'
                }));
                this.workFronts = (result.workFronts || []).map(wf => ({
                    ...wf,
                    link:       `/lightning/r/Work_Front__c/${wf.Id}/view`,
                    statusClass: wf.Readiness_Status__c === 'Blocked'  ? 'front-card front-blocked'
                                : wf.Readiness_Status__c === 'Released' ? 'front-card front-released'
                                : 'front-card front-ready',
                    statusBadge: wf.Readiness_Status__c === 'Blocked'  ? 'slds-badge slds-theme_error'
                                : wf.Readiness_Status__c === 'Released' ? 'slds-badge slds-theme_success'
                                : 'slds-badge',
                    wpName:     wf.Work_Package__r?.Name || '—'
                }));
                this.recentProgress = (result.recentProgress || []).map(dp => ({
                    ...dp,
                    link:        `/lightning/r/Daily_Progress__c/${dp.Id}/view`,
                    wpName:      dp.Work_Package__r?.Name || '—',
                    safetyClass: dp.Safety_Incidents__c > 0 ? 'safety-alert' : ''
                }));
                if (showToast) {
                    this.dispatchEvent(new ShowToastEvent({
                        title: 'Refreshed',
                        message: 'Board data updated.',
                        variant: 'success'
                    }));
                }
            })
            .catch(err => { this.error = err.body?.message || 'Error loading board data.'; })
            .finally(() => { this.isLoading = false; });
    }

    get filteredNcrs() {
        if (this.filterStatus === 'open') {
            return this.ncrs.filter(n => n.Status__c !== 'Closed');
        }
        return this.ncrs;
    }

    get ncrCountLabel() {
        return countLabel(this.filteredNcrs.length, this.ncrs.length, 'NCRs');
    }

    get dprCountLabel() {
        return countLabel(this.recentProgress.length, this.recentProgress.length, 'records');
    }

    get hasNcrData() { return this.ncrs.length > 0; }
    get hasNcrMatches() { return this.filteredNcrs.length > 0; }
    get hasWorkFrontData() { return this.workFronts.length > 0; }
    get hasDprData() { return this.recentProgress.length > 0; }

    get ncrFilterButtonsWithState() {
        return this.ncrFilterButtons.map(b => ({
            ...b,
            variant: b.value === this.filterStatus ? 'brand' : 'neutral'
        }));
    }

    /* KPI getters */
    get openNcrCount()     { return this.ncrs.filter(n => n.Status__c !== 'Closed').length; }
    get criticalNcrCount() { return this.ncrs.filter(n => n.Severity__c === 'Critical' && n.Status__c !== 'Closed').length; }
    get blockedFronts()    { return this.workFronts.filter(w => w.Readiness_Status__c === 'Blocked').length; }
    get releasedFronts()   { return this.workFronts.filter(w => w.Readiness_Status__c === 'Released').length; }
    get todaySafetyInc()   { return this.recentProgress.reduce((s, d) => s + (d.Safety_Incidents__c || 0), 0); }

    get criticalKpiClass() { return this.criticalNcrCount > 0 ? 'kpi-card kpi-error' : 'kpi-card'; }
    get blockedKpiClass()  { return this.blockedFronts > 0    ? 'kpi-card kpi-warning' : 'kpi-card'; }
    get safetyKpiClass()   { return this.todaySafetyInc > 0   ? 'kpi-card kpi-error' : 'kpi-card'; }

    /* Actions */
    handleNcrFilter(event) {
        this.filterStatus = event.target.dataset.value;
    }

    handleNewNCR() {
        this[NavigationMixin.Navigate]({ type: 'standard__objectPage', attributes: { objectApiName: 'NCR__c', actionName: 'new' } });
    }
    handleNewDPR() {
        this[NavigationMixin.Navigate]({ type: 'standard__objectPage', attributes: { objectApiName: 'Daily_Progress__c', actionName: 'new' } });
    }
    handleNewWorkFront() {
        this[NavigationMixin.Navigate]({ type: 'standard__objectPage', attributes: { objectApiName: 'Work_Front__c', actionName: 'new' } });
    }
    handleRefresh() {
        this.loadData(true);
    }

    handleNcrAction(event) {
        const action = event.detail.action.name;
        const row = event.detail.row;
        if (action === 'view' || action === 'close') {
            this[NavigationMixin.Navigate]({ type: 'standard__recordPage', attributes: { recordId: row.Id, actionName: action === 'close' ? 'edit' : 'view' } });
        } else if (action === 'edit') {
            this[NavigationMixin.Navigate]({ type: 'standard__recordPage', attributes: { recordId: row.Id, actionName: 'edit' } });
        }
    }
    handleDprAction(event) {
        const action = event.detail.action.name;
        const row = event.detail.row;
        this[NavigationMixin.Navigate]({ type: 'standard__recordPage', attributes: { recordId: row.Id, actionName: action === 'edit' ? 'edit' : 'view' } });
    }
    handleFrontClick(event) {
        const id = event.currentTarget.dataset.id;
        this[NavigationMixin.Navigate]({ type: 'standard__recordPage', attributes: { recordId: id, actionName: 'view' } });
    }
}
