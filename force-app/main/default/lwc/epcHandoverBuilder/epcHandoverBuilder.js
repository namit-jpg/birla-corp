import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { autoColumns, countLabel } from 'c/epcTableUtils';
import getHandoverData from '@salesforce/apex/HandoverController.getHandoverData';
import getHandoverKPIs from '@salesforce/apex/HandoverController.getHandoverKPIs';
import getFinalAcceptances from '@salesforce/apex/HandoverController.getFinalAcceptances';

const CAT_FILTERS    = ['All', 'A', 'B', 'C'];
const STATUS_FILTERS = ['All', 'Open', 'In Progress', 'Closed'];

const PKG_ACTIONS   = [{ label: 'View', name: 'view' }, { label: 'Edit', name: 'edit' }];
const PUNCH_ACTIONS = [{ label: 'View', name: 'view' }, { label: 'Edit', name: 'edit' }, { label: 'Close Punch', name: 'close' }];
const TRAIN_ACTIONS = [{ label: 'View', name: 'view' }, { label: 'Edit', name: 'edit' }];
const FAC_ACTIONS   = [{ label: 'View', name: 'view' }, { label: 'Edit', name: 'edit' }];

export default class EpcHandoverBuilder extends NavigationMixin(LightningElement) {
    @api recordId;
    @api projectId;

    @track packages        = [];
    @track punchItems      = [];
    @track trainingRecords = [];
    @track facRecords      = [];
    @track kpis;
    @track isLoading       = true;
    @track error;

    @track catFilter         = 'All';
    @track punchStatusFilter = 'All';

    get resolvedPid() { return this.recordId || this.projectId || null; }

    get catFilterButtons() {
        return CAT_FILTERS.map(v => ({ label: v === 'All' ? 'All Cat' : `Cat-${v}`, value: v,
            cls: v === this.catFilter ? 'filter-btn filter-btn-active' : 'filter-btn' }));
    }
    get statusFilterButtons() {
        return STATUS_FILTERS.map(v => ({ label: v, value: v,
            cls: v === this.punchStatusFilter ? 'filter-btn filter-btn-active' : 'filter-btn' }));
    }

    get filteredPunchItems() {
        let r = this.punchItems;
        if (this.catFilter !== 'All')         r = r.filter(p => p.Category__c === this.catFilter);
        if (this.punchStatusFilter !== 'All') r = r.filter(p => p.Punch_Status__c === this.punchStatusFilter);
        return r;
    }

    get punchClosureRate() {
        if (!this.kpis?.totalPunch) return 0;
        return Math.round(((this.kpis.closedPunch || 0) / this.kpis.totalPunch) * 100);
    }
    get catAClass()  { return (this.kpis?.openCatA || 0) > 0 ? 'kpi-card kpi-danger' : 'kpi-card kpi-ok'; }
    get pkgsClass()  { return (this.kpis?.packagesReadyOrAccepted || 0) > 0 ? 'kpi-card kpi-ok' : 'kpi-card'; }

    get packageColumns() {
        return autoColumns([
            { label: 'Package #', fieldName: 'pkgLink', type: 'url', typeAttributes: { label: { fieldName: 'Name' }, target: '_self' }, initialWidth: 140 },
            { label: 'Code',      fieldName: 'Package_Code__c',         type: 'text', initialWidth: 100 },
            { label: 'Status',    fieldName: 'Package_Status__c',       type: 'text', initialWidth: 150,
              cellAttributes: { class: { fieldName: 'pkgStatusClass' } } },
            { label: 'Client Acceptance', fieldName: 'Client_Acceptance_Date__c', type: 'date', initialWidth: 140 },
            { label: 'Actions', type: 'action', typeAttributes: { rowActions: PKG_ACTIONS } }
        ]);
    }
    get punchColumns() {
        return autoColumns([
            { label: 'Punch #',   fieldName: 'punchLink', type: 'url', typeAttributes: { label: { fieldName: 'Name' }, target: '_self' }, initialWidth: 120 },
            { label: 'Category',  fieldName: 'Category__c',     type: 'text', initialWidth: 90,
              cellAttributes: { class: { fieldName: 'catClass' } } },
            { label: 'Priority',  fieldName: 'Priority__c',     type: 'text', initialWidth: 90 },
            { label: 'Status',    fieldName: 'Punch_Status__c', type: 'text', initialWidth: 110,
              cellAttributes: { class: { fieldName: 'punchStatusClass' } } },
            { label: 'Description', fieldName: 'Description__c', type: 'text', initialWidth: 200 },
            { label: 'Due Date',  fieldName: 'Due_Date__c',     type: 'date', initialWidth: 110 },
            { label: 'Actions', type: 'action', typeAttributes: { rowActions: PUNCH_ACTIONS } }
        ]);
    }
    get trainingColumns() {
        return autoColumns([
            { label: 'Record #', fieldName: 'trainLink', type: 'url', typeAttributes: { label: { fieldName: 'Name' }, target: '_self' }, initialWidth: 120 },
            { label: 'Topic',    fieldName: 'Topic__c',           type: 'text',    initialWidth: 200 },
            { label: 'Date',     fieldName: 'Training_Date__c',   type: 'date',    initialWidth: 110 },
            { label: 'Status',   fieldName: 'Training_Status__c', type: 'text',    initialWidth: 120,
              cellAttributes: { class: { fieldName: 'trainStatusClass' } } },
            { label: 'Competency Verified', fieldName: 'Competency_Verified__c', type: 'boolean', initialWidth: 140 },
            { label: 'Actions', type: 'action', typeAttributes: { rowActions: TRAIN_ACTIONS } }
        ]);
    }
    get facColumns() {
        return autoColumns([
            { label: 'FAC #',        fieldName: 'facLink', type: 'url', typeAttributes: { label: { fieldName: 'Name' }, target: '_self' }, initialWidth: 120 },
            { label: 'Status',       fieldName: 'FAC_Status__c',    type: 'text', initialWidth: 140,
              cellAttributes: { class: { fieldName: 'facStatusClass' } } },
            { label: 'Accepted By',  fieldName: 'Accepted_By__c',  type: 'text', initialWidth: 160 },
            { label: 'Accepted Date',fieldName: 'Accepted_Date__c', type: 'date', initialWidth: 120 },
            { label: 'Actions', type: 'action', typeAttributes: { rowActions: FAC_ACTIONS } }
        ]);
    }

    get hasPackages()        { return this.packages.length > 0; }
    get hasFilteredPunch()   { return this.filteredPunchItems.length > 0; }
    get hasTraining()        { return this.trainingRecords.length > 0; }
    get hasFacRecords()      { return this.facRecords.length > 0; }
    get packageCountLabel()  { return countLabel(this.packages.length, this.packages.length, 'packages'); }
    get punchCountLabel()  { return countLabel(this.filteredPunchItems.length, this.punchItems.length, 'punch items'); }
    get trainingCountLabel() { return countLabel(this.trainingRecords.length, this.trainingRecords.length, 'training records'); }
    get facCountLabel()    { return countLabel(this.facRecords.length, this.facRecords.length, 'FAC records'); }

    connectedCallback() { this._load(false); }

    _load(refresh = false) {
        this.isLoading = true;
        Promise.all([
            getHandoverData({ projectId: this.resolvedPid }),
            getHandoverKPIs({ projectId: this.resolvedPid }),
            getFinalAcceptances({ projectId: this.resolvedPid })
        ]).then(([handover, kpiData, fac]) => {
            this.kpis = kpiData;
            this.packages = (handover.packages || []).map(r => ({
                ...r,
                pkgLink:       `/lightning/r/Handover_Package__c/${r.Id}/view`,
                pkgStatusClass: this._pkgStatusClass(r.Package_Status__c)
            }));
            this.punchItems = (handover.punchItems || []).map(r => ({
                ...r,
                punchLink:      `/lightning/r/Punch_List_Item__c/${r.Id}/view`,
                catClass:        this._catClass(r.Category__c),
                punchStatusClass: this._punchStatusClass(r.Punch_Status__c)
            }));
            this.trainingRecords = (handover.trainingRecords || []).map(r => ({
                ...r,
                trainLink:      `/lightning/r/Training_Record__c/${r.Id}/view`,
                trainStatusClass: this._trainStatusClass(r.Training_Status__c)
            }));
            this.facRecords = (fac || []).map(r => ({
                ...r,
                facLink:       `/lightning/r/Final_Acceptance__c/${r.Id}/view`,
                facStatusClass: this._facStatusClass(r.FAC_Status__c)
            }));
            this.error = null;
        }).catch(err => {
            this.error = err.body?.message || 'Failed to load handover data.';
        }).finally(() => {
            this.isLoading = false;
            if (refresh && !this.error) {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Refreshed',
                    message: 'Handover data updated.',
                    variant: 'success'
                }));
            }
        });
    }

    _pkgStatusClass(s) {
        return { 'Accepted': 'hb-accepted', 'Ready for Client': 'hb-ready', 'In Progress': 'hb-inprogress', 'Draft': 'hb-draft' }[s] || '';
    }
    _catClass(c) { return { 'A': 'hb-cat-a', 'B': 'hb-cat-b', 'C': 'hb-cat-c' }[c] || ''; }
    _punchStatusClass(s) { return { 'Closed': 'hb-closed', 'In Progress': 'hb-inprogress', 'Open': 'hb-open' }[s] || ''; }
    _trainStatusClass(s) { return { 'Completed': 'hb-accepted', 'In Progress': 'hb-inprogress', 'Planned': 'hb-draft' }[s] || ''; }
    _facStatusClass(s)   { return { 'Accepted': 'hb-accepted', 'Pending': 'hb-inprogress', 'Rejected': 'hb-cat-a' }[s] || ''; }

    handleCatFilter(event)    { this.catFilter = event.target.dataset.value; }
    handleStatusFilter(event) { this.punchStatusFilter = event.target.dataset.value; }
    handleRefresh()           { this._load(true); }

    handleNewPackage()  { this[NavigationMixin.Navigate]({ type: 'standard__objectPage', attributes: { objectApiName: 'Handover_Package__c', actionName: 'new' } }); }
    handleNewPunch()    { this[NavigationMixin.Navigate]({ type: 'standard__objectPage', attributes: { objectApiName: 'Punch_List_Item__c',  actionName: 'new' } }); }
    handleNewTraining() { this[NavigationMixin.Navigate]({ type: 'standard__objectPage', attributes: { objectApiName: 'Training_Record__c',   actionName: 'new' } }); }

    handleRowAction(event) {
        const { name } = event.detail.action;
        const row = event.detail.row;
        if (name === 'view' || name === 'close') {
            this[NavigationMixin.Navigate]({ type: 'standard__recordPage', attributes: { recordId: row.Id, actionName: 'view' } });
        } else if (name === 'edit') {
            this[NavigationMixin.Navigate]({ type: 'standard__recordPage', attributes: { recordId: row.Id, actionName: 'edit' } });
        }
    }
}
