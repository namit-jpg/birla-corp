import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { createRecord } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { autoColumns, countLabel } from 'c/epcTableUtils';
import getWorkPackageDetails from '@salesforce/apex/EpcDailyProgressController.getWorkPackageDetails';
import getRecentDprs from '@salesforce/apex/EpcDailyProgressController.getRecentDprs';

const DAILY_PROGRESS_OBJECT = 'Daily_Progress__c';

const RECENT_ACTIONS = [
    { label: 'View', name: 'view' }
];

const WEATHER_OPTIONS = [
    { label: '— Select —', value: '' },
    { label: 'Clear',      value: 'Clear' },
    { label: 'Cloudy',     value: 'Cloudy' },
    { label: 'Rain',       value: 'Rain' },
    { label: 'Heavy Rain', value: 'Heavy Rain' },
    { label: 'Hot',        value: 'Hot' },
    { label: 'Windy',      value: 'Windy' },
    { label: 'Storm',      value: 'Storm' }
];

const RECENT_COLUMNS = [
    { label: 'Date',         fieldName: 'dprLink', type: 'url', typeAttributes: { label: { fieldName: 'Date__c' }, target: '_self' }, initialWidth: 110 },
    { label: 'Qty Installed',fieldName: 'Qty_Installed__c',   type: 'number', initialWidth: 120 },
    { label: 'Planned Qty',  fieldName: 'Planned_Quantity__c',type: 'number', initialWidth: 110 },
    { label: 'Hours',        fieldName: 'Hours_Worked__c',    type: 'number', initialWidth: 80 },
    { label: 'Crew',         fieldName: 'Crew_Size__c',       type: 'number', initialWidth: 70 },
    { label: 'Productivity', fieldName: 'Productivity__c',    type: 'number', initialWidth: 110,
      typeAttributes: { minimumFractionDigits: 2, maximumFractionDigits: 2 } },
    { label: 'Weather',      fieldName: 'Weather__c',         type: 'text',   initialWidth: 90 },
    { label: 'Safety',       fieldName: 'Safety_Incidents__c',type: 'number', initialWidth: 75 },
    { label: 'Quality',      fieldName: 'Quality_Issues__c',  type: 'number', initialWidth: 75 },
    { label: 'Actions',      type: 'action', typeAttributes: { rowActions: RECENT_ACTIONS } }
];

export default class EpcDailyProgressCapture extends NavigationMixin(LightningElement) {
    @api recordId;
    @api projectId;

    @track selectedWpId;
    @track wp;
    @track recentRecords  = [];
    @track isLoadingWp    = false;
    @track isLoadingRecent= false;
    @track isSaving       = false;
    @track errorMessage   = '';

    @track formDate             = new Date().toISOString().substring(0, 10);
    @track formQtyInstalled     = '';
    @track formPlannedQty       = '';
    @track formHoursWorked      = '';
    @track formCrewSize         = '';
    @track formWeather          = '';
    @track formSafetyIncidents  = 0;
    @track formQualityIssues    = 0;

    recentColumns = autoColumns(RECENT_COLUMNS);

    get weatherOptions()  { return WEATHER_OPTIONS; }
    get saveLabel()       { return this.isSaving ? 'Saving…' : 'Save DPR'; }
    get hasWp()           { return !!this.selectedWpId; }
    get hasRecentRecords(){ return this.recentRecords.length > 0; }

    get wpName()         { return this.wp?.Name ?? ''; }
    get wpPlannedQty()   { return this.wp?.Planned_Qty__c ?? '—'; }
    get wpPercent()      { return this.wp?.Percent_Complete__c ?? 0; }
    get wpBudget()       { return this.wp?.Budget__c != null ? `₹${Number(this.wp.Budget__c).toLocaleString()}` : '—'; }
    get progressBarStyle() { return `width: ${Math.min(this.wpPercent, 100)}%`; }
    get progressClass()  {
        const p = this.wpPercent;
        return p >= 90 ? 'progress-bar-fill progress-bar-ok' : p >= 60 ? 'progress-bar-fill progress-bar-warn' : 'progress-bar-fill progress-bar-low';
    }

    get recentCountLabel() {
        return countLabel(this.recentRecords.length, this.recentRecords.length, 'entries');
    }

    handleWpChange(event) {
        this.selectedWpId = event.detail.recordId;
        this.wp = null;
        this.recentRecords = [];
        if (this.selectedWpId) {
            this._loadWpDetails();
        }
    }

    _loadWpDetails() {
        this.isLoadingWp = true;
        getWorkPackageDetails({ wpId: this.selectedWpId })
            .then(result => {
                this.wp = result.wp;
                this.recentRecords = (result.recentDprs || []).map(r => ({
                    ...r,
                    dprLink: `/lightning/r/Daily_Progress__c/${r.Id}/view`
                }));
            })
            .catch(err => { this.errorMessage = err.body?.message || 'Failed to load WP details.'; })
            .finally(() => { this.isLoadingWp = false; });
    }

    _loadRecentRecords(showToast = false) {
        if (!this.selectedWpId) return;
        this.isLoadingRecent = true;
        return getRecentDprs({ wpId: this.selectedWpId })
            .then(recs => {
                this.recentRecords = (recs || []).map(r => ({
                    ...r,
                    dprLink: `/lightning/r/Daily_Progress__c/${r.Id}/view`
                }));
                if (showToast) {
                    this.dispatchEvent(new ShowToastEvent({
                        title: 'Refreshed',
                        message: 'Recent DPR entries updated.',
                        variant: 'success'
                    }));
                }
            })
            .catch(err => { this.errorMessage = err.body?.message || 'Failed to refresh.'; })
            .finally(() => { this.isLoadingRecent = false; });
    }

    handleRefreshRecent() {
        this._loadRecentRecords(true);
    }

    handleFieldChange(event) {
        const field = event.target.dataset.field;
        this[field] = event.target.value;
    }

    handleSave() {
        if (!this.selectedWpId) { this.errorMessage = 'Select a Work Package first.'; return; }
        if (!this.formDate || !this.formQtyInstalled) {
            this.errorMessage = 'Date and Qty Installed are required.';
            return;
        }
        this.errorMessage = '';
        this.isSaving = true;

        const fields = {
            Work_Package__c:    this.selectedWpId,
            Date__c:            this.formDate,
            Qty_Installed__c:   Number(this.formQtyInstalled)  || 0,
            Planned_Quantity__c:Number(this.formPlannedQty)    || 0,
            Hours_Worked__c:    Number(this.formHoursWorked)   || 0,
            Crew_Size__c:       Number(this.formCrewSize)      || 0,
            Weather__c:         this.formWeather,
            Safety_Incidents__c:Number(this.formSafetyIncidents) || 0,
            Quality_Issues__c:  Number(this.formQualityIssues)   || 0
        };

        createRecord({ apiName: DAILY_PROGRESS_OBJECT, fields })
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'DPR Saved',
                    message: 'Daily progress recorded and EV updated.',
                    variant: 'success'
                }));
                this._resetForm();
                this._loadRecentRecords();
            })
            .catch(err => {
                this.errorMessage = err.body?.message || 'Error saving record.';
            })
            .finally(() => { this.isSaving = false; });
    }

    _resetForm() {
        this.formDate            = new Date().toISOString().substring(0, 10);
        this.formQtyInstalled    = '';
        this.formPlannedQty      = '';
        this.formHoursWorked     = '';
        this.formCrewSize        = '';
        this.formWeather         = '';
        this.formSafetyIncidents = 0;
        this.formQualityIssues   = 0;
        this.errorMessage        = '';
    }
    handleReset() { this._resetForm(); }

    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;
        if (actionName === 'view' && row?.Id) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: { recordId: row.Id, actionName: 'view' }
            });
        }
    }
}
