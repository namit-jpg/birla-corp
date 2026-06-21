import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { autoColumns, countLabel } from 'c/epcTableUtils';
import getQualityHubData from '@salesforce/apex/QualityHubController.getQualityHubData';
import getQualityKPIs    from '@salesforce/apex/QualityHubController.getQualityKPIs';

const ITP_ACTIONS  = [{ label: 'View', name: 'view' }, { label: 'Edit', name: 'edit' }];
const IR_ACTIONS   = [{ label: 'View', name: 'view' }, { label: 'Edit', name: 'edit' }, { label: 'Raise NCR', name: 'ncr' }];
const NCR_ACTIONS  = [{ label: 'View', name: 'view' }, { label: 'Edit', name: 'edit' }, { label: 'Add CAPA', name: 'capa' }];
const CAPA_ACTIONS = [{ label: 'View', name: 'view' }, { label: 'Edit', name: 'edit' }];

export default class EpcQualityHub extends NavigationMixin(LightningElement) {
    @api recordId;

    @track itps        = [];
    @track inspections = [];
    @track ncrs        = [];
    @track capas       = [];
    @track kpis;
    @track isLoading   = true;
    @track error;
    @track filterInspStatus = 'Requested';
    @track filterNcrSev     = 'Critical';

    get itpColumns() {
        return autoColumns([
            { label: 'ITP #',       fieldName: 'itpLink', type: 'url', typeAttributes: { label: { fieldName: 'Name' }, target: '_self' } },
            { label: 'Discipline',  fieldName: 'Discipline__c', type: 'text' },
            { label: 'Status',      fieldName: 'Status__c',     type: 'text',
              cellAttributes: { class: { fieldName: 'itpStatusClass' } } },
            { label: 'H/W Points',  fieldName: 'Hold_Witness_Points__c', type: 'boolean' },
            { label: 'Actions',     type: 'action', typeAttributes: { rowActions: ITP_ACTIONS } }
        ]);
    }
    get irColumns() {
        return autoColumns([
            { label: 'IR #',        fieldName: 'irLink', type: 'url', typeAttributes: { label: { fieldName: 'Name' }, target: '_self' } },
            { label: 'Type',        fieldName: 'Type__c',           type: 'text' },
            { label: 'Area',        fieldName: 'Area__c',           type: 'text' },
            { label: 'Status',      fieldName: 'Status__c',         type: 'text',
              cellAttributes: { class: { fieldName: 'irStatusClass' } } },
            { label: 'Requested',   fieldName: 'Requested_Date__c', type: 'date' },
            { label: 'Inspected',   fieldName: 'Inspected_Date__c', type: 'date' },
            { label: 'Actions',     type: 'action', typeAttributes: { rowActions: IR_ACTIONS } }
        ]);
    }
    get ncrColumns() {
        return autoColumns([
            { label: 'NCR #',       fieldName: 'ncrLink', type: 'url', typeAttributes: { label: { fieldName: 'Name' }, target: '_self' } },
            { label: 'Severity',    fieldName: 'Severity__c',       type: 'text',
              cellAttributes: { class: { fieldName: 'ncrSevClass' } } },
            { label: 'Category',    fieldName: 'Category__c',       type: 'text' },
            { label: 'Status',      fieldName: 'Status__c',         type: 'text',
              cellAttributes: { class: { fieldName: 'ncrStatusClass' } } },
            { label: 'Identified',  fieldName: 'Identified_Date__c',type: 'date' },
            { label: 'RCA Method',  fieldName: 'RCA_Method__c',     type: 'text' },
            { label: 'Actions',     type: 'action', typeAttributes: { rowActions: NCR_ACTIONS } }
        ]);
    }
    get capaColumns() {
        return autoColumns([
            { label: 'CAPA #',      fieldName: 'capaLink', type: 'url', typeAttributes: { label: { fieldName: 'Name' }, target: '_self' } },
            { label: 'Type',        fieldName: 'Type__c',   type: 'text' },
            { label: 'Status',      fieldName: 'Status__c', type: 'text' },
            { label: 'Due Date',    fieldName: 'Due_Date__c', type: 'date' },
            { label: 'Related NCR', fieldName: 'ncrName',  type: 'text' },
            { label: 'Actions',     type: 'action', typeAttributes: { rowActions: CAPA_ACTIONS } }
        ]);
    }

    get inspStatusButtons() {
        return ['All','Requested','Accepted','Passed','Failed','Conditional'].map(s => ({
            label: s, value: s, variant: s === this.filterInspStatus ? 'brand' : 'neutral'
        }));
    }
    get ncrSevButtons() {
        return ['All','Critical','Major','Minor'].map(s => ({
            label: s, value: s, variant: s === this.filterNcrSev ? 'brand' : 'neutral'
        }));
    }

    get filteredInspections() {
        if (this.filterInspStatus === 'All') return this.inspections;
        return this.inspections.filter(i => i.Status__c === this.filterInspStatus);
    }
    get filteredNcrs() {
        if (this.filterNcrSev === 'All') return this.ncrs;
        return this.ncrs.filter(n => n.Severity__c === this.filterNcrSev);
    }

    get itpCountLabel()        { return countLabel(this.itps.length, this.itps.length, 'ITPs'); }
    get inspectionCountLabel() { return countLabel(this.filteredInspections.length, this.inspections.length, 'inspections'); }
    get ncrCountLabel()        { return countLabel(this.filteredNcrs.length, this.ncrs.length, 'NCRs'); }
    get capaCountLabel()       { return countLabel(this.capas.length, this.capas.length, 'CAPAs'); }

    /* KPI helpers */
    get passRate()      { return this.kpis ? `${this.kpis.inspectionPassRate}%` : '—'; }
    get passedCount()   { return this.kpis?.passedInspections ?? '—'; }
    get failedCount()   { return this.kpis?.failedInspections ?? '—'; }
    get openNcrCount()  { return this.kpis?.openNCRs ?? '—'; }
    get openCapaCount() { return this.kpis?.openCAPAs ?? '—'; }
    get calibAlert()    { return this.kpis?.expiredCalibrations > 0; }
    get calibCount()    { return this.kpis?.expiredCalibrations; }

    connectedCallback() { this._load(); }

    _load(showToast = false) {
        this.isLoading = true;
        Promise.all([
            getQualityHubData({ projectId: this.recordId || null }),
            getQualityKPIs({ projectId: this.recordId || null })
        ]).then(([hubData, kpiData]) => {
            this.kpis = kpiData;
            this.itps = (hubData.itps || []).map(r => ({
                ...r,
                itpLink:       `/lightning/r/Inspection_Test_Plan__c/${r.Id}/view`,
                itpStatusClass: this._itpStatusClass(r.Status__c)
            }));
            this.inspections = (hubData.inspections || []).map(r => ({
                ...r,
                irLink:       `/lightning/r/Inspection_Request__c/${r.Id}/view`,
                irStatusClass: this._irStatusClass(r.Status__c)
            }));
            this.ncrs = (hubData.ncrs || []).map(r => ({
                ...r,
                ncrLink:       `/lightning/r/NCR__c/${r.Id}/view`,
                ncrSevClass:   this._ncrSevClass(r.Severity__c),
                ncrStatusClass: this._ncrStatusClass(r.Status__c)
            }));
            this.capas = (hubData.capas || []).map(r => ({
                ...r,
                capaLink: `/lightning/r/CAPA__c/${r.Id}/view`,
                ncrName:  r.NCR__r?.Name || '—'
            }));
            this.error = null;
            if (showToast) {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Refreshed',
                    message: 'Quality hub data has been updated.',
                    variant: 'success'
                }));
            }
        }).catch(err => {
            this.error = err.body?.message || 'Failed to load quality data.';
        }).finally(() => { this.isLoading = false; });
    }

    _itpStatusClass(s)  { return { 'Active': 'q-active', 'Completed': 'q-ok', 'Draft': 'q-draft', 'Cancelled': 'q-cancelled' }[s] || ''; }
    _irStatusClass(s)   { return { 'Passed': 'q-ok', 'Failed': 'q-fail', 'Requested': 'q-pending', 'Conditional': 'q-warn', 'Accepted': 'q-pending' }[s] || ''; }
    _ncrSevClass(s)     { return { 'Critical': 'q-fail', 'Major': 'q-warn', 'Minor': 'q-draft' }[s] || ''; }
    _ncrStatusClass(s)  { return { 'Open': 'q-fail', 'In Progress': 'q-warn', 'Closed': 'q-ok' }[s] || ''; }

    handleInspFilter(event) { this.filterInspStatus = event.target.dataset.value; }
    handleNcrFilter(event)  { this.filterNcrSev = event.target.dataset.value; }
    handleRefresh()         { this._load(true); }

    handleNewITP()  { this[NavigationMixin.Navigate]({ type: 'standard__objectPage', attributes: { objectApiName: 'Inspection_Test_Plan__c', actionName: 'new' } }); }
    handleNewNCR()  { this[NavigationMixin.Navigate]({ type: 'standard__objectPage', attributes: { objectApiName: 'NCR__c', actionName: 'new' } }); }
    handleNewCAPA() { this[NavigationMixin.Navigate]({ type: 'standard__objectPage', attributes: { objectApiName: 'CAPA__c', actionName: 'new' } }); }

    handleRowAction(event) {
        const { name } = event.detail.action;
        const row = event.detail.row;
        if (name === 'view' || name === 'ncr' || name === 'capa') {
            this[NavigationMixin.Navigate]({ type: 'standard__recordPage', attributes: { recordId: row.Id, actionName: 'view' } });
        } else if (name === 'edit') {
            this[NavigationMixin.Navigate]({ type: 'standard__recordPage', attributes: { recordId: row.Id, actionName: 'edit' } });
        }
    }
}
