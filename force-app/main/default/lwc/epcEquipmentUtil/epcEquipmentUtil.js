import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { autoColumns, countLabel } from 'c/epcTableUtils';
import getEquipment from '@salesforce/apex/ConstructionBoardController.getEquipmentForProject';
import getDefaultProjectId from '@salesforce/apex/ConstructionBoardController.getDefaultProjectId';

const MAX_HOURS = 500;
const ACTIONS = [
    { label: 'View Details',     name: 'view' },
    { label: 'Edit',             name: 'edit' },
    { label: 'Log Hours',        name: 'log'  },
    { label: 'Mark Maintenance', name: 'maint'}
];

const EQUIPMENT_COLUMNS = [
    { label: 'Equipment',   fieldName: 'link', type: 'url', typeAttributes: { label: { fieldName: 'Name' }, target: '_self' }, initialWidth: 180 },
    { label: 'Type',        fieldName: 'Type__c',           type: 'text',   initialWidth: 130 },
    { label: 'Status',      fieldName: 'Status__c',         type: 'text',   initialWidth: 120,
      cellAttributes: { class: { fieldName: 'statusClass' } } },
    { label: 'Hours Logged',fieldName: 'Utilization_Hours__c', type: 'number', initialWidth: 110,
      cellAttributes: { alignment: 'right' } },
    { label: 'Utilization', fieldName: 'utilPct',           type: 'percent', typeAttributes: { maximumFractionDigits: 0 }, initialWidth: 100,
      cellAttributes: { class: { fieldName: 'utilClass' } } },
    { label: 'Last Updated',fieldName: 'LastModifiedDate',  type: 'date',   initialWidth: 120 },
    { label: 'Actions',     type: 'action', typeAttributes: { rowActions: ACTIONS } }
];

export default class EpcEquipmentUtil extends NavigationMixin(LightningElement) {
    @api recordId;
    @track equipment     = [];
    @track filtered      = [];
    @track activeFilter  = 'inuse';
    @track isLoading     = true;
    @track error;

    columns = autoColumns(EQUIPMENT_COLUMNS);

    filterButtons = [
        { label: 'All',              value: 'all'  },
        { label: 'In Use',           value: 'inuse'},
        { label: 'Maintenance',      value: 'maint'},
        { label: 'Idle',             value: 'idle' }
    ];

    connectedCallback() {
        const pid = this.recordId || null;
        if (pid) { this._load(pid); }
        else {
            getDefaultProjectId()
                .then(id => this._load(id))
                .catch(err => { this.error = err.body?.message; this.isLoading = false; });
        }
    }

    _load(pid, showToast = false) {
        this.isLoading = true;
        return getEquipment({ projectId: pid })
            .then(rows => {
                this.equipment = rows.map(eq => {
                    const hrs = eq.Utilization_Hours__c || 0;
                    const pct = Math.min(Math.round(hrs / MAX_HOURS * 100), 100);
                    const st  = eq.Status__c || '';
                    return {
                        ...eq,
                        link:        `/lightning/r/Equipment__c/${eq.Id}/view`,
                        utilPct:     pct / 100,
                        statusClass: st === 'In Use'             ? 'eq-inuse'
                                   : st === 'Under Maintenance'  ? 'eq-maint'
                                   : 'eq-idle',
                        utilClass:   pct >= 80 ? 'util-high' : pct >= 40 ? 'util-mid' : 'util-low'
                    };
                });
                this._applyFilter();
                if (showToast) {
                    this.dispatchEvent(new ShowToastEvent({
                        title: 'Refreshed',
                        message: 'Equipment data updated.',
                        variant: 'success'
                    }));
                }
            })
            .catch(err => { this.error = err.body?.message || 'Failed to load equipment.'; })
            .finally(() => { this.isLoading = false; });
    }

    _applyFilter() {
        const f = this.activeFilter;
        this.filtered = f === 'all'   ? this.equipment
            : f === 'inuse'           ? this.equipment.filter(e => e.Status__c === 'In Use')
            : f === 'maint'           ? this.equipment.filter(e => e.Status__c === 'Under Maintenance')
            : this.equipment.filter(e => e.Status__c !== 'In Use' && e.Status__c !== 'Under Maintenance');
    }

    /* KPIs */
    get totalCount()  { return this.equipment.length; }
    get inUseCount()  { return this.equipment.filter(e => e.Status__c === 'In Use').length; }
    get maintCount()  { return this.equipment.filter(e => e.Status__c === 'Under Maintenance').length; }
    get idleCount()   { return this.equipment.filter(e => e.Status__c !== 'In Use' && e.Status__c !== 'Under Maintenance').length; }
    get totalHours()  { return this.equipment.reduce((s, e) => s + (e.Utilization_Hours__c || 0), 0).toLocaleString('en-IN'); }
    get avgUtil()     {
        if (!this.equipment.length) return '0%';
        const avg = this.equipment.reduce((s, e) => s + (e.Utilization_Hours__c || 0), 0) / this.equipment.length;
        return Math.round(avg / MAX_HOURS * 100) + '%';
    }

    get equipmentCountLabel() {
        return countLabel(this.filtered.length, this.equipment.length, 'equipment');
    }

    get hasEquipmentData() { return this.equipment.length > 0; }
    get hasFilterMatches() { return this.filtered.length > 0; }

    get emptyFilterTitle() {
        const titles = { inuse: 'No equipment in use', maint: 'No equipment under maintenance', idle: 'No idle equipment', all: 'No equipment found' };
        return titles[this.activeFilter] || 'No equipment found';
    }

    get emptyFilterMessage() {
        const msgs = {
            inuse: 'No equipment is currently marked In Use. Try another filter or add equipment.',
            maint: 'No equipment is under maintenance right now.',
            idle:  'All equipment is either in use or under maintenance.',
            all:   'Add equipment to this project to track utilisation.'
        };
        return msgs[this.activeFilter] || 'Try a different filter.';
    }

    get filterButtonsWithState() {
        return this.filterButtons.map(b => ({
            ...b,
            variant: b.value === this.activeFilter ? 'brand' : 'neutral'
        }));
    }

    handleFilter(event) {
        this.activeFilter = event.target.dataset.value;
        this._applyFilter();
    }

    handleRowAction(event) {
        const { name } = event.detail.action;
        const row = event.detail.row;
        if (name === 'view') {
            this[NavigationMixin.Navigate]({ type: 'standard__recordPage', attributes: { recordId: row.Id, actionName: 'view' } });
        } else if (name === 'edit' || name === 'maint') {
            this[NavigationMixin.Navigate]({ type: 'standard__recordPage', attributes: { recordId: row.Id, actionName: 'edit' } });
        } else if (name === 'log') {
            this[NavigationMixin.Navigate]({ type: 'standard__objectPage', attributes: { objectApiName: 'Equipment_Log__c', actionName: 'new' } });
        }
    }

    handleNewEquipment() {
        this[NavigationMixin.Navigate]({ type: 'standard__objectPage', attributes: { objectApiName: 'Equipment__c', actionName: 'new' } });
    }
    handleRefresh() {
        const pid = this.recordId || null;
        if (pid) this._load(pid, true);
        else getDefaultProjectId().then(id => this._load(id, true));
    }
}
