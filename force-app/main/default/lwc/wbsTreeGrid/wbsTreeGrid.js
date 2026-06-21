import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getWBSTree from '@salesforce/apex/WBSTreeController.getWBSTree';
import deleteWBSItem from '@salesforce/apex/WBSTreeController.deleteWBSItem';
import runCPM from '@salesforce/apex/WBSTreeController.runCPM';
import saveProgress from '@salesforce/apex/WBSTreeController.saveProgress';
import getDependencies from '@salesforce/apex/WBSTreeController.getDependencies';
import deleteDependency from '@salesforce/apex/WBSTreeController.deleteDependency';
import getTemplates from '@salesforce/apex/WBSTemplateService.getTemplates';
import instantiateTemplate from '@salesforce/apex/WBSTemplateService.instantiate';
import saveAsTemplate from '@salesforce/apex/WBSTemplateService.saveAsTemplate';

const DEP_LABELS = {
    FS: 'Finish-to-Start (FS)',
    SS: 'Start-to-Start (SS)',
    FF: 'Finish-to-Finish (FF)',
    SF: 'Start-to-Finish (SF)'
};

const MONTHS = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
function fmtDate(d) {
    if (!d) return '';
    const m = /^(\d{4})-(\d{2})-(\d{2})/.exec(String(d));
    if (!m) return String(d);
    return `${parseInt(m[3],10)}-${MONTHS[parseInt(m[2],10)-1]}-${m[1].slice(2)}`;
}

function fmtCurrency(v) {
    if (v == null) return '';
    return new Intl.NumberFormat('en-IN', { style: 'currency', currency: 'INR', maximumFractionDigits: 0 }).format(v);
}

export default class WbsTreeGrid extends LightningElement {
    @api recordId;

    @track treeData = [];
    @track showModal = false;
    @track editRecordId;
    @track parentId;
    @track modalTitle = 'New WBS Item';

    // Progress modal state
    @track showProgressModal = false;
    @track progressRecordId;
    @track progressItemName;
    @track sliderValue = 0;
    @track sliderDisplay = 0;
    @track _progressNotes = '';
    @track isSavingProgress = false;

    // Dependency (predecessor) modal state
    @track showDepModal = false;
    @track depWbsItemId;
    @track depWbsItemName;
    @track dependencies = [];
    @track isLoadingDeps = false;
    @track showDepForm = false;
    DEP_TYPE_OPTIONS = [
        { label: 'Finish-to-Start (FS)', value: 'FS' },
        { label: 'Start-to-Start (SS)',  value: 'SS' },
        { label: 'Finish-to-Finish (FF)', value: 'FF' },
        { label: 'Start-to-Finish (SF)', value: 'SF' }
    ];

    // Template modal state
    @track showTemplateModal = false;
    @track templateOptions = [];
    @track selectedTemplateId;
    @track templateAnchorDate;
    @track newTemplateName = '';
    @track isTemplateBusy = false;

    _wiredResult;
    _expandedIds = new Set();
    @track _expandedVersion = 0;

    isLoading = true;
    isCpmRunning = false;
    hasError = false;
    errorMessage;

    @wire(getWBSTree, { projectId: '$recordId' })
    wiredTree(result) {
        this._wiredResult = result;
        this.isLoading = false;
        if (result.data) {
            this.treeData = this._transform(result.data);
            this._expandedIds = new Set();
            this._collectIds(this.treeData);
            this._expandedVersion++;
            this.hasError = false;
        } else if (result.error) {
            this.hasError = true;
            this.errorMessage = result.error.body?.message ?? 'Failed to load WBS data.';
        }
    }

    _transform(nodes) {
        return nodes.map(n => ({
            ...n,
            pct: n.progress ?? 0,
            displayStart: n.earlyStart ?? n.startDate,
            displayEnd:   n.earlyFinish ?? n.endDate,
            children: n.children?.length ? this._transform(n.children) : []
        }));
    }

    _collectIds(nodes) {
        nodes.forEach(n => {
            this._expandedIds.add(n.id);
            if (n.children?.length) this._collectIds(n.children);
        });
    }

    get flatRows() {
        void this._expandedVersion;
        const rows = [];
        this._flatten(this.treeData, rows, 0);
        return rows;
    }

    _flatten(nodes, rows, depth) {
        nodes.forEach(n => {
            const hasChildren = n.children?.length > 0;
            const isExpanded  = this._expandedIds.has(n.id);
            const pct         = n.pct ?? 0;
            const isCritical  = n.isCritical === true;
            const isRoot      = depth === 0;

            const cls = [
                'wbs-row',
                isRoot ? 'wbs-row-root' : (hasChildren ? 'wbs-row-branch' : 'wbs-row-leaf'),
                isCritical ? 'wbs-row-critical' : ''
            ].filter(Boolean).join(' ');

            rows.push({
                id:               n.id,
                depth,
                hasChildren,
                isExpanded,
                name:             n.name,
                wbsCode:          n.wbsCode ?? '',
                durationDays:     n.durationDays ?? '',
                budgetFormatted:  fmtCurrency(n.budget),
                predSummary:      n.predecessorCount > 0 ? `(${n.predecessorCount})` : '',
                floatDisplay:     n.floatDays != null ? String(n.floatDays) : '',
                startFormatted:   fmtDate(n.displayStart),
                endFormatted:     fmtDate(n.displayEnd),
                actualStartFmt:   fmtDate(n.actualStart),
                actualEndFmt:     fmtDate(n.actualFinish),
                progressRaw:      Math.round(pct),
                isCritical,
                rowClass:         cls,
                indentStyle:      `margin-left:${depth * 1.25}rem`,
                toggleIcon:       isExpanded ? 'utility:chevrondown' : 'utility:chevronright',
                codeClass:        ['wbs-code', isRoot ? 'wbs-code-root' : '', isCritical ? 'wbs-code-critical' : ''].filter(Boolean).join(' '),
                nameClass:        ['wbs-name wbs-name-link', isRoot ? 'wbs-name-root' : '', isCritical ? 'wbs-name-critical' : ''].filter(Boolean).join(' '),
                progressFillStyle: `width:${Math.min(pct, 100)}%`,
                progressLabel:    `${Math.round(pct)}%`
            });

            if (hasChildren && isExpanded) {
                this._flatten(n.children, rows, depth + 1);
            }
        });
    }

    get hasData()  { return !this.isLoading && !this.hasError && this.treeData.length > 0; }
    get isEmpty()  { return !this.isLoading && !this.hasError && this.treeData.length === 0; }

    handleToggle(event) {
        const id = event.currentTarget.dataset.id;
        if (this._expandedIds.has(id)) this._expandedIds.delete(id);
        else this._expandedIds.add(id);
        this._expandedVersion++;
    }

    async handleRunCPM() {
        this.isCpmRunning = true;
        try {
            await runCPM({ projectId: this.recordId });
            this.toast('CPM Complete', 'Critical path and progress recalculated', 'success');
            await refreshApex(this._wiredResult);
        } catch (e) {
            this.toast('CPM Error', e.body?.message ?? 'Recalculation failed', 'error');
        } finally {
            this.isCpmRunning = false;
        }
    }

    handleAddRoot() {
        this.editRecordId = undefined;
        this.parentId     = undefined;
        this.modalTitle   = 'New Root WBS Item';
        this.showModal    = true;
    }

    handleAddChild(event) {
        this.editRecordId = undefined;
        this.parentId     = event.currentTarget.dataset.id;
        this.modalTitle   = `Add Child under: ${event.currentTarget.dataset.label}`;
        this.showModal    = true;
    }

    handleEdit(event) {
        this.editRecordId = event.currentTarget.dataset.id;
        this.parentId     = undefined;
        this.modalTitle   = `Edit: ${event.currentTarget.dataset.label}`;
        this.showModal    = true;
    }

    async handleDelete(event) {
        const id   = event.currentTarget.dataset.id;
        const name = event.currentTarget.dataset.label;
        try {
            await deleteWBSItem({ itemId: id });
            this.toast('Deleted', `"${name}" removed`, 'success');
            await refreshApex(this._wiredResult);
        } catch (e) {
            this.toast('Error', e.body?.message ?? 'Delete failed', 'error');
        }
    }

    handleSubmit(event) {
        event.preventDefault();
        const fields = { ...event.detail.fields };
        if (!this.editRecordId) {
            fields.Project__c = this.recordId;
            if (this.parentId) fields.Parent_WBS__c = this.parentId;
        }
        this.template.querySelector('lightning-record-edit-form').submit(fields);
    }

    handleSaveSuccess() {
        this.showModal = false;
        this.toast('Saved', 'WBS item saved successfully', 'success');
        refreshApex(this._wiredResult);
    }

    handleSaveError(event) {
        this.toast('Save Error', event.detail?.message ?? 'Save failed', 'error');
    }

    closeModal() {
        this.showModal    = false;
        this.editRecordId = undefined;
        this.parentId     = undefined;
    }

    // -- Progress modal --
    handleRowClick(event) {
        const id  = event.currentTarget.dataset.id;
        const lbl = event.currentTarget.dataset.label;
        const pct = parseInt(event.currentTarget.dataset.pct ?? '0', 10);

        this.progressRecordId  = id;
        this.progressItemName  = lbl;
        this.sliderValue       = pct;
        this.sliderDisplay     = pct;
        this._progressNotes    = '';
        this.showProgressModal = true;
    }

    handleSliderInput(event) {
        const v = parseInt(event.target.value, 10);
        this.sliderValue   = v;
        this.sliderDisplay = v;
    }

    handleExactInput(event) {
        let v = parseInt(event.target.value, 10);
        if (isNaN(v)) v = 0;
        v = Math.min(100, Math.max(0, v));
        this.sliderValue   = v;
        this.sliderDisplay = v;
    }

    handleNotesInput(event) {
        this._progressNotes = event.target.value;
    }

    async handleProgressSave() {
        this.isSavingProgress = true;
        try {
            await saveProgress({
                itemId:      this.progressRecordId,
                progressPct: this.sliderValue,
                projectId:   this.recordId
            });
            this.showProgressModal = false;
            this.toast('Progress Updated', `${this.progressItemName} -> ${this.sliderValue}%`, 'success');
            await refreshApex(this._wiredResult);
        } catch (e) {
            this.toast('Save Error', e.body?.message ?? 'Failed to save progress', 'error');
        } finally {
            this.isSavingProgress = false;
        }
    }

    closeProgressModal() {
        this.showProgressModal = false;
        this.progressRecordId  = undefined;
        this.progressItemName  = undefined;
    }

    // -- Dependency (predecessor) modal --
    handleManageDeps(event) {
        this.depWbsItemId   = event.currentTarget.dataset.id;
        this.depWbsItemName = event.currentTarget.dataset.label;
        this.showDepForm    = false;
        this.showDepModal   = true;
        this.loadDependencies();
    }

    async loadDependencies() {
        this.isLoadingDeps = true;
        try {
            const rows = await getDependencies({ wbsItemId: this.depWbsItemId });
            this.dependencies = rows.map(d => ({
                ...d,
                predLabel: [d.predecessorCode, d.predecessorName].filter(Boolean).join(' '),
                typeLabel: (this.DEP_TYPE_OPTIONS.find(o => o.value === d.dependencyType) || {}).label
                           || d.dependencyType,
                lagLabel:  d.lagDays ? `${d.lagDays}d lag` : ''
            }));
        } catch (e) {
            this.toast('Error', e.body?.message ?? 'Failed to load dependencies', 'error');
        } finally {
            this.isLoadingDeps = false;
        }
    }

    get hasDependencies()     { return this.dependencies.length > 0; }
    get isDependenciesEmpty() { return !this.isLoadingDeps && this.dependencies.length === 0; }

    handleShowDepForm() {
        this.showDepForm = true;
    }

    handleDepSubmit(event) {
        event.preventDefault();
        const fields = { ...event.detail.fields };
        fields.Successor__c = this.depWbsItemId;
        if (!fields.Dependency_Type__c) fields.Dependency_Type__c = 'FS';
        this.template.querySelector('.dep-edit-form').submit(fields);
    }

    async handleDepSaveSuccess() {
        this.showDepForm = false;
        this.toast('Saved', 'Predecessor added', 'success');
        await this.loadDependencies();
        await this.recalcAfterDepChange();
    }

    handleDepSaveError(event) {
        this.toast('Save Error', event.detail?.message ?? 'Save failed', 'error');
    }

    async handleDepDelete(event) {
        const id    = event.currentTarget.dataset.id;
        const label = event.currentTarget.dataset.label;
        try {
            await deleteDependency({ dependencyId: id });
            this.toast('Deleted', `Predecessor "${label}" removed`, 'success');
            await this.loadDependencies();
            await this.recalcAfterDepChange();
        } catch (e) {
            this.toast('Error', e.body?.message ?? 'Delete failed', 'error');
        }
    }

    async recalcAfterDepChange() {
        try {
            await runCPM({ projectId: this.recordId });
            await refreshApex(this._wiredResult);
        } catch (e) {
            this.toast('CPM Error', e.body?.message ?? 'Recalculation failed', 'error');
        }
    }

    closeDepModal() {
        this.showDepModal   = false;
        this.depWbsItemId   = undefined;
        this.depWbsItemName = undefined;
        this.dependencies   = [];
        this.showDepForm    = false;
    }

    // -- Templates --
    async handleOpenTemplates() {
        this.selectedTemplateId = undefined;
        this.templateAnchorDate = undefined;
        this.newTemplateName    = '';
        this.showTemplateModal  = true;
        try {
            const opts = await getTemplates();
            this.templateOptions = opts.map(o => ({ label: o.name, value: o.id }));
        } catch (e) {
            this.toast('Error', e.body?.message ?? 'Failed to load templates', 'error');
        }
    }

    handleTemplateSelect(event) { this.selectedTemplateId = event.detail.value; }
    handleAnchorChange(event)   { this.templateAnchorDate = event.target.value; }
    handleTemplateNameChange(event) { this.newTemplateName = event.target.value; }
    closeTemplateModal() { this.showTemplateModal = false; }

    async handleApplyTemplate() {
        if (!this.selectedTemplateId) {
            this.toast('Select a template', 'Choose a template to apply', 'warning');
            return;
        }
        this.isTemplateBusy = true;
        try {
            await instantiateTemplate({
                templateId: this.selectedTemplateId,
                projectId: this.recordId,
                anchorStart: this.templateAnchorDate || null
            });
            this.showTemplateModal = false;
            this.toast('Template Applied', 'WBS generated from template', 'success');
            await refreshApex(this._wiredResult);
        } catch (e) {
            this.toast('Error', e.body?.message ?? 'Failed to apply template', 'error');
        } finally {
            this.isTemplateBusy = false;
        }
    }

    async handleSaveAsTemplate() {
        if (!this.newTemplateName) {
            this.toast('Name required', 'Enter a template name', 'warning');
            return;
        }
        this.isTemplateBusy = true;
        try {
            await saveAsTemplate({ projectId: this.recordId, templateName: this.newTemplateName });
            this.showTemplateModal = false;
            this.toast('Saved', `Template "${this.newTemplateName}" created`, 'success');
        } catch (e) {
            this.toast('Error', e.body?.message ?? 'Failed to save template', 'error');
        } finally {
            this.isTemplateBusy = false;
        }
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
