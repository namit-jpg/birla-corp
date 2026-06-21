import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { autoColumns, countLabel } from 'c/epcTableUtils';
import getHseHubData from '@salesforce/apex/HseHubController.getHseHubData';
import getHseKPIs    from '@salesforce/apex/HseHubController.getHseKPIs';
import closePermit   from '@salesforce/apex/HseHubController.closePermit';

const ROW_ACTIONS = [{ label: 'View', name: 'view' }, { label: 'Edit', name: 'edit' }];
const PERMIT_ACTIONS  = [...ROW_ACTIONS, { label: 'Close Permit', name: 'close' }];
const PERMIT_STATUS_ORDER = { Active: 0, Approved: 1, Draft: 2, Expired: 3, Closed: 4 };

export default class EpcHseHub extends NavigationMixin(LightningElement) {
    @api recordId;
    @api projectId;

    @track permits         = [];
    @track observations    = [];
    @track incidents       = [];
    @track toolboxTalks    = [];
    @track hiras           = [];
    @track safetyAudits    = [];
    @track auditFindings   = [];
    @track emergencyPlans  = [];
    @track ohsCompliance   = [];
    @track kpis;
    @track isLoading       = true;
    @track error;
    @track filterObsRisk   = 'All';
    @track filterIncSev    = 'All';

    get permitColumns() {
        return autoColumns([
            { label: 'Permit #',   fieldName: 'permitLink', type: 'url', typeAttributes: { label: { fieldName: 'Name' }, target: '_self' } },
            { label: 'Type',       fieldName: 'Permit_Type__c', type: 'text' },
            { label: 'Status',     fieldName: 'Status__c',      type: 'text',
              cellAttributes: { class: { fieldName: 'permitStatusClass' } } },
            { label: 'Area',       fieldName: 'Area__c',        type: 'text' },
            { label: 'Valid From', fieldName: 'Valid_From__c',  type: 'date' },
            { label: 'Valid To',   fieldName: 'Valid_To__c',    type: 'date' },
            { label: 'Actions',    type: 'action', typeAttributes: { rowActions: PERMIT_ACTIONS } }
        ]);
    }
    get obsColumns() {
        return autoColumns([
            { label: 'Obs #',      fieldName: 'obsLink', type: 'url', typeAttributes: { label: { fieldName: 'Name' }, target: '_self' } },
            { label: 'Type',       fieldName: 'Observation_Type__c', type: 'text' },
            { label: 'Risk Level', fieldName: 'Risk_Level__c',       type: 'text',
              cellAttributes: { class: { fieldName: 'obsRiskClass' } } },
            { label: 'Status',     fieldName: 'Status__c',           type: 'text' },
            { label: 'Date',       fieldName: 'Observation_Date__c', type: 'date' },
            { label: 'Actions',    type: 'action', typeAttributes: { rowActions: ROW_ACTIONS } }
        ]);
    }
    get incidentColumns() {
        return autoColumns([
            { label: 'Incident #', fieldName: 'incLink', type: 'url', typeAttributes: { label: { fieldName: 'Name' }, target: '_self' } },
            { label: 'Type',       fieldName: 'Incident_Type__c', type: 'text' },
            { label: 'Severity',   fieldName: 'Severity__c',      type: 'text',
              cellAttributes: { class: { fieldName: 'incSevClass' } } },
            { label: 'Near Miss',  fieldName: 'Is_Near_Miss__c',  type: 'boolean' },
            { label: 'Status',     fieldName: 'Status__c',        type: 'text' },
            { label: 'Date',       fieldName: 'Incident_Date__c', type: 'date' },
            { label: 'Actions',    type: 'action', typeAttributes: { rowActions: ROW_ACTIONS } }
        ]);
    }
    get tbtColumns() {
        return autoColumns([
            { label: 'TBT #',      fieldName: 'tbtLink', type: 'url', typeAttributes: { label: { fieldName: 'Name' }, target: '_self' } },
            { label: 'Topic',      fieldName: 'Topic__c',          type: 'text' },
            { label: 'Date',       fieldName: 'Talk_Date__c',      type: 'date' },
            { label: 'Attendance', fieldName: 'Attendance_Count__c', type: 'number' },
            { label: 'Actions',    type: 'action', typeAttributes: { rowActions: ROW_ACTIONS } }
        ]);
    }
    get hiraColumns() {
        return autoColumns([
            { label: 'HIRA #',     fieldName: 'hiraLink', type: 'url', typeAttributes: { label: { fieldName: 'Name' }, target: '_self' } },
            { label: 'Activity',   fieldName: 'Activity__c',    type: 'text' },
            { label: 'Hazard',     fieldName: 'Hazard__c',      type: 'text' },
            { label: 'Risk',       fieldName: 'Risk_Rating__c', type: 'text',
              cellAttributes: { class: { fieldName: 'hiraRiskClass' } } },
            { label: 'Residual',   fieldName: 'Residual_Risk__c', type: 'text' },
            { label: 'Status',     fieldName: 'Status__c',      type: 'text' },
            { label: 'Actions',    type: 'action', typeAttributes: { rowActions: ROW_ACTIONS } }
        ]);
    }
    get auditColumns() {
        return autoColumns([
            { label: 'Audit #',    fieldName: 'auditLink', type: 'url', typeAttributes: { label: { fieldName: 'Name' }, target: '_self' } },
            { label: 'Date',       fieldName: 'Audit_Date__c', type: 'date' },
            { label: 'Auditor',    fieldName: 'Auditor__c',    type: 'text' },
            { label: 'Score',      fieldName: 'Score__c',      type: 'number' },
            { label: 'Status',     fieldName: 'Status__c',     type: 'text' },
            { label: 'Actions',    type: 'action', typeAttributes: { rowActions: ROW_ACTIONS } }
        ]);
    }
    get findingColumns() {
        return autoColumns([
            { label: 'Finding #',  fieldName: 'findingLink', type: 'url', typeAttributes: { label: { fieldName: 'Name' }, target: '_self' } },
            { label: 'Category',   fieldName: 'Category__c',       type: 'text' },
            { label: 'Severity',   fieldName: 'Severity__c',       type: 'text',
              cellAttributes: { class: { fieldName: 'findingSevClass' } } },
            { label: 'Status',     fieldName: 'Finding_Status__c', type: 'text' },
            { label: 'Audit',      fieldName: 'auditName',         type: 'text' },
            { label: 'Actions',    type: 'action', typeAttributes: { rowActions: ROW_ACTIONS } }
        ]);
    }
    get emergencyColumns() {
        return autoColumns([
            { label: 'Plan #',     fieldName: 'planLink', type: 'url', typeAttributes: { label: { fieldName: 'Name' }, target: '_self' } },
            { label: 'Scenario',   fieldName: 'Scenario__c',     type: 'text' },
            { label: 'Status',     fieldName: 'Plan_Status__c',  type: 'text' },
            { label: 'Drill Date', fieldName: 'Drill_Date__c',   type: 'date' },
            { label: 'Actions',    type: 'action', typeAttributes: { rowActions: ROW_ACTIONS } }
        ]);
    }
    get ohsColumns() {
        return autoColumns([
            { label: 'Item #',     fieldName: 'ohsLink', type: 'url', typeAttributes: { label: { fieldName: 'Name' }, target: '_self' } },
            { label: 'Requirement',fieldName: 'Requirement__c',      type: 'text' },
            { label: 'Status',     fieldName: 'Compliance_Status__c', type: 'text',
              cellAttributes: { class: { fieldName: 'ohsStatusClass' } } },
            { label: 'Actions',    type: 'action', typeAttributes: { rowActions: ROW_ACTIONS } }
        ]);
    }

    get obsRiskButtons() {
        return ['All','High','Medium','Low'].map(r => ({
            label: r, value: r, variant: r === this.filterObsRisk ? 'brand' : 'neutral'
        }));
    }
    get incSevButtons() {
        return ['All','Fatality','LTI','Medical','First Aid','Near Miss'].map(s => ({
            label: s, value: s, variant: s === this.filterIncSev ? 'brand' : 'neutral'
        }));
    }

    get sortedPermits() {
        return [...this.permits].sort((a, b) =>
            (PERMIT_STATUS_ORDER[a.Status__c] ?? 99) - (PERMIT_STATUS_ORDER[b.Status__c] ?? 99)
        );
    }
    get openPermitCount() { return this.permits.filter(p => p.Status__c === 'Active').length; }
    get permitsTabLabel() { return `Permits to Work (${this.openPermitCount})`; }

    get filteredObs() {
        if (this.filterObsRisk === 'All') return this.observations;
        return this.observations.filter(o => o.Risk_Level__c === this.filterObsRisk);
    }
    get filteredInc() {
        if (this.filterIncSev === 'All') return this.incidents;
        return this.incidents.filter(i => i.Severity__c === this.filterIncSev);
    }

    get permitCountLabel()   { return countLabel(this.sortedPermits.length, this.permits.length, 'permits'); }
    get obsCountLabel()      { return countLabel(this.filteredObs.length, this.observations.length, 'observations'); }
    get incidentCountLabel() { return countLabel(this.filteredInc.length, this.incidents.length, 'incidents'); }
    get tbtCountLabel()      { return countLabel(this.toolboxTalks.length, this.toolboxTalks.length, 'toolbox talks'); }
    get hiraCountLabel()     { return countLabel(this.hiras.length, this.hiras.length, 'HIRAs'); }
    get auditCountLabel()    { return countLabel(this.safetyAudits.length, this.safetyAudits.length, 'audits'); }
    get findingCountLabel()  { return countLabel(this.auditFindings.length, this.auditFindings.length, 'findings'); }
    get emergencyCountLabel(){ return countLabel(this.emergencyPlans.length, this.emergencyPlans.length, 'plans'); }
    get ohsCountLabel()      { return countLabel(this.ohsCompliance.length, this.ohsCompliance.length, 'items'); }

    get activePermits()  { return this.kpis?.activePermits ?? '—'; }
    get highRiskObs()    { return this.kpis?.openHighObservations ?? '—'; }
    get openIncidents()  { return this.kpis?.openIncidents ?? '—'; }
    get nearMisses()     { return this.kpis?.nearMisses ?? '—'; }
    get tbtAttendees()   { return this.kpis?.totalTbtAttendees ?? '—'; }

    connectedCallback() { this._load(); }

    _load() {
        this.isLoading = true;
        return Promise.all([
            getHseHubData({ projectId: this.recordId || this.projectId || null }),
            getHseKPIs({ projectId: this.recordId || this.projectId || null })
        ]).then(([hubData, kpiData]) => {
            this.kpis = kpiData;
            this.permits = (hubData.permits || []).map(r => ({
                ...r,
                permitLink: `/lightning/r/Permit_to_Work__c/${r.Id}/view`,
                permitStatusClass: this._permitStatusClass(r.Status__c)
            }));
            this.observations = (hubData.observations || []).map(r => ({
                ...r,
                obsLink: `/lightning/r/Observation__c/${r.Id}/view`,
                obsRiskClass: this._riskClass(r.Risk_Level__c)
            }));
            this.incidents = (hubData.incidents || []).map(r => ({
                ...r,
                incLink: `/lightning/r/Incident__c/${r.Id}/view`,
                incSevClass: this._sevClass(r.Severity__c)
            }));
            this.toolboxTalks = (hubData.toolboxTalks || []).map(r => ({
                ...r,
                tbtLink: `/lightning/r/Toolbox_Talk__c/${r.Id}/view`
            }));
            this.hiras = (hubData.hiras || []).map(r => ({
                ...r,
                hiraLink: `/lightning/r/HIRA__c/${r.Id}/view`,
                hiraRiskClass: this._riskClass(r.Risk_Rating__c)
            }));
            this.safetyAudits = (hubData.safetyAudits || []).map(r => ({
                ...r,
                auditLink: `/lightning/r/Safety_Audit__c/${r.Id}/view`
            }));
            this.auditFindings = (hubData.auditFindings || []).map(r => ({
                ...r,
                findingLink: `/lightning/r/Audit_Finding__c/${r.Id}/view`,
                auditName: r.Safety_Audit__r?.Name || '—',
                findingSevClass: this._sevClass(r.Severity__c)
            }));
            this.emergencyPlans = (hubData.emergencyPlans || []).map(r => ({
                ...r,
                planLink: `/lightning/r/Emergency_Plan__c/${r.Id}/view`
            }));
            this.ohsCompliance = (hubData.ohsCompliance || []).map(r => ({
                ...r,
                ohsLink: `/lightning/r/OHS_Compliance_Item__c/${r.Id}/view`,
                ohsStatusClass: r.Compliance_Status__c === 'Compliant' ? 'hse-ok' : 'hse-warn'
            }));
            this.error = null;
        }).catch(err => {
            this.error = err.body?.message || 'Failed to load HSE data.';
        }).finally(() => { this.isLoading = false; });
    }

    _permitStatusClass(s) { return { Active: 'hse-active', Closed: 'hse-closed', Expired: 'hse-danger' }[s] || ''; }
    _riskClass(r)         { return { High: 'hse-danger', Medium: 'hse-warn', Low: 'hse-ok' }[r] || ''; }
    _sevClass(s)          { return { Fatality: 'hse-danger', LTI: 'hse-danger', Medical: 'hse-warn', 'First Aid': 'hse-warn', Critical: 'hse-danger', Major: 'hse-warn' }[s] || ''; }

    _toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    handleObsFilter(event) { this.filterObsRisk = event.target.dataset.value; }
    handleIncFilter(event) { this.filterIncSev  = event.target.dataset.value; }
    handleRefresh() {
        this._load().then(() => {
            if (!this.error) this._toast('Refreshed', 'HSE data updated.', 'success');
        });
    }

    handleNewPermit()   { this._navNew('Permit_to_Work__c'); }
    handleNewObs()      { this._navNew('Observation__c'); }
    handleNewIncident() { this._navNew('Incident__c'); }
    handleNewTbt()      { this._navNew('Toolbox_Talk__c'); }
    handleNewHira()     { this._navNew('HIRA__c'); }
    handleNewAudit()    { this._navNew('Safety_Audit__c'); }
    handleNewFinding()  { this._navNew('Audit_Finding__c'); }
    handleNewPlan()     { this._navNew('Emergency_Plan__c'); }
    handleNewOhs()      { this._navNew('OHS_Compliance_Item__c'); }

    _navNew(objectApiName) {
        this[NavigationMixin.Navigate]({ type: 'standard__objectPage', attributes: { objectApiName, actionName: 'new' } });
    }

    async handleRowAction(event) {
        const { name } = event.detail.action;
        const row = event.detail.row;
        if (name === 'close') {
            const prev = [...this.permits];
            this.permits = this.permits.map(p =>
                p.Id === row.Id
                    ? { ...p, Status__c: 'Closed', permitStatusClass: this._permitStatusClass('Closed') }
                    : p
            );
            try {
                await closePermit({ permitId: row.Id });
                this._toast('Success', 'Permit closed.', 'success');
            } catch (err) {
                this.permits = prev;
                this._toast('Error', err.body?.message || 'Failed to close permit.', 'error');
            }
        } else if (name === 'view' || name === 'edit') {
            this[NavigationMixin.Navigate]({ type: 'standard__recordPage', attributes: { recordId: row.Id, actionName: name } });
        }
    }
}
