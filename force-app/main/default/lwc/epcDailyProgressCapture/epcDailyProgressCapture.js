import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { createRecord } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getWbsDetails from '@salesforce/apex/EpcDailyProgressController.getWbsDetails';
import getRecentDprs from '@salesforce/apex/EpcDailyProgressController.getRecentDprs';

const DAILY_PROGRESS_OBJECT = 'Daily_Progress__c';

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

export default class EpcDailyProgressCapture extends NavigationMixin(LightningElement) {
    @api recordId;
    @api projectId;

    @track selectedWbsId;
    @track wbs;
    @track recentRecords   = [];
    @track isLoadingWbs    = false;
    @track isLoadingRecent = false;
    @track isSaving        = false;
    @track errorMessage    = '';

    @track formDate             = new Date().toISOString().substring(0, 10);
    @track formPercentComplete  = '';
    @track formHoursWorked      = '';
    @track formCrewSize         = '';
    @track formWeather          = '';
    @track formSafetyIncidents  = 0;
    @track formQualityIssues    = 0;

    get weatherOptions()   { return WEATHER_OPTIONS; }
    get saveLabel()        { return this.isSaving ? 'Saving…' : 'Save DPR'; }
    get hasWbs()           { return !!this.selectedWbsId; }
    get hasRecentRecords() { return this.recentRecords.length > 0; }

    get wbsCode()    { return this.wbs?.Code__c  ?? ''; }
    get wbsName()    { return this.wbs?.Name__c  ?? ''; }
    get wbsPercent() { return this.wbs?.Percent_Complete__c ?? 0; }

    get progressBarStyle() { return `width: ${Math.min(this.wbsPercent, 100)}%`; }
    get progressClass() {
        const p = this.wbsPercent;
        return p >= 90 ? 'progress-bar-fill progress-bar-ok'
             : p >= 60 ? 'progress-bar-fill progress-bar-warn'
             :            'progress-bar-fill progress-bar-low';
    }

    handleWbsChange(event) {
        this.selectedWbsId = event.detail.recordId;
        this.wbs = null;
        this.recentRecords = [];
        if (this.selectedWbsId) {
            this._loadWbsDetails();
        }
    }

    _loadWbsDetails() {
        this.isLoadingWbs = true;
        getWbsDetails({ wbsId: this.selectedWbsId })
            .then(result => {
                this.wbs = result.wbs;
                this.recentRecords = (result.recentDprs || []).map(r => ({
                    ...r,
                    dprLink: `/lightning/r/Daily_Progress__c/${r.Id}/view`
                }));
            })
            .catch(err => { this.errorMessage = err.body?.message || 'Failed to load WBS details.'; })
            .finally(() => { this.isLoadingWbs = false; });
    }

    handleRefreshRecent() {
        if (!this.selectedWbsId) return;
        this.isLoadingRecent = true;
        getRecentDprs({ wbsId: this.selectedWbsId })
            .then(recs => {
                this.recentRecords = (recs || []).map(r => ({
                    ...r,
                    dprLink: `/lightning/r/Daily_Progress__c/${r.Id}/view`
                }));
                this.dispatchEvent(new ShowToastEvent({ title: 'Refreshed', message: 'Recent DPR entries updated.', variant: 'success' }));
            })
            .catch(err => { this.errorMessage = err.body?.message || 'Failed to refresh.'; })
            .finally(() => { this.isLoadingRecent = false; });
    }

    handleFieldChange(event) {
        const field = event.target.dataset.field;
        this[field] = event.target.value;
    }

    handleSave() {
        if (!this.selectedWbsId) { this.errorMessage = 'Select a WBS item first.'; return; }
        if (!this.formDate || this.formPercentComplete === '') {
            this.errorMessage = 'Date and % Complete are required.';
            return;
        }
        const pct = Number(this.formPercentComplete);
        if (pct < 0 || pct > 100) {
            this.errorMessage = '% Complete must be between 0 and 100.';
            return;
        }
        this.errorMessage = '';
        this.isSaving = true;

        const fields = {
            WBS_Item__c:             this.selectedWbsId,
            Date__c:                 this.formDate,
            Percent_Complete_Day__c: pct,
            Hours_Worked__c:         Number(this.formHoursWorked)    || 0,
            Crew_Size__c:            Number(this.formCrewSize)        || 0,
            Weather__c:              this.formWeather,
            Safety_Incidents__c:     Number(this.formSafetyIncidents) || 0,
            Quality_Issues__c:       Number(this.formQualityIssues)   || 0
        };

        createRecord({ apiName: DAILY_PROGRESS_OBJECT, fields })
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'DPR Saved',
                    message: 'Progress recorded. WBS % complete updated.',
                    variant: 'success'
                }));
                this._resetForm();
                this._loadWbsDetails();
            })
            .catch(err => { this.errorMessage = err.body?.message || 'Error saving record.'; })
            .finally(() => { this.isSaving = false; });
    }

    _resetForm() {
        this.formDate            = new Date().toISOString().substring(0, 10);
        this.formPercentComplete = '';
        this.formHoursWorked     = '';
        this.formCrewSize        = '';
        this.formWeather         = '';
        this.formSafetyIncidents = 0;
        this.formQualityIssues   = 0;
        this.errorMessage        = '';
    }
    handleReset() { this._resetForm(); }

    handleCardClick(event) {
        const recordId = event.currentTarget.dataset.id;
        if (recordId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: { recordId, actionName: 'view' }
            });
        }
    }
}
