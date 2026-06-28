import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { loadScript } from 'lightning/platformResourceLoader';
import XLSX_JS from '@salesforce/resourceUrl/xlsx_js';
import importTemplate from '@salesforce/apex/WBSTemplateImportService.importTemplate';

const REQUIRED_COLS  = ['code', 'name'];
const PREVIEW_LIMIT  = 8;

const COL_ALIASES = {
    'code':            ['code', 'wbs code', 'wbs#', 'activity code'],
    'name':            ['name', 'activity', 'description', 'activity name', 'task name'],
    'duration':        ['duration', 'duration (days)', 'days', 'typical duration'],
    'budgetPct':       ['budget%', 'budget %', 'budget pct', 'budget percentage', 'budgetpct', 'budget_pct'],
    'controlAccount':  ['control account', 'control_account', 'ca'],
    'discipline':      ['discipline', 'dept', 'department'],
    'predecessorCode': ['predecessor', 'predecessor code', 'pred code', 'pred'],
    'depType':         ['dep type', 'dependency type', 'type', 'dep_type'],
    'lagDays':         ['lag', 'lag days', 'lag (days)', 'lag_days'],
};

export default class WbsTemplateImporter extends NavigationMixin(LightningElement) {
    @track step = 'form';          // form | preview | saving | done
    @track templateName = '';
    @track industry = '';
    @track projectType = '';
    @track description = '';
    @track rows = [];
    @track previewRows = [];
    @track errors = [];
    @track fileName = '';

    xlsxLoaded = false;
    rawRows = [];

    industryOptions = [
        { label: 'Cement / EPC',   value: 'Cement' },
        { label: 'Power',           value: 'Power' },
        { label: 'Oil & Gas',       value: 'Oil & Gas' },
        { label: 'Infrastructure',  value: 'Infrastructure' },
        { label: 'General',         value: 'General' },
    ];
    projectTypeOptions = [
        { label: 'Greenfield',     value: 'Greenfield' },
        { label: 'Brownfield',     value: 'Brownfield' },
        { label: 'Maintenance',    value: 'Maintenance' },
        { label: 'Shutdown',       value: 'Shutdown' },
    ];

    get isFormStep()     { return this.step === 'form'; }
    get isPreviewStep()  { return this.step === 'preview'; }
    get isSaving()       { return this.step === 'saving'; }
    get isDone()         { return this.step === 'done'; }
    get hasErrors()      { return this.errors.length > 0; }
    get canProceed()     { return !!(this.templateName.trim() && this.rows.length > 0 && !this.hasErrors); }
    get cannotProceed()  { return !this.canProceed; }
    get rowCount()       { return this.rows.length; }
    get previewLimited() { return this.rows.length > PREVIEW_LIMIT; }

    connectedCallback() {
        loadScript(this, XLSX_JS)
            .then(() => { this.xlsxLoaded = true; })
            .catch(e => console.error('SheetJS load failed', e));
    }

    // ── form field handlers ────────────────────────────────────────────────
    handleName(e)        { this.templateName = e.detail.value; }
    handleIndustry(e)    { this.industry = e.detail.value; }
    handleProjectType(e) { this.projectType = e.detail.value; }
    handleDescription(e) { this.description = e.detail.value; }

    // ── file upload ────────────────────────────────────────────────────────
    handleFileChange(e) {
        const file = e.target.files[0];
        if (!file) return;
        this.fileName = file.name;
        this.errors = [];
        this.rows = [];

        const isCsv = file.name.toLowerCase().endsWith('.csv');
        const reader = new FileReader();

        reader.onload = (ev) => {
            try {
                if (!this.xlsxLoaded) {
                    this.errors = ['SheetJS is still loading — please try again in a moment.'];
                    return;
                }
                /* global XLSX */
                const wb = XLSX.read(ev.target.result, { type: isCsv ? 'string' : 'array' });
                const ws = wb.Sheets[wb.SheetNames[0]];
                const raw = XLSX.utils.sheet_to_json(ws, { header: 1, defval: '' });
                this.processSheet(raw);
            } catch(err) {
                this.errors = ['Could not parse the file: ' + err.message];
            }
        };
        if (isCsv) reader.readAsText(file);
        else       reader.readAsArrayBuffer(file);
    }

    processSheet(raw) {
        if (!raw || raw.length < 2) {
            this.errors = ['File appears empty — ensure it has a header row and at least one data row.'];
            return;
        }

        // Map header row → canonical keys
        const headerRow = raw[0].map(h => String(h).trim().toLowerCase());
        const colMap = {};
        for (const [canonical, aliases] of Object.entries(COL_ALIASES)) {
            const idx = headerRow.findIndex(h => aliases.includes(h));
            if (idx >= 0) colMap[canonical] = idx;
        }

        const missing = REQUIRED_COLS.filter(c => colMap[c] === undefined);
        if (missing.length) {
            this.errors = [`Missing required column(s): ${missing.join(', ')}. ` +
                `Found: ${headerRow.join(', ')}`];
            return;
        }

        const parsed = [];
        const errs   = [];
        for (let i = 1; i < raw.length; i++) {
            const r = raw[i];
            const code = String(r[colMap['code']] ?? '').trim();
            const name = String(r[colMap['name']] ?? '').trim();
            if (!code && !name) continue;  // skip blank rows
            if (!code) { errs.push(`Row ${i + 1}: missing Code`);  continue; }
            if (!name) { errs.push(`Row ${i + 1}: missing Name`);  continue; }

            parsed.push({
                code,
                name,
                duration:        colMap['duration']        !== undefined ? r[colMap['duration']]        : '',
                budgetPct:       colMap['budgetPct']       !== undefined ? r[colMap['budgetPct']]       : '',
                controlAccount:  colMap['controlAccount']  !== undefined ? r[colMap['controlAccount']]  : '',
                discipline:      colMap['discipline']      !== undefined ? r[colMap['discipline']]      : '',
                predecessorCode: colMap['predecessorCode'] !== undefined ? r[colMap['predecessorCode']] : '',
                depType:         colMap['depType']         !== undefined ? r[colMap['depType']]         : 'FS',
                lagDays:         colMap['lagDays']         !== undefined ? r[colMap['lagDays']]         : '',
                rowNum: i + 1,
            });
        }

        if (errs.length) { this.errors = errs; return; }
        if (!parsed.length) {
            this.errors = ['No valid data rows found after parsing.'];
            return;
        }

        this.rows = parsed;
        this.previewRows = parsed.slice(0, PREVIEW_LIMIT).map((r, i) => ({ ...r, _idx: i }));
    }

    handleNext() {
        if (this.canProceed) this.step = 'preview';
    }

    handleBack() {
        this.step = 'form';
    }

    async handleImport() {
        this.step = 'saving';
        try {
            const result = await importTemplate({
                req: {
                    templateName: this.templateName,
                    industry:     this.industry,
                    projectType:  this.projectType,
                    description:  this.description,
                    rowsJson:     JSON.stringify(this.rows),
                }
            });
            this.step = 'done';
            this.dispatchEvent(new ShowToastEvent({
                title: 'Template Imported',
                message: `"${this.templateName}" created with ${this.rows.length} activities.`,
                variant: 'success',
            }));
            // Navigate to the new template record
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: result,
                    objectApiName: 'WBS_Template__c',
                    actionName: 'view',
                },
            });
        } catch(err) {
            this.step = 'preview';
            this.errors = [err.body?.message || err.message || 'Import failed.'];
        }
    }

    handleCancel() {
        this.dispatchEvent(new CustomEvent('cancel'));
        // If used as a quick action, navigate away
        this[NavigationMixin.Navigate]({ type: 'standard__objectPage',
            attributes: { objectApiName: 'WBS_Template__c', actionName: 'list' },
            state: { filterName: 'Recent' }
        });
    }
}
