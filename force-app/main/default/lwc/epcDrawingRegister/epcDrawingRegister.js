import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { autoColumns, countLabel } from 'c/epcTableUtils';
import getDrawings from '@salesforce/apex/EpcDrawingRegisterController.getDrawings';

const ACTIONS = [
    { label: 'View Details', name: 'view'     },
    { label: 'Edit',         name: 'edit'     },
    { label: 'Supersede',    name: 'supersede'}
];

const BASE_COLUMNS = [
    { label: 'Drawing #',  fieldName: 'dwgLink',           type: 'url',
      typeAttributes: { label: { fieldName: 'Name' }, target: '_self' }, initialWidth: 130 },
    { label: 'Title',      fieldName: 'Title__c',           type: 'text',   initialWidth: 220 },
    { label: 'Discipline', fieldName: 'Discipline__c',      type: 'text',   initialWidth: 130 },
    { label: 'Revision',   fieldName: 'Current_Revision__c',type: 'text',   initialWidth: 80 },
    { label: 'Status',     fieldName: 'Status__c',          type: 'text',   initialWidth: 120,
      cellAttributes: { class: { fieldName: 'statusClass' } } },
    { label: 'Issue Date', fieldName: 'Issue_Date__c',      type: 'date',   initialWidth: 120 },
    { label: 'Drawn By',   fieldName: 'Drawn_By__c',        type: 'text',   initialWidth: 130 },
    { label: 'Actions',    type: 'action', typeAttributes: { rowActions: ACTIONS } }
];

const FILE_URL_COLUMN = {
    label: 'File URL', fieldName: 'fileLink', type: 'url',
    typeAttributes: { label: { fieldName: 'fileLinkLabel' }, target: '_blank' }
};

const DISCIPLINES = ['Civil','Mechanical','Electrical','Instrumentation','Piping','Structural','E&M'];
const STATUSES    = ['Draft','For Review','Issued for Review','Approved','Approved for Construction','IFC/GFC','Rejected','Superseded'];

export default class EpcDrawingRegister extends NavigationMixin(LightningElement) {
    @api recordId;

    @track allDrawings   = [];
    @track isLoading     = true;
    @track error;
    @track filterDisc    = 'all';
    @track filterStatus  = 'all';
    @track hasFileUrl    = false;

    get columns() {
        const cols = [...BASE_COLUMNS];
        if (this.hasFileUrl) {
            cols.splice(cols.length - 1, 0, FILE_URL_COLUMN);
        }
        return autoColumns(cols);
    }

    get discButtons() {
        return [{ label: 'All', value: 'all' }, ...DISCIPLINES.map(d => ({ label: d, value: d }))]
            .map(b => ({ ...b, variant: b.value === this.filterDisc ? 'brand' : 'neutral' }));
    }
    get statusButtons() {
        return [{ label: 'All', value: 'all' }, ...STATUSES.map(s => ({ label: s, value: s }))]
            .map(b => ({ ...b, variant: b.value === this.filterStatus ? 'brand' : 'neutral' }));
    }

    get hasFilteredData() { return this.filtered.length > 0; }
    get countLabelText()  { return countLabel(this.filtered.length, this.allDrawings.length, 'drawings'); }

    connectedCallback() { this._load(false); }

    _load(refresh = false) {
        this.isLoading = true;
        getDrawings({ projectId: this.recordId || null })
            .then(data => {
                this.hasFileUrl = (data || []).some(d => d.File_URL__c);
                this.allDrawings = data.map(d => ({
                    ...d,
                    dwgLink:       `/lightning/r/Drawing__c/${d.Id}/view`,
                    statusClass:   this._statusClass(d.Status__c),
                    fileLink:      d.File_URL__c || null,
                    fileLinkLabel: d.File_URL__c ? 'Open' : ''
                }));
                this.error = null;
            })
            .catch(err => { this.error = err.body?.message || 'Failed to load drawings.'; })
            .finally(() => {
                this.isLoading = false;
                if (refresh && !this.error) {
                    this.dispatchEvent(new ShowToastEvent({
                        title: 'Refreshed',
                        message: `${this.allDrawings.length} drawings loaded.`,
                        variant: 'success'
                    }));
                }
            });
    }

    _statusClass(s) {
        return {
            'Draft': 'dwg-draft',
            'For Review': 'dwg-review',
            'Issued for Review': 'dwg-review',
            'Approved': 'dwg-approved',
            'Approved for Construction': 'dwg-approved',
            'IFC/GFC': 'dwg-ifc',
            'Rejected': 'dwg-rejected',
            'Superseded': 'dwg-superseded'
        }[s] || '';
    }

    get filtered() {
        return this.allDrawings.filter(d => {
            const dOk = this.filterDisc   === 'all' || d.Discipline__c === this.filterDisc;
            const sOk = this.filterStatus === 'all' || d.Status__c     === this.filterStatus;
            return dOk && sOk;
        });
    }

    /* KPIs */
    get totalCount()     { return this.allDrawings.length; }
    get ifcCount()       { return this.allDrawings.filter(d => ['IFC/GFC','Approved','Approved for Construction'].includes(d.Status__c)).length; }
    get reviewCount()    { return this.allDrawings.filter(d => ['For Review','Issued for Review'].includes(d.Status__c)).length; }
    get rejectedCount()  { return this.allDrawings.filter(d => d.Status__c === 'Rejected').length; }

    handleDiscFilter(event)   { this.filterDisc   = event.target.dataset.value; }
    handleStatusFilter(event) { this.filterStatus = event.target.dataset.value; }
    handleRefresh()           { this._load(true); }
    handleNewDrawing()        { this[NavigationMixin.Navigate]({ type: 'standard__objectPage', attributes: { objectApiName: 'Drawing__c', actionName: 'new' } }); }

    handleRowAction(event) {
        const { name } = event.detail.action;
        const row = event.detail.row;
        if (name === 'view' || name === 'supersede') {
            this[NavigationMixin.Navigate]({ type: 'standard__recordPage', attributes: { recordId: row.Id, actionName: 'view' } });
        } else if (name === 'edit') {
            this[NavigationMixin.Navigate]({ type: 'standard__recordPage', attributes: { recordId: row.Id, actionName: 'edit' } });
        }
    }
}
