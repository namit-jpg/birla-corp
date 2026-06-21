import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getKanbanContext from '@salesforce/apex/ConstructionBoardController.getKanbanContext';
import updateWorkPackageStatus from '@salesforce/apex/ConstructionBoardController.updateWorkPackageStatus';

const COLUMNS = [
    { status: 'Not Started', color: '#706e6b', variant: 'default', icon: 'utility:steps' },
    { status: 'Planned', color: '#1589ee', variant: 'info', icon: 'utility:date_input' },
    { status: 'In Progress', color: '#ff9e2c', variant: 'warning', icon: 'utility:clock' },
    { status: 'On Hold', color: '#c23934', variant: 'error', icon: 'utility:pause' },
    { status: 'Completed', color: '#027e46', variant: 'success', icon: 'utility:check' }
];

const ACTIVE_STATUSES = new Set(['Not Started', 'Planned', 'In Progress']);

export default class EpcWorkPackageKanban extends NavigationMixin(LightningElement) {
    @api recordId;

    @track projectId;
    @track projectName = '';
    @track allWorkPackages = [];
    @track columns = [];
    @track disciplines = [];
    @track isLoading = true;
    @track isUpdating = false;
    @track error;
    @track searchTerm = '';
    @track disciplineFilter = 'All';
    @track quickFilter = 'active';
    @track dragOverColumn = null;
    @track draggedCard = null;

    connectedCallback() {
        this.loadData();
    }

    loadData(showToast = false) {
        this.isLoading = true;
        this.error = null;
        const pid = this.recordId || this.projectId || null;

        getKanbanContext({ projectId: pid })
            .then(ctx => {
                this.projectId = ctx.projectId;
                this.projectName = ctx.projectName || 'Project';
                this.allWorkPackages = (ctx.workPackages || []).map(wp => this._decorateWp(wp));
                this._buildDisciplines();
                this._rebuildBoard();
                if (showToast) {
                    this._toast('Refreshed', 'Work packages updated.', 'success');
                }
            })
            .catch(err => {
                this.error = err.body?.message || 'Failed to load work packages.';
                if (showToast) {
                    this._toast('Refresh failed', this.error, 'error');
                }
            })
            .finally(() => { this.isLoading = false; });
    }

    _decorateWp(wp) {
        const pct = Math.min(wp.Percent_Complete__c || 0, 100);
        const status = wp.Status__c || 'Not Started';
        const endDate = wp.End_Date__c ? new Date(wp.End_Date__c) : null;
        const isOverdue = endDate && endDate < new Date() && status !== 'Completed';
        return {
            ...wp,
            status,
            link: `/lightning/r/Work_Package__c/${wp.Id}/view`,
            progressStyle: `width:${pct}%`,
            progressFillStyle: `width:${pct}%;background:${pct >= 80 ? '#027e46' : pct >= 40 ? '#ff9e2c' : '#c23934'}`,
            pctLabel: `${pct}%`,
            budgetDisplay: wp.Budget__c ? `₹${(wp.Budget__c / 100000).toFixed(1)}L` : '—',
            startDisplay: wp.Start_Date__c
                ? new Date(wp.Start_Date__c).toLocaleDateString('en-IN', { day: '2-digit', month: 'short' })
                : '—',
            endDisplay: wp.End_Date__c
                ? new Date(wp.End_Date__c).toLocaleDateString('en-IN', { day: '2-digit', month: 'short' })
                : '—',
            wbsCode: wp.WBS_Item__r?.Code__c || '—',
            disciplineClass: 'disc-badge disc-' + (wp.Discipline__c || 'other').toLowerCase().replace(/[^a-z]/g, ''),
            isOverdue,
            overdueClass: isOverdue ? 'date-overdue' : ''
        };
    }

    _buildDisciplines() {
        const set = new Set();
        this.allWorkPackages.forEach(wp => {
            if (wp.Discipline__c) set.add(wp.Discipline__c);
        });
        this.disciplines = ['All', ...Array.from(set).sort()];
    }

    _filteredWorkPackages() {
        const term = (this.searchTerm || '').trim().toLowerCase();
        return this.allWorkPackages.filter(wp => {
            if (this.disciplineFilter !== 'All' && wp.Discipline__c !== this.disciplineFilter) return false;
            if (this.quickFilter === 'active' && !ACTIVE_STATUSES.has(wp.status)) return false;
            if (this.quickFilter === 'hold' && wp.status !== 'On Hold') return false;
            if (this.quickFilter === 'overdue' && !wp.isOverdue) return false;
            if (!term) return true;
            return (
                (wp.Name || '').toLowerCase().includes(term) ||
                (wp.Discipline__c || '').toLowerCase().includes(term) ||
                (wp.wbsCode || '').toLowerCase().includes(term)
            );
        });
    }

    _rebuildBoard() {
        const wps = this._filteredWorkPackages();
        const grouped = {};
        COLUMNS.forEach(c => { grouped[c.status] = []; });

        wps.forEach(wp => {
            const st = wp.status;
            if (!grouped[st]) grouped[st] = [];
            grouped[st].push(wp);
        });

        this.columns = COLUMNS.map(c => ({
            ...c,
            headerStyle: `border-top: 4px solid ${c.color};`,
            bodyClass: this.dragOverColumn === c.status ? 'col-body col-body--drag-over' : 'col-body',
            cards: grouped[c.status],
            count: grouped[c.status].length,
            isEmpty: grouped[c.status].length === 0
        }));
    }

    /* KPI getters — always from full dataset */
    get totalWPs() { return this.allWorkPackages.length; }
    get inProgressCount() { return this._countByStatus('In Progress'); }
    get onHoldCount() { return this._countByStatus('On Hold'); }
    get completedCount() { return this._countByStatus('Completed'); }
    get overdueCount() { return this.allWorkPackages.filter(w => w.isOverdue).length; }

    get totalBudget() {
        return this.allWorkPackages.reduce((s, w) => s + (w.Budget__c || 0), 0);
    }

    get totalBudgetDisplay() {
        const b = this.totalBudget;
        if (b >= 10000000) return `₹${(b / 10000000).toFixed(1)} Cr`;
        if (b >= 100000) return `₹${(b / 100000).toFixed(1)} L`;
        return `₹${b.toLocaleString('en-IN')}`;
    }

    get overallPct() {
        if (!this.allWorkPackages.length) return 0;
        const sum = this.allWorkPackages.reduce((s, w) => s + (w.Percent_Complete__c || 0), 0);
        return Math.round(sum / this.allWorkPackages.length);
    }

    get overallProgressStyle() { return `width:${this.overallPct}%`; }

    get filteredCount() { return this._filteredWorkPackages().length; }

    get showCountLabel() {
        return `${this.filteredCount} of ${this.totalWPs} work packages shown`;
    }

    get hasNoData() { return !this.isLoading && this.totalWPs === 0; }

    get hasNoMatches() {
        return !this.isLoading && this.totalWPs > 0 && this.filteredCount === 0;
    }

    get subtitle() {
        return this.projectName ? `Project: ${this.projectName}` : '';
    }

    get allFilterVariant() { return this.quickFilter === 'all' ? 'brand' : 'neutral'; }
    get activeFilterVariant() { return this.quickFilter === 'active' ? 'brand' : 'neutral'; }
    get holdFilterVariant() { return this.quickFilter === 'hold' ? 'brand' : 'neutral'; }
    get overdueFilterVariant() { return this.quickFilter === 'overdue' ? 'brand' : 'neutral'; }

    get disciplineOptions() {
        return this.disciplines.map(d => ({ label: d, value: d }));
    }

    _countByStatus(status) {
        return this.allWorkPackages.filter(w => w.status === status).length;
    }

    handleSearchChange(event) {
        this.searchTerm = event.detail?.value ?? event.target.value ?? '';
        this._rebuildBoard();
    }

    stopPropagation(event) {
        event.stopPropagation();
    }

    handleDisciplineChange(event) {
        this.disciplineFilter = event.detail.value;
        this._rebuildBoard();
    }

    handleQuickFilter(event) {
        this.quickFilter = event.currentTarget.dataset.filter;
        this._rebuildBoard();
    }

    handleClearFilters() {
        this.searchTerm = '';
        this.disciplineFilter = 'All';
        this.quickFilter = 'all';
        this._rebuildBoard();
    }

    /* Drag and drop */
    handleDragStart(event) {
        const id = event.currentTarget.dataset.id;
        const status = event.currentTarget.dataset.status;
        this.draggedCard = { id, status };
        event.dataTransfer.effectAllowed = 'move';
        event.dataTransfer.setData('text/plain', id);
        event.currentTarget.classList.add('kanban-card--dragging');
    }

    handleDragEnd(event) {
        event.currentTarget.classList.remove('kanban-card--dragging');
        this.dragOverColumn = null;
        this.draggedCard = null;
        this._rebuildBoard();
    }

    handleDragOver(event) {
        event.preventDefault();
        event.dataTransfer.dropEffect = 'move';
        const status = event.currentTarget.dataset.status;
        if (this.dragOverColumn !== status) {
            this.dragOverColumn = status;
            this._rebuildBoard();
        }
    }

    handleDragLeave(event) {
        const status = event.currentTarget.dataset.status;
        if (this.dragOverColumn === status) {
            this.dragOverColumn = null;
            this._rebuildBoard();
        }
    }

    handleDrop(event) {
        event.preventDefault();
        const newStatus = event.currentTarget.dataset.status;
        const cardId = this.draggedCard?.id;
        const oldStatus = this.draggedCard?.status;
        this.dragOverColumn = null;
        this.draggedCard = null;

        if (!cardId || !newStatus || newStatus === oldStatus) {
            this._rebuildBoard();
            return;
        }
        this._moveCard(cardId, oldStatus, newStatus);
    }

    _moveCard(cardId, oldStatus, newStatus) {
        const snapshot = [...this.allWorkPackages];
        this.allWorkPackages = this.allWorkPackages.map(wp =>
            wp.Id === cardId ? { ...wp, status: newStatus, Status__c: newStatus } : wp
        );
        this._rebuildBoard();
        this.isUpdating = true;

        updateWorkPackageStatus({ workPackageId: cardId, newStatus })
            .then(() => {
                this._toast('Status updated', `Moved to ${newStatus}.`, 'success');
            })
            .catch(err => {
                this.allWorkPackages = snapshot;
                this._rebuildBoard();
                this._toast('Update failed', err.body?.message || 'Could not update status.', 'error');
            })
            .finally(() => { this.isUpdating = false; });
    }

    handleCardClick(event) {
        if (event.target.closest('.card-actions')) return;
        const id = event.currentTarget.dataset.id;
        this._navigateToRecord(id, 'view');
    }

    handleCardMenuSelect(event) {
        event.stopPropagation();
        const action = event.detail.value;
        const id = event.currentTarget.dataset.id;
        if (action === 'view' || action === 'edit') {
            this._navigateToRecord(id, action);
        }
    }

    _navigateToRecord(recordId, actionName) {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId, actionName }
        });
    }

    handleNewWP() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: { objectApiName: 'Work_Package__c', actionName: 'new' }
        });
    }

    handleRefresh() {
        this.loadData(true);
    }

    _toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant, mode: 'dismissable' }));
    }
}
