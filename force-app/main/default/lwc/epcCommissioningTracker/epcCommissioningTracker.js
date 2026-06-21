import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { autoColumns, countLabel } from 'c/epcTableUtils';
import getHandoverData from '@salesforce/apex/HandoverController.getHandoverData';
import getCommissioningProcedures from '@salesforce/apex/HandoverController.getCommissioningProcedures';

const STAGES = [
    'Mechanical Completion', 'E&I Completion', 'Pre-Commissioning',
    'No-Load Trial', 'Load Trial', 'Cold Commissioning',
    'Hot Commissioning', 'Performance Test'
];

const COMP_ACTIONS = [
    { label: 'View',     name: 'view'     },
    { label: 'Edit',     name: 'edit'     },
    { label: 'Sign Off', name: 'sign_off' }
];
const PROC_ACTIONS = [
    { label: 'View', name: 'view' },
    { label: 'Edit', name: 'edit' }
];

export default class EpcCommissioningTracker extends NavigationMixin(LightningElement) {
    @api recordId;
    @api projectId;

    @track completions  = [];
    @track procedures   = [];
    @track isLoading    = true;
    @track error;
    @track stageFilter  = 'All';

    get resolvedPid() { return this.recordId || this.projectId || null; }

    get stageFilterButtons() {
        return [{ label: 'All', value: 'All' }, ...STAGES.map(s => ({ label: s, value: s }))]
            .map(b => ({ ...b, cls: b.value === this.stageFilter ? 'filter-btn filter-btn-active' : 'filter-btn' }));
    }

    get filteredCompletions() {
        if (this.stageFilter === 'All') return this.completions;
        return this.completions.filter(c => c.Stage__c === this.stageFilter);
    }

    get stageSummary() {
        return STAGES.map(stage => {
            const items    = this.completions.filter(c => c.Stage__c === stage);
            const total    = items.length;
            const complete = items.filter(c => c.Completion_Status__c === 'Complete' || c.Completion_Status__c === 'Signed Off').length;
            const pct      = total > 0 ? Math.round((complete / total) * 100) : 0;
            const allDone  = total > 0 && complete === total;
            return { name: stage, total, complete, pct, allDone,
                     cardClass: allDone ? 'stage-card stage-card-done' : (pct > 0 ? 'stage-card stage-card-active' : 'stage-card') };
        }).filter(s => s.total > 0);
    }

    /* KPIs */
    get totalCompletions()  { return this.completions.length; }
    get signedOffCount()    { return this.completions.filter(c => c.Completion_Status__c === 'Signed Off').length; }
    get inProgressCount()   { return this.completions.filter(c => c.Completion_Status__c === 'In Progress').length; }
    get totalProcedures()   { return this.procedures.length; }

    get completionColumns() {
        return autoColumns([
            { label: 'Completion #', fieldName: 'compLink', type: 'url', typeAttributes: { label: { fieldName: 'Name' }, target: '_self' }, initialWidth: 140 },
            { label: 'System',       fieldName: 'System__c',            type: 'text', initialWidth: 140 },
            { label: 'Stage',        fieldName: 'Stage__c',             type: 'text', initialWidth: 160 },
            { label: 'Status',       fieldName: 'Completion_Status__c', type: 'text', initialWidth: 120,
              cellAttributes: { class: { fieldName: 'statusClass' } } },
            { label: 'Target Date',  fieldName: 'Target_Date__c',       type: 'date', initialWidth: 110 },
            { label: 'Actual Date',  fieldName: 'Actual_Date__c',       type: 'date', initialWidth: 110 },
            { label: 'Actions',      type: 'action', typeAttributes: { rowActions: COMP_ACTIONS } }
        ]);
    }

    get procedureColumns() {
        return autoColumns([
            { label: 'Procedure #',  fieldName: 'procLink', type: 'url', typeAttributes: { label: { fieldName: 'Name' }, target: '_self' }, initialWidth: 140 },
            { label: 'System',       fieldName: 'Proc_System__c',  type: 'text',   initialWidth: 140 },
            { label: 'Status',       fieldName: 'Proc_Status__c',  type: 'text',   initialWidth: 120,
              cellAttributes: { class: { fieldName: 'procStatusClass' } } },
            { label: 'Steps Done',   fieldName: 'Steps_Complete__c', type: 'number', initialWidth: 110 },
            { label: 'Total Steps',  fieldName: 'Steps_Total__c',    type: 'number', initialWidth: 110 },
            { label: 'Actions',      type: 'action', typeAttributes: { rowActions: PROC_ACTIONS } }
        ]);
    }

    get hasFilteredCompletions() { return this.filteredCompletions.length > 0; }
    get hasProcedures()          { return this.procedures.length > 0; }
    get completionCountLabel()   { return countLabel(this.filteredCompletions.length, this.completions.length, 'completions'); }
    get procedureCountLabel()    { return countLabel(this.procedures.length, this.procedures.length, 'procedures'); }

    connectedCallback() { this._load(false); }

    _load(refresh = false) {
        this.isLoading = true;
        Promise.all([
            getHandoverData({ projectId: this.resolvedPid }),
            getCommissioningProcedures({ projectId: this.resolvedPid })
        ]).then(([handover, procs]) => {
            this.completions = (handover.completions || []).map(r => ({
                ...r,
                compLink:    `/lightning/r/Completion__c/${r.Id}/view`,
                statusClass: this._statusClass(r.Completion_Status__c)
            }));
            this.procedures = (procs || []).map(r => ({
                ...r,
                procLink:        `/lightning/r/Commissioning_Procedure__c/${r.Id}/view`,
                procStatusClass: this._procStatusClass(r.Proc_Status__c)
            }));
            this.error = null;
        }).catch(err => {
            this.error = err.body?.message || 'Failed to load commissioning data.';
        }).finally(() => {
            this.isLoading = false;
            if (refresh && !this.error) {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Refreshed',
                    message: `${this.completions.length} completions and ${this.procedures.length} procedures loaded.`,
                    variant: 'success'
                }));
            }
        });
    }

    _statusClass(s) {
        return { 'Signed Off': 'ct-signed-off', 'Complete': 'ct-complete', 'In Progress': 'ct-inprogress', 'Not Started': 'ct-notstarted' }[s] || '';
    }
    _procStatusClass(s) {
        return { 'Completed': 'ct-signed-off', 'In Progress': 'ct-inprogress', 'Pending': 'ct-notstarted' }[s] || '';
    }

    handleStageFilter(event) {
        this.stageFilter = event.target.dataset.value;
    }
    handleRefresh() { this._load(true); }
    handleNewCompletion() {
        this[NavigationMixin.Navigate]({ type: 'standard__objectPage', attributes: { objectApiName: 'Completion__c', actionName: 'new' } });
    }

    handleRowAction(event) {
        const { name } = event.detail.action;
        const row = event.detail.row;
        if (name === 'view' || name === 'sign_off') {
            this[NavigationMixin.Navigate]({ type: 'standard__recordPage', attributes: { recordId: row.Id, actionName: 'view' } });
        } else if (name === 'edit') {
            this[NavigationMixin.Navigate]({ type: 'standard__recordPage', attributes: { recordId: row.Id, actionName: 'edit' } });
        }
    }
}
