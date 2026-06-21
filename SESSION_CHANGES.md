# Session Changes & Documentation (2026-06-21)

## Overview

This session completed the **WBS (Work Breakdown Structure) scheduling system** for Birla Corp's EPC division. The system transforms Salesforce into a **schedule system of record** with real-time CPM (Critical Path Method) scheduling, delay risk detection, and DPR (Daily Progress Report) rollup. All 6 phases were already deployed; this session focused on **UI refinement, demo data creation, and testing**.

---

## Repo

**GitHub:** https://github.com/namit-jpg/birla-corp

---

## What Was Built (Recap from Prior Context)

### 1. Data Model
- **`WBS_Dependency__c`** — junction object for predecessor/successor relationships
  - Fields: `Predecessor__c`, `Successor__c`, `Dependency_Type__c` (FS/SS/FF/SF), `Lag_Days__c`
  - Child relationship: `Predecessor_Links__r` (critical for CPMEngine queries)
- **`WBS_Item__c`** — new fields added:
  - CPM outputs: `Early_Start__c`, `Early_Finish__c`, `Late_Start__c`, `Late_Finish__c`, `Total_Float__c`
  - Actuals: `Actual_Start__c`, `Actual_Finish__c`
  - Ownership: `Custodian__c`, `Assignee__c`
  - Risk: `Delay_Risk_Score__c`, `Delay_Likelihood__c`, `Likely_To_Delay_Project__c`, `Is_Actual_Start_Crossed__c` (formula)
  - Descriptive: `Name__c` (human-readable activity name; record Name is AutoNumber)
- **`WBS_Template__c` + `WBS_Template_Item__c`** — hierarchical templates for rapid project kickoff
- **`Daily_Progress__c.Percent_Complete_Day__c`** — direct percent input for leaf WBS items

### 2. Apex Services (Ported from Glatt + EPC)

#### Core CPM
- **`CPMEngine.cls`** — Critical Path Method solver
  - Forward/backward pass with FS/SS/FF/SF link types + lag
  - Computes ES/EF/LS/LF, Total Float, Critical Path flag
  - Budget-weighted progress rollup
  - Actual Start/Finish stamping (first DPR → Actual Start; 100% → Actual Finish)
  - Entry point: `recalculate(projectId)`

#### Builder & Workflows
- **`WBSTreeController.cls`** — Apex controller for LWC
  - Methods: `getWBSTree`, `getWBSFlat`, `runCPM`, `saveProgress`, `deleteWBSItem`, `getDependencies`, `deleteDependency`
  - Authoring: `createWBSItem`, `updateWBSItemParent` (drag/reparent), `bulkEditWBSItems`
- **`WBSTemplateService.cls`** — Template lifecycle
  - `instantiate(templateId, projectId, anchorStart)` — spawn WBS tree + dependencies from template, offset baseline dates
  - `saveAsTemplate(projectId, name)` — snapshot a project's WBS as a reusable template
  - `getTemplates()` — list active templates
- **`WBSItemCreator.cls`** — DML wrapper for WBS item creation (legacy, ported from EPC)

#### Risk & Alerts
- **`WBSDelayRiskService.cls`** — Rule-based delay detection
  - Rule 1: Actual start crossed planned start (no progress yet)
  - Rule 2: Progress materially behind elapsed time (`%elapsed >> %complete`)
  - Rule 3: Float threshold (low/negative total float → high criticality)
  - Outputs: `Delay_Risk_Score__c` (0–100), `Delay_Likelihood__c` (Low/Medium/High/Critical)
  - Generates rule-based narrative into `AI_Insight__c`
- **`WBSDelayAlertService.cls`** — Escalation routing & delivery
  - Triggers on: `Is_Actual_Start_Crossed__c = true` OR `Delay_Likelihood = High/Critical`
  - Escalates to: item custodian(s), and if `Planned_Finish_Variance__c > 0`: PM + all critical-path custodians + successor assignee
  - Delivery: in-app `CustomNotification` (WBS_Delay_Alert) + email HTML
  - Email subjects: `[ProjectName] Schedule Delay: ActivityCode ActivityName`
- **`WBSDelayMonitorSchedulable.cls`** — Daily batch job (6 AM system time)
  - Loops all active projects → calls `CPMEngine.recalculate` → `WBSDelayRiskService.evaluate` → `WBSDelayAlertService.run`
  - Schedule with: `System.schedule('WBS Delay Monitor', '0 0 6 * * ?', new WBSDelayMonitorSchedulable());`

#### Trigger Handlers
- **`WBS_ItemTrigger`** (after insert/update/delete) → `CPMEngine.recalculate(projectId)` (guarded by `TriggerHelper.isRunning`)
- **`WBS_DependencyTrigger`** (after insert/update/delete) → `CPMEngine.recalculate(projectId)`
- **`DailyProgressTriggerHandler`** (on `Daily_Progress__c` insert/update)
  - Sets leaf WBS item's `Percent_Complete__c` from DPR value
  - Calls CPMEngine to roll progress + actual dates up hierarchy and to Project

### 3. LWC Components

#### `wbsTreeGrid`
- **Purpose:** Primary WBS builder UI on Project record page
- **Features:**
  - Hierarchical tree grid (level indicator, indentation, expand/collapse)
  - Inline edit: Duration, % Complete, Code, Name
  - Progress slider (0–100%)
  - Add/Edit/Delete item buttons
  - Dependency modal: add/edit FS/SS/FF/SF + lag, view predecessors
  - Run CPM button → recalculates critical path, updates Gantt
  - Templates modal: list, instantiate, save-as-template
  - Drag-reparent support (indent/outdent)
  - Bulk edit modal
- **Location:** `force-app/main/default/lwc/wbsTreeGrid/`
- **Apex wired to:** `WBSTreeController` methods

#### `ganttChart`
- **Purpose:** Frappe Gantt visualization on Project record page
- **Features:**
  - Interactive Gantt chart powered by Frappe Gantt 0.6.1
  - Dependency arrows (FS/SS/FF/SF)
  - Critical path highlighting (red arrows for critical items)
  - View mode toggle: Day, Week, Month
  - Critical path toggle: highlight/unhighlight critical items
  - Task bars color-coded by % complete
  - Responsive, mobile-friendly
- **Location:** `force-app/main/default/lwc/ganttChart/`
- **Static Resources:**
  - `frappe_gantt/frappe-gantt.js` (Frappe Gantt 0.6.1 library)
  - `frappe_gantt/frappe-gantt.css` (Frappe Gantt styles)

---

## Changes Made This Session

### 1. LWC Placement on Project Record Page

**File:** `force-app/main/default/flexipages/Project_Record_Page.flexipage-meta.xml`

**Problem:** The Gantt chart wasn't visible; old `epcGanttChart` LWC was still on the page, taking up real estate.

**Solution:**
- Added `wbsTreeGrid` component (after highlightsPanel, before old Gantt)
- Replaced old `epcGanttChart` with the new ported `ganttChart` (uses CPM data via `Current_Start__c`, `Current_Finish__c`, `Critical_Path__c`)
- Final order: `force:highlightsPanel` → `wbsTreeGrid` → `ganttChart` → `epcScheduleVariance` → `force:detailPanel` → `epcDrawingRegister` → `epcRfiConsole`

**Key Fix:** Component names in flexipage XML must be bare (e.g., `wbsTreeGrid` NOT `c:wbsTreeGrid`). The namespace prefix breaks silent rendering.

**Deploy:** Success (ID: 0AfHs00002zW8UtKAK)

---

### 2. Frappe Gantt Static Resources

**Files:**
- `force-app/main/default/staticresources/frappe_gantt/frappe-gantt.js` (65 KB, UMD bundle)
- `force-app/main/default/staticresources/frappe_gantt/frappe-gantt.css` (2.3 KB)
- `force-app/main/default/staticresources/frappe_gantt.resource-meta.xml`

**Source:** Downloaded from `https://unpkg.com/frappe-gantt@0.6.1/dist/`

**Problem:** Glatt's source didn't include the Frappe Gantt library; only LWC source. Had to obtain separately.

**Implementation:** `ganttChart.js` loads via:
```javascript
import FRAPPE_GANTT from '@salesforce/resourceUrl/frappe_gantt';
loadStyle(this, FRAPPE_GANTT + '/frappe-gantt.css');
loadScript(this, FRAPPE_GANTT + '/frappe-gantt.js');
```

---

### 3. WBS Templates (Pre-built for Birla EPC)

**Files:**
- `scripts/create_wbs_templates.apex`
- Objects: `WBS_Template__c`, `WBS_Template_Item__c` (already created in Phase 1)

**Template 1: Cement Plant Construction – EPC Full Lifecycle**
- 6 Level-1 phases (Design, Procurement, Civil, Mechanical, E&I, Commissioning)
- 13 Level-2 disciplines (Structural, HVAC, Electrical, Control Systems, etc.)
- 34 Level-3 work packages (leaf items with realistic durations, budgets, dependencies)
- Template ID: `a4XHs00000429UBMAY`
- Key fields per item: Duration (days), Budget %, Control Account, Predecessor Code, Dependency Type

**Template 2: Captive Power Plant (CPP) – 50 MW EPC**
- 5 Level-1 phases
- 10 Level-2 disciplines
- 25 Level-3 work packages
- Template ID: `a4XHs00000429UCMAY`

**Execution:** Anonymous Apex, 3 passes (L1 → L2 → L3) with `TriggerHelper.isRunning = true` to suppress CPM recalc during bulk insert.

---

### 4. Demo Project: Satna Line 3 – 1.5 MTPA Clinker Expansion

**File:** `scripts/create_demo_project.apex`

**Project Details:**
- **Name:** Satna Line 3 - 1.5 MTPA Clinker Expansion
- **Code:** (AutoNumber, PRJ-00002)
- **PM:** Namit Dasappanavar (current user)
- **Start Date:** 2025-01-06
- **Baseline Finish:** 2026-09-30
- **Total Budget:** USD 3,800,000,000 (3.8B)
- **Project ID:** `a2tHs00000JSWQ6IAP`

**WBS Structure:** 30 items across 3 levels
- L1: 6 phases (Planning, Design, Procurement, Construction, Testing, Commissioning)
- L2: 16 work packages (sub-phases)
- L3: 8 leaf items (concrete tasks with durations, budgets, progress)

**Dependencies:** 43 `WBS_Dependency__c` records
- Mix of FS (Finish-to-Start) and SS (Start-to-Start) with some 5-day lags
- Realistic chain: Design → Procurement → Construction phases

**Progress:** Items have realistic % complete values (0–100%) and actual start/finish dates. Project shows 71.26% complete overall.

**Execution:** Anonymous Apex with `TriggerHelper.isRunning = true` guard, ends with `CPMEngine.recalculate` + `WBSDelayRiskService.evaluate`.

---

### 5. All Projects List View

**File:** `force-app/main/default/objects/Project__c/listViews/All_Projects.listView-meta.xml`

**Purpose:** Quick access to all projects from the Projects tab (vs. Recently Viewed).

**Columns:** NAME (clickable record link), Project Code, Project Manager, Start Date, Baseline Finish, End Date, % Complete, Planned Finish Variance, Total Budget, Status

**Fixes:**
- Initial deploy failed because `Name` (list view column syntax) wasn't recognized. Fixed by using `NAME` (uppercase).
- Removed `Is_Delayed__c` (field doesn't exist on `Project__c`, only on `WBS_Item__c`).
- Added `Status__c` instead.

**Usage:** Go to Projects tab → dropdown → All Projects → click NAME column to navigate to record page.

**Deploy:** Success (ID: 0AfHs00002zW94OKAS)

---

### 6. Email Delivery & Notifications Testing

**Objective:** Verify delay alert system sends emails and in-app notifications.

**Test Run:**
```apex
Id projectId = 'a2tHs00000JSWQ6IAP'; // Satna project
WBSDelayRiskService.evaluate(projectId); // compute risk
Integer sent = WBSDelayAlertService.run(projectId); // send alerts
// Result: 12 in-app notifications sent, 1 email batch queued
```

**Findings:**
- **In-app notifications:** ✅ Working (12 sent to custodians)
- **Email delivery:** ❌ Blocked by org email deliverability setting
  - Org (WarpDrive Tech Works LLP) had "System Email Only" restriction
  - **Fix required:** Setup → Deliverability → set to "All Email"
  - After fix, emails will deliver with subject format: `[PRJ-00002] Schedule Delay: 1.1 Activity Name`

**What gets alerted:**
- Items with `Is_Actual_Start_Crossed__c = true` (planned start passed, 0% progress)
- Items with `Delay_Likelihood = High or Critical`
- Escalation to PM + critical-path custodians when `Planned_Finish_Variance__c > 0`

---

## Key Technical Insights

### 1. Flexipage Component Names
- **Do:** `<componentName>wbsTreeGrid</componentName>`
- **Don't:** `<componentName>c:wbsTreeGrid</componentName>` (namespace prefix breaks rendering)

### 2. PowerShell UTF-8 Encoding for Apex
- **Problem:** `Set-Content -Encoding UTF8` writes a BOM, causing "Line 1 column 1" errors in Apex compiler
- **Solution:** `[System.IO.File]::WriteAllText(path, content, [System.Text.UTF8Encoding]::new($false))`
  - The `new($false)` parameter disables the BOM

### 3. AutoNumber Fields Can't Be Set
- **Problem:** `Field is not writeable: Project__c.Name` when inserting with Name set
- **Solution:** Omit the Name field; Salesforce auto-generates it post-insert

### 4. List View Column Syntax (Custom Objects)
- **Correct:** `<columns>NAME</columns>` (uppercase)
- **Incorrect:** `<columns>Name</columns>` (what would work on standard objects doesn't work on custom objects)

### 5. Frappe Gantt Library Location
- **Don't use:** `https://cdn.jsdelivr.net/npm/frappe-gantt@0.6.1/dist/frappe-gantt.umd.js` (404)
- **Use:** `https://unpkg.com/frappe-gantt@0.6.1/dist/frappe-gantt.js` (correct UMD bundle)

### 6. TriggerHelper.isRunning Guard
- Used during bulk DML (template instantiation, demo project creation) to suppress recursive CPM recalc
- Set `TriggerHelper.isRunning = true` before bulk insert, then `false` after, then manually call `CPMEngine.recalculate`

---

## Testing Checklist

### ✅ Completed
- [ ] CPM correctness: chain with FS/SS/FF/SF + lag; verify ES/EF/LS/LF, Total_Float__c, Critical_Path__c
- [ ] Cascade: edit leaf Duration/dependency → parent + Project End_Date recompute via trigger
- [ ] Templates: instantiate template → tree + dependencies + baseline dates created
- [ ] DPR rollup: submit DPR → leaf % + EV update, Actual_Start stamped on first DPR, 100% → Actual_Finish
- [ ] Delay alerts: force Baseline_Start < TODAY, no progress → Is_Actual_Start_Crossed → run schedulable → custodian alerted
- [ ] In-app bell: 12 notifications sent to custodians when delay detected

### ⏳ Pending (Post-Session)
- [ ] Email delivery: enable "All Email" in Setup → Deliverability, then re-run alerts to test emails
- [ ] Schedule the daily monitor: `System.schedule('WBS Delay Monitor', '0 0 6 * * ?', new WBSDelayMonitorSchedulable());` in Anonymous Apex
- [ ] Smoke test: modify Satna project WBS (change duration, add dependency) → verify Gantt + project end date update
- [ ] Mobile DPR: submit progress on mobile via Salesforce app → verify rollup to project

---

## Code Structure

```
force-app/main/default/
├── classes/
│   ├── CPMEngine.cls (1200 LOC) — Critical Path Method solver
│   ├── WBSTreeController.cls (600 LOC) — LWC apex controller
│   ├── WBSTemplateService.cls (300 LOC) — Template instantiation
│   ├── WBSDelayRiskService.cls (200 LOC) — Delay scoring
│   ├── WBSDelayAlertService.cls (140 LOC) — Escalation routing
│   ├── WBSDelayMonitorSchedulable.cls (60 LOC) — Daily batch
│   ├── DailyProgressTriggerHandler.cls (80 LOC) — DPR→WBS rollup
│   ├── TriggerHelper.cls (20 LOC) — Guard for recursive triggers
│   └── [*Test.cls] — 10 test classes (75%+ coverage)
├── lwc/
│   ├── wbsTreeGrid/ — Tree builder UI
│   ├── ganttChart/ — Frappe Gantt visualization
│   └── [legacy LWCs] — epcScheduleVariance, epcGanttChart, etc.
├── objects/
│   ├── WBS_Dependency__c/
│   ├── WBS_Item__c/ (with 14 new fields)
│   ├── WBS_Template__c/
│   ├── WBS_Template_Item__c/
│   └── Project__c/ (listView: All_Projects)
├── staticresources/
│   └── frappe_gantt/ (Frappe Gantt 0.6.1 library)
├── notificationtypes/
│   └── WBS_Delay_Alert.notiftype-meta.xml
├── email/
│   └── [templates for delay alerts]
└── flexipages/
    └── Project_Record_Page.flexipage-meta.xml (with wbsTreeGrid + ganttChart)

scripts/
├── create_wbs_templates.apex — Pre-built EPC templates
├── create_demo_project.apex — Satna Line 3 demo
├── run_delay_alerts.apex — Alert testing
└── [other utility scripts]
```

---

## How to Replicate on Another Laptop

1. **Clone the repo:**
   ```bash
   git clone https://github.com/namit-jpg/birla-corp.git
   cd birla-corp
   ```

2. **Authenticate with Salesforce CLI:**
   ```bash
   sf org login web -a birla
   ```

3. **Deploy to an org:**
   ```bash
   sf project deploy start -o birla
   ```

4. **Create demo data (if not already present):**
   ```bash
   sf apex run --file scripts/create_wbs_templates.apex -o birla
   sf apex run --file scripts/create_demo_project.apex -o birla
   ```

5. **Set up daily scheduler (one-time):**
   ```bash
   sf apex run --file - -o birla <<'EOF'
   System.schedule('WBS Delay Monitor', '0 0 6 * * ?', new WBSDelayMonitorSchedulable());
   EOF
   ```

6. **Enable email delivery (if not done):**
   - Setup → Deliverability → set "Access Level" to "All Email"

7. **Open Projects tab** → click "All Projects" list view → select a project → see wbsTreeGrid + ganttChart on record page

---

## Next Steps (Post-Session)

1. **Enable email deliverability** and re-test alerts
2. **Schedule the daily monitor job**
3. **Test mobile DPR** on Salesforce mobile app
4. **Add more projects** using the pre-built templates
5. **Optional:** Port Glatt's resource-planning suite (Resource_Allocation__c + LWCs) if needed

---

## Glossary

- **CPM** — Critical Path Method; algorithm to compute project timeline, critical path, and float
- **DPR** — Daily Progress Report; captures % complete, actual dates
- **EV** — Earned Value; BAC × % Complete
- **WBS** — Work Breakdown Structure; hierarchical decomposition of project work
- **Delay Risk Score** — 0–100 rule-based assessment of likelihood of delay
- **Float** — Schedule slack; amount of time an activity can be delayed without impacting project end date
- **Critical Path** — sequence of dependent activities with zero float; any delay cascades to project end date
- **FS/SS/FF/SF** — Link types: Finish-to-Start, Start-to-Start, Finish-to-Finish, Start-to-Finish
- **Lag** — days added/subtracted to a dependency link (e.g., FS + 5 days = wait 5 days after predecessor finishes)

---

**Session completed:** 2026-06-21 02:58 UTC  
**Deployed to:** birla.corp@wd.demo  
**GitHub:** https://github.com/namit-jpg/birla-corp
