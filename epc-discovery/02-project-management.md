# Project Management Module — Deep Dive

The PM module is the backbone of the org. It implements a full **project-controls** model: a `Project__c` with a multi-level **WBS** hierarchy, **Work Packages** for execution, **Daily Progress** capture that drives **Earned Value Management (EVM)**, plus **Change Orders**, **Progress Claims**, **Milestones**, and resource/timesheet tracking. Projects flow through **stage gates G0–G6**.

## Object map & hierarchy

```
Project__c (a00, 29 recs)  ── Account, Project_Manager, Contract
   │  EVM: BAC/EAC/EV/PV/AC, CPI/SPI/CV/SV/VAC · Stage_GateWD__c G0-G6 · Approval_Status
   │
   ├── WBS_Template__c (a0j, 7) ──< WBS_Template_Item__c (a0n, 233)   [reusable WBS blueprint]
   │
   ├── WBS_Item__c (a02, 1,236)  self-parent hierarchy (Level 1→2→3), Control Accounts,
   │      │  EVM per node, Baseline vs Current dates, predecessors, critical path
   │      │
   │      ├── Work_Package__c (a04, 93)  executable scope under a WBS item
   │      │      └── Daily_Progress__c (a07, 59) ──< Resource__c (a0q, 36)
   │      │
   │      ├── Change_Order__c (a06, 12)        scope/cost/schedule changes
   │      ├── Milestone__c (a09, 0)            schedule milestones (empty)
   │      └── (RFI, Submittal, NCR, Punch, Inspection, MR, PO all reference WBS_Item)
   │
   ├── Progress_Claim__c (a0A, 6)   monthly billing/IPC with retention
   ├── Project_Team__c (a0Q, 0)     role assignments (empty)
   ├── Crew__c (a0R, 0)             field crews (empty)
   └── Timesheet__c (a0P, 0) ──< Timesheet_line__c (a0k, 0)   (empty)
```

---

## 1. Project (`Project__c`, prefix `a00`, 29 records)

The project header. Carries the contract/commercial frame, the schedule window, **stage-gate status**, and **rolled-up EVM**.

| Group | Fields |
|---|---|
| **Identity** | `Name` (Project Number), `Project_Code__c`, `Number__c`, `Type__c`, `Contract_Type__c` |
| **Parties** | `Account__c`, `Project_Manager__c`, `Contract__c` (std Contract) |
| **Schedule** | `Start_Date__c`, `End_Date__c` (both **auto-maintained** by the WBS rollup trigger), `Percent_Complete__c` |
| **Stage gates** | `Stage_GateWD__c` = G0/G1/.../G6 · `Stage_Gate__c` (text) · planned gate dates `Planned_G0__c … Planned_G6__c` |
| **Approval** | `Approval_Status__c` = Draft / Submitted / Approved / Rejected / Recall · `Baseline_Frozen__c` |
| **Status** | `Status__c` = Initiation → Planning → Design → Permitting & Approvals → Pre-Construction → Construction (Foundation / Structure / Finishing) → Completed → Closed |
| **Budget** | `Total_Budget__c`, `Baseline_Budget__c`, `BAC__c`, `Current_Forecast__c`, `Actual_Cost__c` |
| **EVM** | `EV__c`/`Earned_Value__c`, `PV__c`/`Planned_Value__c`, `EAC__c`/`Estimate_at_completion__c`, `Cost_Variance__c`, `Schedule_Variance__c`, `Variance_at_completion__c`, `CPI__c`/`Cost_Performance_Index(_Custom)__c`, `SPI__c`/`Schedule_Performance_Index(_Custom)__c` |
| **Commercial** | `LD_Rate__c` (liquidated damages), `Retention_Pct__c` |
| **Template** | `WBS_Template__c` (template used to generate the WBS) |

> Note the duplicated EVM fields (e.g. `EV__c` and `Earned_Value__c`, `CPI__c` and `Cost_Performance_Index__c`). Multiple iterations left parallel fields; confirm which the demo UI binds before presenting numbers.

### Project automation
- **`Project_Initialization`** (flow) — sets up a new project.
- **`EPC Approval Process for Project`** (RecordAfterSave) — drives `Approval_Status__c`.
- **`EPC Stage Gate Guard RTF`** (RecordAfterSave) — enforces stage-gate progression rules (G0→G6).
- WBS rollup (below) writes `Start_Date__c`, `End_Date__c`, `BAC__c` from Level-1 children.
- `EpcProjectHeader` Apex + `epcProjectHeader` LWC render the header KPIs.

---

## 2. WBS Template (`WBS_Template__c` + `WBS_Template_Item__c`)

A **reusable WBS blueprint** so projects don't build a breakdown from scratch.

**`WBS_Template__c`** (7 recs): `Name`, `Project_Type__c` (EPC/EPCM/Construction/Maintenance), `Industry__c` (Oil & Gas / Infrastructure / Manufacturing / Commercial), `Complexity_Level__c`, `Template_Type__c`, `Template_Data__c` (JSON blob, 32k), `Is_Active__c`, `Template_Version__c`, `Duration__c`.

**`WBS_Template_Item__c`** (233 recs): `Code__c`, `Level__c`, `Sequence__c`, `Parent_Template_Item__c` (self-hierarchy), `Work_Type_c__c` (Design/Procurement/Construction/Testing), `Discipline__c`, `Resource_Type__c` (Labor/Material/Equipment/Subcontract), `Budget_Percentage__c`, `Typical_Duration_Days__c`, `Control_Account__c`.

### Generation automation
- **`EPC_WBS_From_Template_Creation` / `_new` / `_SF` / `_Sub_Flow`** (flows) and **`EPC WBS From Template Creation new`** — instantiate `WBS_Item__c` records on a project from a chosen template.
- Apex `WBSTemplateService`, `WBSItemCreator`, `WBSController` support the builder.
- LWC `epcWbsBuilder`, `epcWbsBuilderAdvanced` provide the interactive builder UI.

---

## 3. WBS Item (`WBS_Item__c`, prefix `a02`, **1,236 records** — the most-used PM object)

A node in the work breakdown structure. Self-referencing hierarchy (`Parent_WBS__c`) with `Level__c` 1/2/3, optional **Control Account** flag, schedule, and per-node EVM.

| Group | Fields |
|---|---|
| **Identity / tree** | `Name` (WBS Code), `Code__c`, `Name__c`, `Level__c`, `Parent_WBS__c`, `parent_level__c`, `Sequence__c`, `Size__c`, `Project__c`, `Control_Account__c` |
| **Schedule** | `Baseline_Start__c`, `Baseline_Finish__c`, `Current_Start__c`, `Current_Finish__c`, `Duration__c`, `Predecessor__c`, `Predecessor_Type__c` (FS/SS/FF), `Add_days__c`, `Critical_Path__c`, `Is_Actual_Start_Date_Crossed_vs_planned__c` |
| **EVM** | `BAC__c`, `PV__c`, `EV__c`, `AC__c`, `CPI__c`, `SPI__c`, `Percent_Complete__c`, `Last_EV_Update__c` |
| **Scope** | `Planned_Quantity__c`, `UoM__c`, `Discipline__c` (Civil/Mechanical/Electrical/Instrumentation/Structural/E&M), `Resource__c` (User) |
| **AI** | `AI_Insight__c` (32k) — populated by the AI Insight flows (below) |

### WBS rollup trigger (`WBSItemTriggerHandler`)
Bottom-up rollup of **dates + budget** through the hierarchy whenever a child's `Baseline_Start__c`/`Baseline_Finish__c` changes:

```
Level 3 child changes ──► recompute Level 2 parent  (MIN start, MAX finish, SUM BAC, Duration)
Level 2 child changes ──► recompute Level 1 parent  (MIN start, MAX finish, SUM BAC, Duration)
Level 1 changes       ──► recompute Project__c       (Start_Date, End_Date, BAC = SUM)
```
Uses aggregate SOQL grouped by parent (bulk-safe). Duration = `daysBetween(min,max)+1` (inclusive).

### WBS automation (flows)
- **`RTF_Duration&predecessorFLOW`** (RecordBeforeSave) — computes dates from `Duration__c` + `Predecessor__c`.
- **`RTF_WorkpackagestartDateUpdate`**, **`RTF_CalculatePercentage`** — schedule/percent updates.
- **`WBS AI Insight`** (PromptFlow) + **`WBS Item AI Insight Update`** (RecordAfterSave) — generate `AI_Insight__c` narratives.

### WBS UI
`epcWbsBuilder`, `epcWbsBuilderAdvanced` (builder), `epcGanttChart` (Gantt), `epcTimeline`, FlexiPage `WBS_Item_Record_Page`.

---

## 4. Work Package (`Work_Package__c`, prefix `a04`, 93 records)

The executable unit of scope under a WBS item — what a crew/subcontractor actually delivers and reports against.

| Group | Fields |
|---|---|
| **Identity** | `Name`/`Number__c`, `Package_Name__c`, `Description__c` |
| **Links** | `Project__c`, `WBS_Item__c`, `Material_Requisition__c`, `RFI__c`, `Crew__c` (User), `Package_Manager__c` (MEP Engineer/Structural Lead/Civil Engineer) |
| **Scope** | `Discipline__c`, `Planned_Qty__c`, `Planned_Uom__c`/`Unit__c` (EA/LF/SF/CY/TON/KG …), `Location__c`, `Resource_type__c` (Subcontractor/Equipment) |
| **Schedule** | `Start_Date__c`, `End_Date__c`, `Planned_duration__c` |
| **Status / progress** | `Status__c` = Not Started / Planned / In_Progress / On_Hold / Completed · `Percent_Complete__c`, `Progress__c` |
| **Cost** | `Budget__c`, `Actual_Cost__c` |

UI: `epcWorkPackageKanban` (kanban board), `EPCWorkPackageService` Apex, multiple `Work_Package_Record_Page` variants.

---

## 5. Earned Value Management (EVM) engine

The org computes EVM bottom-up from physical progress. Two layers:

### Compute layer — `EVCalculator` (Queueable)
`EVCalculator.enqueue(projectId)` runs asynchronously:
1. **Leaf WBS items:** `Percent_Complete = Σ Daily_Progress.Qty_Installed / Planned_Quantity × 100`; `EV = BAC × %Complete/100`; `PV` = time-phased linear interpolation between `Baseline_Start`/`Baseline_Finish`; `AC = Σ PO_Line.Extended_Price` for that WBS item.
2. **Parent WBS items:** roll up EV/PV/AC/BAC from children, %Complete = weighted average.
3. **Indices per node:** `SPI = EV/PV`, `CPI = EV/AC`.
4. Recursively re-enqueues parent recalculation.

> **Caveat for demo:** the project-level write-back block in `EVCalculator.calculateProjectLevelEV()` is **commented out** — it sums but does not persist to `Project__c`. Actual cost only pulls `PO_Line` (timesheet cost is a TODO).

### Read layer — `EPCEVMService` (LWC-facing, cacheable)
- `getEVMData(projectId)` → `{PV, EV, AC, CPI, SPI}` summed live from WBS items.
- `calculateEVM(wbsItemId)` → per-node PV/EV/AC.
- `calculateProgress(projectId)` → `{totalBudget, totalProgress, progressPercentage}`.

### EVM UI
`epcEVM` (KPI cards), `epcSCurve` (S-curve PV/EV/AC over time), `epcStageGateIndicator`, surfaced on `Project_Command_Center`. `EVDataController` supports the data feed.

---

## 6. Daily Progress (`Daily_Progress__c`, prefix `a07`, 59 records)

Field progress capture — the **source of physical %-complete that feeds EVM**.

Fields: `Date__c`, `Project__c`, `Work_Package__c`, `WBS_Item__c`, `Resource__c`, `Qty_Installed__c`, `Actual_Quantity__c`/`Planned_Quantity__c`, `Percent_Complete_Day__c`, `Hours_Worked__c`, `Crew_Size__c`, `Equipment_Hours__c`, `Total_Earned_Value__c`, `Weather__c`, `Safety_Incidents__c`, `Quality_Issues__c`, `Material_Shortages__c`, `Delays__c`, `Submitted_By__c`, `Approved_By__c`.

**Logic (`EPCDailyProgressService`):**
- `saveDailyProgress(record, materialLines)` — transactional (savepoint): inserts the Daily Progress, then **updates linked `Resource__c`** records, accumulating `Quantity_Used__c` and stamping `Daily_Progress__c`/`Work_Package__c`/`Product__c`. Requires Project + Work Package + Date.
- `getAllProjects`, `getProjectRelatedWBSItems` (returns Work Packages), `getDailyProgress` (delegates to `EPCSiteExecutionController`).

**Automation:**
- **`EPC Daily Progress Update EV RTF`** (RecordAfterSave) — recalculates EV when progress is logged.
- **`EPC_RTF_updateDailyProgress`** (RecordAfterSave).

**UI:** `epcDailyProgressCapture`, `epcDailyProgressForm`, `epcDailyProgressLite`, `epcSiteExecutionBoard`, `epcMobileDashboard`, `epcPhotoUpload` (site photos). Workspace: `Site_Execution_Workspace`. Apex `EPCSiteExecutionController`, `EPCMobileDashboardService`.

---

## 7. Change Order (`Change_Order__c`, prefix `a06`, 12 records)

Scope/cost/schedule variations against a project/WBS item.

Fields: `Project__c`, `WBS_Item__c`, `Type_of_Change__c` (Scope/Cost/Schedule), `Status__c` (Proposed/Under Review/Approved/Rejected), `Approval_Status__c` (Draft/Submitted/Approved/Rejected), `Reason__c`, `Justification__c`, `Description__c`, `Value__c`/`Estimated_Additional_Cost__c`/`Impact_Cost__c`, `Budget__c`, `Impact_Days__c`/`Variance_Days__c`, `Revised_End_Date__c`, `Approved_By__c`, `Approved_On__c`.

**Automation:** **`RTF_updatebudjectfromchangeorder`** (RecordAfterSave) — pushes approved change-order value into the project/WBS budget. Apex `EPCChangeOrderService`; LWC `epcChangeOrderConsole`, `epcChangeCostRoom`, `epcChangeCostRoomtwo`.

---

## 8. Progress Claim (`Progress_Claim__c`, prefix `a0A`, 6 records)

Monthly billing / Interim Payment Certificate with retention handling.

Fields: `Project__c`, `Subcontract__c` (lookup→Project), `Period__c`, `Claim_Date__c`, `Amount__c`, `Base_Claim__c`, `Net_Claim__c`, `Retention_Held__c`, `Retention_Pct__c`, `Status__c` (Draft/Submitted/Under Review/Approved/Rejected), `Oracle_Invoice_ID__c` (ERP integration ref).

**Automation:** **`EPC_ProgressClaim_Monthly_Sched`** (RecordAfterSave) — monthly claim generation. Retention logic in `RetentionEngine` Apex. Oracle invoice id implies ERP push.

---

## 9. Resources, Crews, Teams, Timesheets

| Object | Recs | Role |
|---|---|---|
| `Resource__c` (a0q) | 36 | Material/labour consumed against a Work Package & Daily Progress (`Quantity`, `Quantity_Used__c`, `Hours_Worked__c`, links to `Product2`) |
| `Project_Team__c` (a0Q) | 0 | Project role assignments — `Role__c` = PM/QS/Planner/QAQC/HSE/Buyer/Engineer/Supervisor (**empty**) |
| `Crew__c` (a0R) | 0 | Field crews by discipline + supervisor (**empty**) |
| `Timesheet__c` (a0P) | 0 | Weekly timesheet header → `Project`/`WBS_Item`/`Work_Package`, approval workflow (**empty**) |
| `Timesheet_line__c` (a0k) | 0 | Daily hour lines (**empty**) |

**Automation present even where data is empty:** `EPC Timesheet Approval RTF` (RecordAfterSave), `ResourceAssignmentHandler` Apex, `resourceAllocation` / `resourceAssignmentModal` LWC.

> **Demo caution:** Timesheets, Crews, Project Teams, Milestones are **built but unpopulated**. Show them as configured capability, not live data.

---

## Demo cheat-sheet (PM)

1. **Project Command Center** (`Project_Command_Center`) — open a project (29 available), show stage gate G0–G6, EVM KPI cards (`epcEVM`), S-curve (`epcSCurve`).
2. **WBS** — `epcWbsBuilder`/`epcGanttChart` show the 1,236-node hierarchy with baseline vs current dates, critical path, AI Insight.
3. **Generate WBS from template** — pick a `WBS_Template__c` → flow instantiates the breakdown.
4. **Work Packages** — `epcWorkPackageKanban` board by status.
5. **Site execution** — `epcDailyProgressCapture`/`epcSiteExecutionBoard`: log Qty Installed → triggers EV recalc → KPIs move.
6. **Change Orders / Progress Claims** — show variation → budget update, and monthly claim with retention.
7. **EVM math** — explain bottom-up EV from Daily Progress (note `EVCalculator` is Queueable; project-level persistence is partially commented out — read live numbers from `EPCEVMService`).
