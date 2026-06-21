import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { autoColumns, countLabel } from 'c/epcTableUtils';
import getHseHubData from '@salesforce/apex/HseHubController.getHseHubData';
import getHseKPIs    from '@salesforce/apex/HseHubController.getHseKPIs';

const INC_ACTIONS = [{ label: 'View', name: 'view' }, { label: 'Edit', name: 'edit' }];
const OBS_ACTIONS = [{ label: 'View', name: 'view' }, { label: 'Edit', name: 'edit' }];

export default class EpcSafetyDashboard extends NavigationMixin(LightningElement) {
    @api recordId;
    @api projectId;
    @api totalManHours = 100000;

    @track kpis;
    @track incidents     = [];
    @track observations  = [];
    @track isLoading     = true;
    @track error;
    @track filterIncStatus = 'Open';

    get resolvedPid() { return this.recordId || this.projectId || null; }

    get incColumns() {
        return autoColumns([
            { label: 'Incident #', fieldName: 'incLink', type: 'url', typeAttributes: { label: { fieldName: 'Name' }, target: '_self' } },
            { label: 'Type',       fieldName: 'Incident_Type__c', type: 'text' },
            { label: 'Severity',   fieldName: 'Severity__c',      type: 'text',
              cellAttributes: { class: { fieldName: 'sevClass' } } },
            { label: 'Near Miss',  fieldName: 'Is_Near_Miss__c',  type: 'boolean' },
            { label: 'Status',     fieldName: 'Status__c',        type: 'text' },
            { label: 'Date',       fieldName: 'Incident_Date__c', type: 'date' },
            { label: 'Actions',    type: 'action', typeAttributes: { rowActions: INC_ACTIONS } }
        ]);
    }
    get obsColumns() {
        return autoColumns([
            { label: 'Obs #',      fieldName: 'obsLink', type: 'url', typeAttributes: { label: { fieldName: 'Name' }, target: '_self' } },
            { label: 'Type',       fieldName: 'Observation_Type__c', type: 'text' },
            { label: 'Risk Level', fieldName: 'Risk_Level__c',       type: 'text',
              cellAttributes: { class: { fieldName: 'riskClass' } } },
            { label: 'Status',     fieldName: 'Status__c',           type: 'text' },
            { label: 'Date',       fieldName: 'Observation_Date__c', type: 'date' },
            { label: 'Actions',    type: 'action', typeAttributes: { rowActions: OBS_ACTIONS } }
        ]);
    }

    get incStatusButtons() {
        return ['Open', 'All'].map(s => ({
            label: s, value: s, variant: s === this.filterIncStatus ? 'brand' : 'neutral'
        }));
    }

    get filteredIncidents() {
        if (this.filterIncStatus === 'All') return this.incidents;
        return this.incidents.filter(i => i.Status__c !== 'Closed');
    }

    get incidentCountLabel()  { return countLabel(this.filteredIncidents.length, this.incidents.length, 'incidents'); }
    get observationCountLabel(){ return countLabel(this.observations.length, this.observations.length, 'observations'); }

    /* KPIs */
    get trirValue() {
        if (!this.kpis || !this.totalManHours) return 'N/A';
        return ((( this.kpis.openIncidents || 0) * 200000) / this.totalManHours).toFixed(2);
    }
    get trirClass()      { const t = parseFloat(this.trirValue); return t === 0 ? 'kpi-value sd-ok' : t <= 1 ? 'kpi-value sd-warn' : 'kpi-value sd-fail'; }
    get nearMisses()     { return this.kpis?.nearMisses ?? '—'; }
    get activePermits()  { return this.kpis?.activePermits ?? '—'; }
    get highRiskObs()    { return this.kpis?.openHighObservations ?? '—'; }
    get openIncidents()  { return this.kpis?.openIncidents ?? '—'; }
    get tbtAttendees()   { return this.kpis?.totalTbtAttendees ?? '—'; }

    connectedCallback() { this._load(); }

    _load() {
        this.isLoading = true;
        return Promise.all([
            getHseHubData({ projectId: this.resolvedPid }),
            getHseKPIs({ projectId: this.resolvedPid })
        ]).then(([hubData, kpiData]) => {
            this.kpis = kpiData;
            this.incidents = (hubData.incidents || []).map(r => ({
                ...r,
                incLink:  `/lightning/r/Incident__c/${r.Id}/view`,
                sevClass: this._sevClass(r.Severity__c)
            }));
            this.observations = (hubData.observations || []).map(r => ({
                ...r,
                obsLink:   `/lightning/r/Observation__c/${r.Id}/view`,
                riskClass: this._riskClass(r.Risk_Level__c)
            }));
            this.error = null;
        }).catch(err => {
            this.error = err.body?.message || 'Failed to load safety data.';
        }).finally(() => { this.isLoading = false; });
    }

    _sevClass(s)  { return { 'Fatality': 'sd-fail', 'LTI': 'sd-fail', 'Medical': 'sd-warn', 'First Aid': 'sd-warn' }[s] || ''; }
    _riskClass(r) { return { 'High': 'sd-fail', 'Medium': 'sd-warn', 'Low': 'sd-ok' }[r] || ''; }

    _toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    handleIncStatusFilter(event) { this.filterIncStatus = event.target.dataset.value; }
    handleRefresh() {
        this._load().then(() => {
            if (!this.error) this._toast('Refreshed', 'Safety data updated.', 'success');
        });
    }
    handleNewIncident() { this[NavigationMixin.Navigate]({ type: 'standard__objectPage', attributes: { objectApiName: 'Incident__c', actionName: 'new' } }); }
    handleNewObs()      { this[NavigationMixin.Navigate]({ type: 'standard__objectPage', attributes: { objectApiName: 'Observation__c', actionName: 'new' } }); }

    handleRowAction(event) {
        const { name } = event.detail.action;
        const row = event.detail.row;
        if (name === 'view') {
            this[NavigationMixin.Navigate]({ type: 'standard__recordPage', attributes: { recordId: row.Id, actionName: 'view' } });
        } else if (name === 'edit') {
            this[NavigationMixin.Navigate]({ type: 'standard__recordPage', attributes: { recordId: row.Id, actionName: 'edit' } });
        }
    }
}
