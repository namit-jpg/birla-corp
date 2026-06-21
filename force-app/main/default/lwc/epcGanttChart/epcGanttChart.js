import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getWBSItems from '@salesforce/apex/EpcGanttController.getWBSItems';

const MS_PER_DAY = 86400000;

export default class EpcGanttChart extends NavigationMixin(LightningElement) {
    @api recordId;
    @api objectApiName;

    @track _rows = [];
    @track isLoading = true;
    @track errorMessage;
    @track filterMode = 'all';
    @track dateRangeLabel = '';
    @track monthMarkers = [];

    _ganttStartMs = 0;
    _ganttEndMs = 0;
    _ganttRangeMs = 1;

    connectedCallback() {
        this._load(false);
    }

    get isRecordPage() {
        return this.objectApiName === 'Project__c' || this.objectApiName === 'WBS_Item__c';
    }

    get cardClass() {
        return this.isRecordPage ? 'gantt-card gantt-card--embedded' : 'gantt-card';
    }

    get displayRows() {
        if (this.filterMode === 'critical') {
            return this._rows.filter(r => r.isCritical);
        }
        if (this.filterMode === 'delayed') {
            return this._rows.filter(r => r.isDelayed);
        }
        return this._rows;
    }

    get hasRows() {
        return this._rows.length > 0;
    }

    get hasDisplayRows() {
        return this.displayRows.length > 0;
    }

    get isEmpty() {
        return !this.isLoading && !this.errorMessage && !this.hasRows;
    }

    get isFilterEmpty() {
        return !this.isLoading && this.hasRows && !this.hasDisplayRows;
    }

    get totalCount() {
        return this._rows.length;
    }

    get criticalCount() {
        return this._rows.filter(r => r.isCritical).length;
    }

    get delayedCount() {
        return this._rows.filter(r => r.isDelayed).length;
    }

    get onTrackCount() {
        return this._rows.filter(r => !r.isDelayed && !r.isCritical).length;
    }

    get avgPct() {
        if (!this._rows.length) return '0%';
        const avg = this._rows.reduce((s, r) => s + (r.percentNum || 0), 0) / this._rows.length;
        return `${avg.toFixed(0)}%`;
    }

    get countLabel() {
        if (!this.hasRows) return '';
        if (this.filterMode === 'all') {
            return `${this.totalCount} WBS items`;
        }
        return `${this.displayRows.length} of ${this.totalCount} WBS items shown`;
    }

    get todayLineStyle() {
        const pct = this._dateToPercent(new Date());
        if (pct < 0 || pct > 100) return 'display:none';
        return `left:${pct.toFixed(2)}%;`;
    }

    get timelineMinWidth() {
        const months = Math.max(this.monthMarkers.length, 6);
        return `min-width:${Math.max(months * 72, 640)}px`;
    }

    get allFilterVariant() {
        return this.filterMode === 'all' ? 'brand' : 'neutral';
    }

    get criticalFilterVariant() {
        return this.filterMode === 'critical' ? 'brand' : 'neutral';
    }

    get delayedFilterVariant() {
        return this.filterMode === 'delayed' ? 'brand' : 'neutral';
    }

    _load(refresh = false) {
        this.isLoading = true;
        getWBSItems({
            recordId: this.recordId || null,
            objectType: this.objectApiName || 'Project__c'
        })
            .then(data => {
                this.errorMessage = undefined;
                this._buildRows(data);
            })
            .catch(err => {
                this.errorMessage = err.body?.message || err.message || 'Failed to load WBS items.';
                this._rows = [];
                this.monthMarkers = [];
                this.dateRangeLabel = '';
            })
            .finally(() => {
                this.isLoading = false;
                if (refresh && !this.errorMessage) {
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'Refreshed',
                            message: `${this._rows.length} WBS items loaded.`,
                            variant: 'success'
                        })
                    );
                }
            });
    }

    _buildRows(items) {
        if (!items || items.length === 0) {
            this._rows = [];
            this.monthMarkers = [];
            this.dateRangeLabel = '';
            return;
        }

        let minMs = Infinity;
        let maxMs = -Infinity;
        items.forEach(item => {
            if (item.Baseline_Start__c) minMs = Math.min(minMs, this._toMs(item.Baseline_Start__c));
            if (item.Baseline_Finish__c) maxMs = Math.max(maxMs, this._toMs(item.Baseline_Finish__c));
            if (item.Current_Start__c) minMs = Math.min(minMs, this._toMs(item.Current_Start__c));
            if (item.Current_Finish__c) maxMs = Math.max(maxMs, this._toMs(item.Current_Finish__c));
        });

        if (!Number.isFinite(minMs) || !Number.isFinite(maxMs)) {
            minMs = Date.now();
            maxMs = minMs + 90 * MS_PER_DAY;
        }

        this._ganttStartMs = minMs - 7 * MS_PER_DAY;
        this._ganttEndMs = maxMs + 14 * MS_PER_DAY;
        this._ganttRangeMs = Math.max(this._ganttEndMs - this._ganttStartMs, MS_PER_DAY);

        this.dateRangeLabel = `${this._fmtDate(this._ganttStartMs)} – ${this._fmtDate(this._ganttEndMs)}`;
        this.monthMarkers = this._buildMonthMarkers();
        this._rows = items.map(item => this._buildRow(item));
    }

    _buildMonthMarkers() {
        const markers = [];
        const end = new Date(this._ganttEndMs);
        let cursor = new Date(new Date(this._ganttStartMs).getFullYear(), new Date(this._ganttStartMs).getMonth(), 1);

        while (cursor.getTime() <= end.getTime()) {
            const pct = this._dateToPercent(cursor);
            if (pct >= -2 && pct <= 102) {
                markers.push({
                    key: `${cursor.getFullYear()}-${cursor.getMonth()}`,
                    label: cursor.toLocaleDateString('en-IN', { month: 'short', year: '2-digit' }),
                    lineStyle: `left:${pct.toFixed(2)}%`
                });
            }
            cursor = new Date(cursor.getFullYear(), cursor.getMonth() + 1, 1);
        }
        return markers;
    }

    _buildRow(item) {
        const isCritical = item.Critical_Path__c === true;
        const isDelayed = item.Is_Delayed__c === true;
        const percentNum = item.Percent_Complete__c != null ? item.Percent_Complete__c : 0;

        const baselineBar = this._calcBar(item.Baseline_Start__c, item.Baseline_Finish__c);
        const currentBar = this._calcBar(item.Current_Start__c, item.Current_Finish__c);

        const baselineColor = isCritical ? '#c23934' : '#0176d3';
        const currentColor = isCritical ? '#8e030f' : isDelayed ? '#fe9339' : '#2e844a';

        const baselineBarStyle = baselineBar
            ? `left:${baselineBar.left}%;width:${baselineBar.width}%;background:${baselineColor};`
            : 'display:none;';
        const currentBarStyle = currentBar
            ? `left:${currentBar.left}%;width:${currentBar.width}%;background:${currentColor};`
            : 'display:none;';
        const progressStyle = `width:${Math.min(Math.max(percentNum, 0), 100)}%;`;

        const lvl = Math.max(0, Math.min((item.Level__c || 1) - 1, 4));
        const variance = item.Schedule_Variance_Days__c != null ? item.Schedule_Variance_Days__c : 0;

        return {
            id: item.Id,
            key: item.Id,
            code: item.Code__c || '—',
            name: item.Name,
            level: item.Level__c,
            levelLabel: lvl > 0 ? `L${item.Level__c}` : '',
            indentStyle: `padding-left:${0.75 + lvl * 1.1}rem`,
            percentNum,
            percentComplete: `${percentNum}%`,
            progressStyle,
            scheduleVariance: variance,
            varianceClass: variance > 0 ? 'var-late' : variance < 0 ? 'var-ahead' : 'var-ontrack',
            varianceLabel: variance > 0 ? `+${variance}` : String(variance),
            isDelayed,
            isCritical,
            baselineBarStyle,
            currentBarStyle,
            rowClass: isCritical ? 'gantt-row gantt-row--critical' : isDelayed ? 'gantt-row gantt-row--delayed' : 'gantt-row',
            statusBadge: isCritical ? 'Critical' : isDelayed ? 'Delayed' : 'On Track',
            statusClass: isCritical ? 'status-badge status-critical' : isDelayed ? 'status-badge status-delayed' : 'status-badge status-ok'
        };
    }

    _calcBar(startDate, finishDate) {
        if (!startDate || !finishDate) return null;
        const startMs = this._toMs(startDate);
        const finishMs = this._toMs(finishDate) + MS_PER_DAY;
        const left = Math.max(0, ((startMs - this._ganttStartMs) / this._ganttRangeMs) * 100);
        const right = Math.min(100, ((finishMs - this._ganttStartMs) / this._ganttRangeMs) * 100);
        return { left: left.toFixed(2), width: Math.max(0.8, right - left).toFixed(2) };
    }

    _toMs(dateStr) {
        return new Date(dateStr).getTime();
    }

    _dateToPercent(d) {
        return ((d.getTime() - this._ganttStartMs) / this._ganttRangeMs) * 100;
    }

    _fmtDate(ms) {
        return new Date(ms).toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' });
    }

    handleFilter(event) {
        this.filterMode = event.currentTarget.dataset.filter;
    }

    handleClearFilter() {
        this.filterMode = 'all';
    }

    handleRefresh() {
        this._load(true);
    }

    handleNewWBS() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: { objectApiName: 'WBS_Item__c', actionName: 'new' }
        });
    }

    handleRowClick(event) {
        const rowId = event.currentTarget.dataset.id;
        if (rowId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: { recordId: rowId, actionName: 'view' }
            });
        }
    }
}
