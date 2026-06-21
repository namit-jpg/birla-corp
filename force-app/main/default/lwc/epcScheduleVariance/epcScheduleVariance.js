import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { autoColumns, countLabel } from 'c/epcTableUtils';
import getWBSItems from '@salesforce/apex/EpcGanttController.getWBSItems';

const ROW_ACTIONS = [{ label: 'View', name: 'view' }];

const COLUMNS = [
    { label: 'Code',       fieldName: 'wbsLink', type: 'url',
      typeAttributes: { label: { fieldName: 'Code__c' }, target: '_self' }, initialWidth: 100 },
    { label: 'Name',       fieldName: 'Name',                    type: 'text',    initialWidth: 220 },
    { label: 'Variance (d)', fieldName: 'Schedule_Variance_Days__c', type: 'number', initialWidth: 110,
      cellAttributes: { class: { fieldName: 'varClass' }, alignment: 'left' } },
    { label: '% Done',     fieldName: 'Percent_Complete__c',     type: 'percent', initialWidth: 90 },
    { label: 'Baseline Finish', fieldName: 'Baseline_Finish__c', type: 'date',   initialWidth: 130 },
    { label: 'Current Finish',  fieldName: 'Current_Finish__c',  type: 'date',   initialWidth: 130 },
    { label: 'Critical',   fieldName: 'Critical_Path__c',        type: 'boolean', initialWidth: 80 },
    { label: 'Actions',    type: 'action', typeAttributes: { rowActions: ROW_ACTIONS } }
];

export default class EpcScheduleVariance extends NavigationMixin(LightningElement) {
    @api recordId;
    @api objectApiName;

    @track _items      = [];
    @track isLoading   = true;
    @track errorMessage;
    @track showTable   = true;

    columns = autoColumns(COLUMNS);

    _totalCount    = 0;
    _onTimeCount   = 0;
    _delayedCount  = 0;
    _criticalCount = 0;
    _avgVariance   = 0;

    connectedCallback() { this._load(false); }

    _load(refresh = false) {
        this.isLoading = true;
        getWBSItems({
            recordId:   this.recordId   || null,
            objectType: this.objectApiName || 'Project__c'
        }).then(data => {
            this.errorMessage = undefined;
            this._computeMetrics(data);
            this._items = (data || []).map(r => ({
                ...r,
                wbsLink:  `/lightning/r/WBS_Item__c/${r.Id}/view`,
                varClass: r.Schedule_Variance_Days__c > 0 ? 'sv-behind'
                        : r.Schedule_Variance_Days__c < 0 ? 'sv-ahead' : ''
            })).sort((a, b) => (b.Schedule_Variance_Days__c || 0) - (a.Schedule_Variance_Days__c || 0));
        }).catch(err => {
            this.errorMessage = err.body?.message || err.message || 'Failed to load WBS items.';
        }).finally(() => {
            this.isLoading = false;
            if (refresh && !this.errorMessage) {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Refreshed',
                    message: `${this._totalCount} WBS items loaded.`,
                    variant: 'success'
                }));
            }
        });
    }

    _computeMetrics(items) {
        if (!items || items.length === 0) { this._totalCount = 0; return; }
        let delayed = 0, critical = 0, varSum = 0, varCnt = 0;
        items.forEach(item => {
            if (item.Is_Delayed__c)    delayed++;
            if (item.Critical_Path__c) critical++;
            if (item.Schedule_Variance_Days__c != null) { varSum += item.Schedule_Variance_Days__c; varCnt++; }
        });
        this._totalCount    = items.length;
        this._delayedCount  = delayed;
        this._onTimeCount   = items.length - delayed;
        this._criticalCount = critical;
        this._avgVariance   = varCnt > 0 ? Math.round(varSum / varCnt) : 0;
    }

    get totalCount()    { return this._totalCount; }
    get onTimeCount()   { return this._onTimeCount; }
    get delayedCount()  { return this._delayedCount; }
    get criticalCount() { return this._criticalCount; }
    get avgVariance()   { return this._avgVariance; }

    get onTimePct()  { return this._totalCount > 0 ? Math.round((this._onTimeCount / this._totalCount) * 100) : 0; }
    get delayedPct() { return this._totalCount > 0 ? Math.round((this._delayedCount / this._totalCount) * 100) : 0; }

    get onTimeClass()   { return this.onTimePct  >= 80 ? 'metric-value metric-value--success' : 'metric-value metric-value--warning'; }
    get delayedClass()  { return this._delayedCount > 0 ? 'metric-value metric-value--error' : 'metric-value metric-value--success'; }
    get varianceClass() { return this._avgVariance > 0 ? 'metric-value metric-value--error' : this._avgVariance < 0 ? 'metric-value metric-value--success' : 'metric-value'; }

    get hasData()       { return !this.isLoading && !this.errorMessage && this._totalCount > 0; }
    get isEmpty()       { return !this.isLoading && !this.errorMessage && this._totalCount === 0; }
    get toggleLabel()   { return this.showTable ? 'Hide Detail' : 'Show Detail'; }
    get countLabelText(){ return countLabel(this._items.length, this._totalCount, 'WBS items'); }

    handleRefresh()     { this._load(true); }
    handleToggleTable() { this.showTable = !this.showTable; }

    handleRowAction(event) {
        const { name } = event.detail.action;
        const row = event.detail.row;
        if (name === 'view') {
            this[NavigationMixin.Navigate]({ type: 'standard__recordPage', attributes: { recordId: row.Id, actionName: 'view' } });
        }
    }
}
