import { LightningElement, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { autoColumns, countLabel } from 'c/epcTableUtils';
import getMRStatusCounts  from '@salesforce/apex/ProcurementConsoleCtrl.getMRStatusCounts';
import getRFQStatusCounts from '@salesforce/apex/ProcurementConsoleCtrl.getRFQStatusCounts';
import getPOStatusCounts  from '@salesforce/apex/ProcurementConsoleCtrl.getPOStatusCounts';
import getPurchaseOrders  from '@salesforce/apex/ProcurementConsoleCtrl.getPurchaseOrders';

const PO_ACTIONS = [
    { label: 'View Details',     name: 'view'    },
    { label: 'Edit',             name: 'edit'    },
    { label: 'Mark Delivered',   name: 'deliver' },
    { label: 'Raise Change Order', name: 'co'   }
];

export default class EpcProcurementConsole extends NavigationMixin(LightningElement) {
    @track mrCounts      = [];
    @track rfqCounts     = [];
    @track poCounts      = [];
    @track poList        = [];
    @track criticalOnly  = false;
    @track poSearchTerm  = '';
    @track isLoading     = true;
    @track error;

    get poColumns() {
        return autoColumns([
            { label: 'PO Number',    fieldName: 'poLink',              type: 'url',      typeAttributes: { label: { fieldName: 'Name' }, target: '_self' } },
            { label: 'Vendor',       fieldName: 'VendorName',          type: 'text' },
            { label: 'Status',       fieldName: 'Status__c',           type: 'text',
              cellAttributes: { class: { fieldName: 'statusClass' } } },
            { label: 'Approval Stage', fieldName: 'Approval_Stage__c', type: 'text' },
            { label: 'Contract Value ₹', fieldName: 'Total_Value__c',  type: 'currency', typeAttributes: { currencyCode: 'INR', minimumFractionDigits: 0 } },
            { label: 'Expected Delivery', fieldName: 'Expected_Delivery__c', type: 'date' },
            { label: 'Critical',     fieldName: 'Is_Critical__c',      type: 'boolean' },
            { label: 'Actions',      type: 'action', typeAttributes: { rowActions: PO_ACTIONS } }
        ]);
    }

    get filteredPoList() {
        const term = (this.poSearchTerm || '').trim().toLowerCase();
        if (!term) return this.poList;
        return this.poList.filter(p =>
            (p.Name || '').toLowerCase().includes(term) ||
            (p.VendorName || '').toLowerCase().includes(term) ||
            (p.Status__c || '').toLowerCase().includes(term) ||
            (p.Approval_Stage__c || '').toLowerCase().includes(term)
        );
    }

    get poCountLabel() {
        return countLabel(this.filteredPoList.length, this.poList.length, 'purchase orders');
    }

    get hasPoSearch() {
        return !!(this.poSearchTerm || '').trim();
    }

    get emptyPoMessage() {
        if (this.hasPoSearch) return 'No purchase orders match your search. Try a different PO number or vendor name.';
        if (this.criticalOnly) return 'No critical purchase orders found. Switch to All POs to see the full list.';
        return 'No purchase orders yet. Click New PO to create your first order.';
    }

    connectedCallback() { this.loadAll(); }

    _mapPoList(pos) {
        return pos.map(p => ({
            ...p,
            poLink:      `/lightning/r/Purchase_Order__c/${p.Id}/view`,
            VendorName:  p.Vendor__r?.Name  || '—',
            ProjectName: p.Project__r?.Name || '—',
            statusClass: this._poStatusClass(p.Status__c)
        }));
    }

    loadAll(showToast = false) {
        this.isLoading = true;
        Promise.all([
            getMRStatusCounts(),
            getRFQStatusCounts(),
            getPOStatusCounts(),
            getPurchaseOrders({ criticalOnly: this.criticalOnly })
        ]).then(([mr, rfq, po, pos]) => {
            this.mrCounts  = this._fmt(mr);
            this.rfqCounts = this._fmt(rfq);
            this.poCounts  = this._fmt(po);
            this.poList    = this._mapPoList(pos);
            this.error = null;
            if (showToast) {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Refreshed',
                    message: 'Procurement data has been updated.',
                    variant: 'success'
                }));
            }
        }).catch(err => {
            this.error = err.body?.message || 'Failed to load procurement data.';
        }).finally(() => { this.isLoading = false; });
    }

    _fmt(data) {
        return Object.entries(data).map(([status, count]) => ({
            status,
            countStr:   String(count),
            badgeClass: count > 0 ? 'count-badge count-active' : 'count-badge count-zero'
        }));
    }

    _poStatusClass(st) {
        const map = { 'Draft': 'status-draft', 'Issued': 'status-issued', 'Partially Received': 'status-partial', 'Received': 'status-received', 'Closed': 'status-closed', 'Cancelled': 'status-cancelled' };
        return map[st] || '';
    }

    /* KPIs derived from counts */
    get totalPOValue() {
        const total = this.poList.reduce((s, p) => s + (p.Total_Value__c || 0), 0);
        if (total >= 10000000) return `₹${(total/10000000).toFixed(1)} Cr`;
        if (total >= 100000)  return `₹${(total/100000).toFixed(1)} L`;
        return `₹${total.toLocaleString('en-IN')}`;
    }
    get openMRCount()  { return this.mrCounts.filter(m => m.status !== 'PO Raised' && m.status !== 'Cancelled').reduce((s,m) => s + parseInt(m.countStr||0,10), 0); }
    get pendingApprovalCount() { return this.poList.filter(p => p.Approval_Stage__c && p.Approval_Stage__c !== 'Approved').length; }
    get criticalPOCount() { return this.poList.filter(p => p.Is_Critical__c).length; }

    /* Toggle */
    get allVariant()      { return this.criticalOnly ? 'neutral' : 'brand'; }
    get criticalVariant() { return this.criticalOnly ? 'brand'   : 'neutral'; }

    showAll() {
        this.criticalOnly = false;
        getPurchaseOrders({ criticalOnly: false }).then(pos => {
            this.poList = this._mapPoList(pos);
        });
    }
    showCritical() {
        this.criticalOnly = true;
        getPurchaseOrders({ criticalOnly: true }).then(pos => {
            this.poList = this._mapPoList(pos);
        });
    }

    handlePoSearch(event) { this.poSearchTerm = event.target.value; }

    handleNewMR()  { this[NavigationMixin.Navigate]({ type: 'standard__objectPage', attributes: { objectApiName: 'Material_Requisition__c', actionName: 'new' } }); }
    handleNewRFQ() { this[NavigationMixin.Navigate]({ type: 'standard__objectPage', attributes: { objectApiName: 'RFQ__c',                  actionName: 'new' } }); }
    handleNewPO()  { this[NavigationMixin.Navigate]({ type: 'standard__objectPage', attributes: { objectApiName: 'Purchase_Order__c',        actionName: 'new' } }); }
    handleRefresh() { this.loadAll(true); }

    handleRowAction(event) {
        const { name } = event.detail.action;
        const row = event.detail.row;
        if (name === 'view' || name === 'deliver') {
            this[NavigationMixin.Navigate]({ type: 'standard__recordPage', attributes: { recordId: row.Id, actionName: 'view' } });
        } else if (name === 'edit') {
            this[NavigationMixin.Navigate]({ type: 'standard__recordPage', attributes: { recordId: row.Id, actionName: 'edit' } });
        } else if (name === 'co') {
            this[NavigationMixin.Navigate]({ type: 'standard__objectPage', attributes: { objectApiName: 'Change_Order__c', actionName: 'new' } });
        }
    }
}
