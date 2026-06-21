import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { autoColumns, countLabel } from 'c/epcTableUtils';
import getQualityKPIs       from '@salesforce/apex/QualityHubController.getQualityKPIs';
import getCalibrationAlerts from '@salesforce/apex/QualityHubController.getCalibrationAlerts';
import getQualityHubData    from '@salesforce/apex/QualityHubController.getQualityHubData';

const CALIB_ACTIONS = [{ label: 'View', name: 'view' }, { label: 'Edit', name: 'edit' }];
const NCR_ACTIONS   = [{ label: 'View', name: 'view' }, { label: 'Edit', name: 'edit' }];

export default class EpcQualityDashboard extends NavigationMixin(LightningElement) {
    @api recordId;

    @track kpis;
    @track calibrationAlerts = [];
    @track recentNcrs        = [];
    @track ncrSeverityData   = [];
    @track isLoading         = true;
    @track error;

    get calibColumns() {
        return autoColumns([
            { label: 'Calib #',    fieldName: 'calibLink', type: 'url', typeAttributes: { label: { fieldName: 'Name' }, target: '_self' } },
            { label: 'Instrument', fieldName: 'Instrument__c', type: 'text' },
            { label: 'Serial No.', fieldName: 'Serial_No__c',  type: 'text' },
            { label: 'Due Date',   fieldName: 'Due_Date__c',   type: 'date' },
            { label: 'Status',     fieldName: 'Status__c',     type: 'text',
              cellAttributes: { class: { fieldName: 'calibStatusClass' } } },
            { label: 'Actions',    type: 'action', typeAttributes: { rowActions: CALIB_ACTIONS } }
        ]);
    }
    get ncrColumns() {
        return autoColumns([
            { label: 'NCR #',     fieldName: 'ncrLink', type: 'url', typeAttributes: { label: { fieldName: 'Name' }, target: '_self' } },
            { label: 'Severity',  fieldName: 'Severity__c',       type: 'text',
              cellAttributes: { class: { fieldName: 'ncrSevClass' } } },
            { label: 'Category',  fieldName: 'Category__c',       type: 'text' },
            { label: 'Status',    fieldName: 'Status__c',         type: 'text' },
            { label: 'Identified',fieldName: 'Identified_Date__c',type: 'date' },
            { label: 'Actions',   type: 'action', typeAttributes: { rowActions: NCR_ACTIONS } }
        ]);
    }

    get passRateDisplay() { return this.kpis ? `${this.kpis.inspectionPassRate}%` : '—'; }
    get passRateClass() {
        const r = this.kpis?.inspectionPassRate || 0;
        return r >= 90 ? 'kpi-value qd-ok' : r >= 70 ? 'kpi-value qd-warn' : 'kpi-value qd-fail';
    }
    get calibExpiredClass() { return (this.kpis?.expiredCalibrations || 0) > 0 ? 'kpi-value qd-fail' : 'kpi-value qd-ok'; }

    get ncrCountLabel()   { return countLabel(this.recentNcrs.length, this.recentNcrs.length, 'NCRs'); }
    get calibCountLabel() { return countLabel(this.calibrationAlerts.length, this.calibrationAlerts.length, 'calibrations'); }

    connectedCallback() { this._load(); }

    _load(showToast = false) {
        this.isLoading = true;
        Promise.all([
            getQualityKPIs({ projectId: this.recordId || null }),
            getCalibrationAlerts(),
            getQualityHubData({ projectId: this.recordId || null })
        ]).then(([kpiData, calib, hubData]) => {
            this.kpis = kpiData;
            this.calibrationAlerts = (calib || []).map(r => ({
                ...r,
                calibLink:        `/lightning/r/Calibration_Record__c/${r.Id}/view`,
                calibStatusClass: r.Status__c === 'Expired' ? 'qd-fail' : 'qd-warn'
            }));
            const ncrs = hubData?.ncrs || [];
            const counts = { Critical: 0, Major: 0, Minor: 0 };
            ncrs.forEach(n => { if (counts[n.Severity__c] !== undefined) counts[n.Severity__c]++; });
            this.ncrSeverityData = [
                { label: 'Critical', count: counts.Critical, key: 'Critical', sevClass: 'sev-critical' },
                { label: 'Major',    count: counts.Major,    key: 'Major',    sevClass: 'sev-major' },
                { label: 'Minor',    count: counts.Minor,    key: 'Minor',    sevClass: 'sev-minor' }
            ];
            this.recentNcrs = ncrs.slice(0, 10).map(r => ({
                ...r,
                ncrLink:    `/lightning/r/NCR__c/${r.Id}/view`,
                ncrSevClass: this._ncrSevClass(r.Severity__c)
            }));
            this.error = null;
            if (showToast) {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Refreshed',
                    message: 'Quality dashboard data has been updated.',
                    variant: 'success'
                }));
            }
        }).catch(err => {
            this.error = err.body?.message || 'Failed to load quality dashboard.';
        }).finally(() => { this.isLoading = false; });
    }

    _ncrSevClass(s) { return { 'Critical': 'qd-fail', 'Major': 'qd-warn', 'Minor': 'qd-minor' }[s] || ''; }

    handleRefresh() { this._load(true); }
    handleNewNCR()  { this[NavigationMixin.Navigate]({ type: 'standard__objectPage', attributes: { objectApiName: 'NCR__c', actionName: 'new' } }); }

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
