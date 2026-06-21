# EPC Project Management & Execution — PoC Build Plan (Birla Org)

> **Purpose:** Build a working Salesforce PoC on the **birla** org that demonstrates the capabilities confirmed in *"Project Mgm. Platform Datasheet - WarpDrive Response.xlsx"* for RCCPL (Birla Corp). Scope = **all functional sections (1–7, 9) except external integrations**. Each Work Package (WP) below is **self-contained and built in its own thread**.
>
> **Source of truth for proven designs:** the existing WarpDrive **EPC org** (alias `epc`), fully documented in `./epc-discovery/`. We are doing a **clean fresh build** — reuse the EPC designs as reference but drop the cruft (duplicate fields, dead picklists, commented-out code).

---

## 1. Context & decisions (locked)

| Decision | Value |
|---|---|
| Target org | **birla** (`sf ... -o birla`) — WarpDrive Tech Works LLP, Enterprise Edition, prod-style demo org |
| Build style | **Clean fresh build** (new metadata, not ported from EPC org) |
| Object naming | **Clean names, no prefix** (verified no collisions in birla: `Project__c`, `WBS_Item__c`, `RFI__c`, etc.) |
| Scope | Functional sections 1–7 + 9. **Excluded:** all integration rows (1.1/1.2 MSP/P6, 2.5 live carrier, 8.12–8.16 SAP/MSP/P6/PowerBI/SCADA). Build SF-native equivalents only. |
| Datasheet sections 10 & 11 | Not built (vendor/commercial — sales team) |
| Development model | Orchestrator (this/parent model) **delegates atomic build tasks to lower-model subagents** (Haiku/Sonnet) via the Agent tool — see §4 |

### Carried-forward risk flags (from datasheet — keep visible to client)
- **On-prem (8.1):** not possible — Salesforce is cloud-only. Not a build item; positioning only.
- **Critical Path / CPM (1.6):** we visualize & track critical path; true CPM engine = P6/MSP integration (out of PoC).
- **Offline (8.5):** only Field Service mobile is truly offline; scope mobile demo as online.
- **SCADA/DCS/OPC (8.16):** middleware-only, not native; out of PoC.
- **Licensing/TCO (8.9, 11.x):** per-named-user cost — commercial, not technical.

---

## 2. Target architecture

```
                         ┌─────────────────────────────────────────────┐
   App: "EPC Execution"  │  Project__c  (stage gates, EVM rollup)       │
   Perm set: EPC_PoC      │     │                                        │
                          │     ├── WBS_Item__c (L1-3 hierarchy, EVM)    │
                          │     │      ├── Work_Package__c               │
                          │     │      │     └── Daily_Progress__c       │
                          │     │      ├── Milestone__c                  │
                          │     │      └── Change_Order__c               │
                          │     ├── Engineering: Drawing__c, Document_   │
                          │     │   Revision__c, Submittal__c, RFI__c,   │
                          │     │   Transmittal__c, Interface__c         │
                          │     ├── Procurement: Material_Requisition__c,│
                          │     │   RFQ__c, Purchase_Order__c,           │
                          │     │   Goods_Receipt__c, Progress_Claim__c  │
                          │     ├── Quality: ITP__c, Inspection__c,      │
                          │     │   NCR__c, Pour_Card__c, Weld_Record__c,│
                          │     │   Calibration__c                       │
                          │     ├── HSE: Permit_to_Work__c, Observation__c,│
                          │     │   Incident__c, Toolbox_Talk__c, HIRA__c│
                          │     └── Comm/Handover: Completion__c,        │
                          │         Punch_List_Item__c, Handover_Package__c│
                          └─────────────────────────────────────────────┘
                                   Reporting (sec 9): reports + dashboards
                                   AI (8.17): Agentforce agent (stretch)
```

### Shared conventions (every WP must follow)
- **Auto-number Name** on transactional objects (e.g. `RFI-{0000}`), `Text` Name on config objects.
- **Standard picklists** reused across objects: `Discipline` = Civil; Mechanical; Electrical; Instrumentation; Piping; Structural; E&M. `Status` lifecycles kept short & explicit.
- **Every object** gets: a Lightning record page, a tab, and is added to the **`EPC_PoC` permission set** and the **`EPC Execution` app**.
- **Lookups** to `Project__c` / `WBS_Item__c` / `Work_Package__c` where the datasheet implies "integration with schedule".
- **No hardcoded IDs**, no commented-out logic, bulk-safe Apex/flows.
- API version **62.0+**, deploy with `sf project deploy start -o birla`.

### Skills to use (per task type)
`generating-custom-object`, `generating-custom-field`, `generating-validation-rule`, `generating-flow`, `generating-apex`, `generating-apex-test`, `generating-lwc-components`, `generating-flexipage`, `generating-permission-set`, `generating-custom-tab`, `generating-custom-application`, `deploying-metadata`, `handling-sf-data`, `developing-agentforce` (WP9).

---

## 3. Sequencing & dependencies

```
WP0 Foundation ──┬─> WP1 Planning/Schedule ──┐
                 ├─> WP2 Procurement         │
                 ├─> WP3 Engineering ─────────┤
                 ├─> WP4 Construction ────────┼─> WP8 Reporting & Analytics ─> WP9 AI (stretch)
                 ├─> WP5 Quality ─────────────┤
                 ├─> WP6 HSE ─────────────────┤
                 └─> WP7 Commissioning/Handover┘
```
- **WP0 must run first** (everyone depends on the core objects + app + perm set).
- **WP1–WP7 are parallelizable** across threads after WP0. Shared objects are owned by the **first** WP that needs them: `NCR__c` → **WP4** (WP5 reuses), `RFI__c` → **WP3** (WP4 reuses), `Change_Order__c` → **WP2** (WP1/WP4 reuse), `Punch_List_Item__c` → **WP7**.
- **WP8 runs after** the data-producing WPs (needs sample data). **WP9 last** (grounds on everything).

---

## 4. Delegation model (how each thread runs)

Each WP thread:
1. **Orchestrator** (Opus/Sonnet) opens this plan, reads its WP + §2 conventions, confirms WP0 is deployed.
2. Decomposes the WP into atomic tasks (one object + its fields = one task; one flow = one task; one LWC = one task).
3. **Delegates each atomic task to a lower-model subagent** via the Agent tool (`subagent_type: general-purpose`, `model: haiku` for mechanical metadata authoring; `model: sonnet` for Apex/LWC/flows). Give the subagent: the exact field list, the conventions from §2, and "deploy to `-o birla` and report the deploy result."
4. **Verifies** each deploy (`sf project deploy start`/`sobject describe`), loads sample data, runs acceptance checks.
5. Updates the **progress tracker** (§7) and reports flags.

> Subagents do mechanical authoring & deploys. The orchestrator owns sequencing, schema decisions, verification, and anything cross-object (rollups, EVM). Don't delegate cross-object automation to Haiku.

---

## 5. Work Packages

Each object spec lists **key fields only** (every object also gets Name + standard audit). Field types: T=Text, TA=TextArea, P=Picklist, N=Number, C=Currency, %=Percent, D=Date, DT=DateTime, B=Checkbox, L(X)=Lookup to X, MD(X)=Master-Detail, F=Formula, AN=AutoNumber.

---

### WP0 — Foundation *(run first; ~1 thread)*
**Goal:** app shell, security, and the 4 core objects everything hangs off.

**Objects:**
- `Project__c` (AN `PRJ-{00000}`): Project_Code__c(T), Account__c L(Account), Project_Manager__c L(User), Start_Date__c(D), End_Date__c(D), Status__c(P: Initiation;Planning;Design;Pre-Construction;Construction;Commissioning;Completed;Closed), Stage_Gate__c(P: G0–G6), Approval_Status__c(P: Draft;Submitted;Approved;Rejected), Total_Budget__c(C), BAC__c(C), EV__c(C), PV__c(C), AC__c(C), CPI__c(N 18,2), SPI__c(N 18,2), Percent_Complete__c(% ), Baseline_Frozen__c(B).
- `WBS_Item__c` (AN `WBS-{00000}`): Project__c L(Project), Parent_WBS__c L(WBS_Item), Level__c(N), Code__c(T), Discipline__c(P), Control_Account__c(B), Baseline_Start__c(D), Baseline_Finish__c(D), Current_Start__c(D), Current_Finish__c(D), Duration__c(N), Predecessor__c(T), Predecessor_Type__c(P: FS;SS;FF), Critical_Path__c(B), Planned_Quantity__c(N), UoM__c(T), BAC__c(C), PV__c(C), EV__c(C), AC__c(C), Percent_Complete__c(%), CPI__c(N), SPI__c(N).
- `Work_Package__c` (AN `WP-{00000}`): Project__c L, WBS_Item__c L, Discipline__c(P), Status__c(P: Not Started;Planned;In Progress;On Hold;Completed), Start_Date__c(D), End_Date__c(D), Planned_Qty__c(N), Unit__c(P), Percent_Complete__c(%), Budget__c(C), Actual_Cost__c(C), Package_Manager__c L(User).
- `Milestone__c` (AN `MS-{00000}`): Project__c L, Description__c(TA), Due_Date__c(D), Actual_Date__c(D), Status__c(P: Not Started;In Progress;Completed;Delayed), Percent_Complete__c(%).

**Build also:** `EPC_PoC` permission set (R/W all PoC objects + fields); `EPC Execution` Lightning app (nav: Projects, WBS, Work Packages, Milestones — more added per WP); record pages for each.
**Acceptance:** create a Project with a 3-level WBS + 2 Work Packages + 2 Milestones manually; all tabs visible under the app via the perm set.
**Kickoff prompt:** *"Read BUILD_PLAN.md §2 + WP0. Clean fresh build on org `birla`. Create the 4 core objects with the listed fields, the EPC_PoC permission set, and the EPC Execution app. Delegate each object's field authoring to a haiku subagent; you author the app+permset and verify deploys. Don't build automation yet."*

---

### WP1 — Project Planning & Scheduling *(datasheet §1)*
**Rows:** 1.3 schedule build, 1.4 milestones, 1.5 update/re-baseline, 1.6 critical path, 1.7 delay capture, 1.8 catch-up. *(1.1/1.2 MSP/P6 = excluded integration.)*
**Schema add:** Schedule fields already on WBS (WP0). Add `Project__c.Planned_Finish_Variance__c`(F days), `WBS_Item__c.Schedule_Variance_Days__c`(F), `WBS_Item__c.Is_Delayed__c`(F B), `WBS_Item__c.AI_Insight__c`(TA, stretch).
**Automation:**
- WBS **date+budget roll-up** (child→parent→project): MIN baseline start, MAX baseline finish, SUM BAC, Level 3→2→1→Project. (Reference EPC `WBSItemTriggerHandler`; reimplement clean as Apex trigger handler + test.)
- **Duration/predecessor** before-save flow (compute finish from start+duration & predecessor offset).
- Baseline freeze (Project.Baseline_Frozen__c locks Baseline_* — validation rule or before-update).
**UI:** `epcGanttChart` LWC (WBS Gantt, baseline vs current bar, critical-path highlight); `epcScheduleVariance` mini-dashboard.
**Sample data:** 1 project, ~25 WBS items across 3 levels with baselines + a couple delayed.
**Acceptance:** editing a leaf baseline date rolls up to parent & project; critical-path items flagged; delayed items surface; Gantt renders.
**Kickoff prompt:** *"Read BUILD_PLAN.md §2,§4 + WP0(deployed)+WP1. Build §1 scheduling on `birla`: schedule fields, WBS roll-up trigger (+test, bulk-safe), duration/predecessor flow, Gantt LWC, sample data. Delegate field/flow authoring to subagents; you own the roll-up trigger + verification."*

---

### WP2 — Procurement *(datasheet §2)*
**Rows:** 2.1 planning, 2.2 order listing by function, 2.3 full status, 2.4 critical orders, 2.5 shipment, 2.6 customs, 2.7 LD & force majeure, 2.8 change order, 2.9 claims.
**Objects:**
- `Material_Requisition__c` (AN `MR-{00000}`): Project__c L, WBS_Item__c L, Work_Package__c L, Discipline__c(P), Priority__c(P: Low;Medium;High;Critical), Status__c(P: Draft;Submitted;Approved;RFQ Issued;Rejected), Needed_By__c(D), Total_Estimated_Cost__c(C), Requested_By__c L(User).  +child `MR_Line__c` (MD): Material_Code__c(T), Description__c(TA), Qty__c(N), UoM__c(P), Estimated_Unit_Cost__c(C), Estimated_Total_Cost__c(F).
- `RFQ__c` (AN) + `RFQ_Line__c` (MD): vendor invite & award fields. (Keep light — single-round.)
- `Purchase_Order__c` (AN `PO-{00000}`): Project__c L, Vendor__c L(Account), Material_Requisition__c L, WBS_Item__c L, Status__c(P: Draft;Issued;Partially Received;Closed), Approval_Stage__c(P: Buyer;PM;Finance), Total_Value__c(C), Order_Date__c(D), Expected_Delivery__c(D), Is_Critical__c(B), Inco_Terms__c(T), Payment_Terms__c(T). +child `PO_Line__c`.
- `Shipment__c` (AN): Purchase_Order__c L, Status__c(P: Planned;In Transit;At Customs;Cleared;Delivered), ETD__c(D), ETA__c(D), Customs_Status__c(P: Not Started;In Progress;Cleared;Held), Customs_Cleared_Date__c(D). *(covers 2.5/2.6 natively, no carrier integration)*
- `Goods_Receipt__c` (AN): Purchase_Order__c L, PO_Line__c L, Received_Qty__c(N), Receipt_Date__c(D), Status__c(P: Accepted;Partial;Rejected).
- `Change_Order__c` (AN `CO-{00000}`) **[owned here]**: Project__c L, WBS_Item__c L, Type_of_Change__c(P: Scope;Cost;Schedule), Status__c(P: Proposed;Under Review;Approved;Rejected), Value__c(C), Impact_Days__c(N), Justification__c(TA), Approved_By__c L(User), Approved_On__c(D).
- `Progress_Claim__c` (AN): Project__c L, Period__c(T), Amount__c(C), Retention_Pct__c(%), Retention_Held__c(F), Net_Claim__c(F), Status__c(P: Draft;Submitted;Approved;Rejected).
- LD/Force Majeure: `Project__c.LD_Rate__c`(C), `Project__c.LD_Accrued__c`(C); `Force_Majeure_Event__c` (AN): Project__c L, Description__c(TA), Start__c(D), End__c(D), Impact_Days__c(N).
**Automation:** MR approval → auto-create RFQ (flow); Change Order approved → add Value to Project budget/forecast (flow); PO 3-stage approval (Buyer→PM→Finance); GR updates PO % received.
**UI:** `epcProcurementConsole` LWC (PO/RFQ/MR status board + critical-order filter).
**Sample data:** ~5 MRs, 3 RFQs, 5 POs (1 critical), 3 shipments (1 at customs), 2 change orders, 2 claims.
**Acceptance:** MR→approve→RFQ created; PO advances through approval; critical orders filterable; customs/shipment status visible; CO approval bumps budget.
**Kickoff prompt:** *"Read §2,§4 + WP0 + WP2. Build the §2 procurement chain on `birla`. Change_Order__c is owned here. Delegate object/field authoring to haiku subagents; you own the approval & budget-update flows + verification + sample data."*

---

### WP3 — Engineering & Document Control *(datasheet §3)*
**Rows:** 3.1 schedule integ, 3.2 MDL, 3.3 progress, 3.4 drawing/doc mgmt, 3.5 review/approval (vendor↔RCCPL), 3.6 interface mgmt, 3.7 change request, 3.8 GFC release, 3.9 revision control, 3.10 mobile GFC access, 3.11 technical query (RFI), 3.12 escalation matrix, 3.13 revision gap analysis.
**Objects:**
- `Drawing__c` (AN `DWG-{00000}`): Project__c L, WBS_Item__c L, Drawing_Number__c(T), Title__c(T), Discipline__c(P), Current_Revision__c(T), Status__c(P: Draft;For Review;Approved;IFC/GFC;Rejected;Superseded), File_Type__c(P: PDF;DWG;DXF;3D;Image), File_URL__c(URL), Issue_Date__c(D). (Use Salesforce Files for attachments + URL for cloud.)
- `Document_Revision__c` (AN): Drawing__c L, Rev_Code__c(T), Reason__c(T), Issue_Date__c(D), Superseded__c(B), Comments__c(TA), Change_Summary__c(TA, for 3.13).
- `Submittal__c` (AN): Project__c L, Drawing__c L, WBS_Item__c L, Type__c(T), Discipline__c(P), Status__c(P: Draft;Submitted;Under Review;Approved;Approved as Noted;Rejected), Reviewer__c L(User), Submission_Date__c(D), Due_Date__c(D), Days_In_Review__c(F).
- `Transmittal__c` (AN): Project__c L, Purpose__c(T), Recipients__c(T), Sent_Date__c(D), Drawing__c L.
- `Interface__c` (AN): Project__c L, From_Party__c(T), To_Party__c(T), Description__c(TA), Status__c(P: Open;In Progress;Closed), Due_Date__c(D), Owner__c L(User). *(3.6)*
- `RFI__c` (AN `RFI-{00000}`) **[owned here; WP4 reuses]**: Project__c L, WBS_Item__c L, Work_Package__c L, Drawing__c L, Subject__c(T), Question_Rich__c(rich TA), Answer_Rich__c(rich TA), Status__c(P: Draft;Open;Under Review;Answered;Closed), Priority__c(P: High;Medium;Low), Discipline__c(P), Submitted_By__c L(User), Assigned_To__c L(User), Submitted_Date__c(D), Due_Date__c(D), Response_Date__c(D), Close_Date__c(D), SLA_Hours__c(N), Days_Open__c(F).
**Automation:**
- Drawing/Submittal **approval flow** (vendor→client review, status transitions, IFC release notification). *(3.5/3.8)*
- RFI **close-date** trigger (set Close_Date on Closed, clear on reopen) + **SLA escalation** scheduled flow (overdue → notify + escalate by priority: High 8h/Med 24h/Low 48h). *(3.11/3.12)*
- Revision **gap analysis**: on new Document_Revision, capture Change_Summary; optional Agentforce/prompt to summarize diff (stretch). *(3.13)*
**UI:** `epcDrawingRegister` (MDL list w/ revision+status), `epcRfiConsole` (RFI list + SLA + dashboard), `drawingViewer` (file view + markup — light). Mobile: ensure pages are mobile-enabled. *(3.10)*
**Sample data:** ~10 drawings (mix of statuses incl. IFC), revisions, 5 submittals, 8 RFIs (some overdue).
**Acceptance:** drawing review→IFC with notification; RFI overdue triggers escalation; MDL register filterable by discipline/status; mobile view works.
**Kickoff prompt:** *"Read §2,§4 + WP0 + WP3. Build §3 engineering/doc-control on `birla`. RFI__c is owned here. Delegate object authoring to haiku; you own approval flow, RFI SLA scheduled flow + close-date trigger (+tests), and the RFI/Drawing LWCs."*

---

### WP4 — Construction *(datasheet §4)*
**Rows:** 4.1 schedule, 4.2 mobilization, 4.3 daily progress, 4.4 weekly, 4.5 quantity, 4.6 productivity, 4.7 work front, 4.8 site instructions, 4.9 change mgmt, 4.10 RFI (reuse WP3), 4.11 NCR, 4.12 resource, 4.13 equipment, 4.14 contractor perf.
**Objects:**
- `Daily_Progress__c` (AN `DPR-{00000}`): Project__c L, Work_Package__c L, WBS_Item__c L, Date__c(D), Qty_Installed__c(N), Planned_Quantity__c(N), Hours_Worked__c(N), Crew_Size__c(N), Equipment_Hours__c(N), Weather__c(T), Safety_Incidents__c(N), Quality_Issues__c(N), Productivity__c(F: Qty/Hours), Submitted_By__c L(User), Approved_By__c L(User).
- `Resource__c` (AN): Work_Package__c L, Daily_Progress__c L, Type__c(P: Labor;Material;Equipment;Subcontract), Quantity__c(N), Quantity_Used__c(N), Hours_Worked__c(N), UoM__c(T).
- `Equipment__c` (AN): Project__c L, Name__c(T), Type__c(T), Status__c(P: Idle;In Use;Under Maintenance), Utilization_Hours__c(N). +`Equipment_Log__c` (date, hours, work package).
- `Site_Instruction__c` (AN): Project__c L, WBS_Item__c L, Instruction__c(TA), Issued_To__c L(User), Status__c(P: Issued;Acknowledged;Closed), Issue_Date__c(D). *(4.8)*
- `Work_Front__c` (AN): Project__c L, Work_Package__c L, Readiness_Status__c(P: Blocked;Ready;Released), Released_Date__c(D), Blockers__c(TA). *(4.7)*
- `Mobilization__c` (AN): Project__c L, Item__c(T), Category__c(P: Manpower;Equipment;Facility), Status__c(P: Planned;In Progress;Complete), Target_Date__c(D). *(4.2)*
- `NCR__c` (AN `NCR-{00000}`) **[owned here; WP5 reuses]**: Project__c L, WBS_Item__c L, Status__c(P: Open;Under Investigation;Corrective Action;Closed), Severity__c(P: Low;Medium;High;Critical), Category__c(T), Root_Cause__c(TA), Corrective_Action__c(TA), Opened_By__c L(User), Responsible_Party__c L(User), Identified_Date__c(D), Closed_Date__c(D), Vendor__c L(Account).
- `Contractor_Performance__c` (AN): Project__c L, Contractor__c L(Account), Period__c(T), Schedule_Score__c(N), Quality_Score__c(N), Safety_Score__c(N), Overall__c(F). *(4.14)*
**Automation:** Daily Progress → roll up `Qty_Installed` to Work Package `Percent_Complete` and WBS `EV` (reference EPC `EVCalculator`; clean reimplementation — leaf %complete from daily qty, EV=BAC×%); weekly rollup report; NCR close-date stamp.
**UI:** `epcDailyProgressCapture` (mobile-friendly form), `epcSiteExecutionBoard` (progress + NCR + work-front), `epcWorkPackageKanban` (status board), `epcEquipmentUtil`.
**Sample data:** ~30 daily progress records over 2 weeks, resources, 5 equipment, 8 NCRs, work fronts, contractor scores.
**Acceptance:** logging daily progress updates WP/WBS % and EV; weekly report aggregates; NCR lifecycle works; equipment utilization shows; productivity computed.
**Kickoff prompt:** *"Read §2,§4 + WP0 + WP4. Build §4 construction on `birla`. NCR__c owned here; reuse RFI__c from WP3 (if not yet built, create minimal RFI lookup). Delegate object authoring to haiku; you own the daily-progress→EV rollup (Apex/flow, bulk-safe, +test) and the capture/board LWCs."*

---

### WP5 — Quality *(datasheet §5)*
**Rows:** 5.1 QMP/ITP, 5.2 TPI inspection, 5.3 FAT, 5.4 SAT, 5.5 NCR (reuse WP4), 5.6 CAPA, 5.7 RCA, 5.8 vendor quality, 5.9 pour card, 5.10 welding, 5.11 calibration, 5.12 IBR.
**Objects:**
- `Inspection_Test_Plan__c` (AN `ITP-{00000}`): Project__c L, Discipline__c(P), Description__c(TA), Hold_Witness_Points__c(B), Status__c(P: Draft;Approved;Active;Closed).
- `Inspection_Request__c` (AN `IR-{00000}`): Project__c L, WBS_Item__c L, Work_Package__c L, ITP__c L, Type__c(P: TPI;FAT;SAT;Internal), Lot__c(T), Area__c(T), Requested_Date__c(D), Inspected_Date__c(D), Status__c(P: Requested;Accepted;Passed;Failed;Conditional), Inspector__c L(User), Result_Notes__c(TA). *(covers 5.2/5.3/5.4 via Type)*
- `CAPA__c` (AN): NCR__c L, Action__c(TA), Type__c(P: Corrective;Preventive), Owner__c L(User), Due_Date__c(D), Status__c(P: Open;In Progress;Verified;Closed), Verification__c(TA). *(5.6)* — RCA (5.7) lives on NCR.Root_Cause__c + add `NCR__c.RCA_Method__c`(P: 5-Why;Fishbone;FMEA).
- `Pour_Card__c` (AN): Project__c L, WBS_Item__c L, Mix_Design__c(T), Slump__c(N), Cube_Test_Result__c(N), Pre_Pour_Checklist_Complete__c(B), Approval_Status__c(P: Pending;Approved;Rejected), Pour_Date__c(D). *(5.9)*
- `Weld_Record__c` (AN): Project__c L, Joint_No__c(T), WPS__c(T), Welder_ID__c(T), Welder_Qualified__c(B), NDT_Type__c(P: RT;UT;MT;PT;Visual), NDT_Result__c(P: Accept;Reject;Repair). *(5.10)*
- `Calibration_Record__c` (AN): Instrument__c(T), Serial_No__c(T), Calibration_Date__c(D), Due_Date__c(D), Status__c(P: Valid;Due;Expired), Certificate_URL__c(URL). *(5.11)*
- `IBR_Test__c` (AN): Project__c L, Component__c(T), Test_Type__c(T), IBR_Form__c(T), Status__c(P: Scheduled;Passed;Failed;Certified), Inspector__c(T), Certified_Date__c(D). *(5.12)*
- Vendor quality (5.8): reuse `NCR__c.Vendor__c` + a report; add `Account` rollup field if helpful.
**Automation:** Failed Inspection → auto-create NCR (flow); Calibration Due_Date → status flip via scheduled flow; CAPA closure verification.
**UI:** `epcQualityHub` (ITP/inspection/NCR/CAPA tabs), `epcQualityDashboard`.
**Sample data:** ITPs, ~6 inspections (incl. FAT/SAT, 1 failed→NCR), CAPAs, 3 pour cards, weld records, calibrations, IBR tests.
**Acceptance:** failed inspection spawns NCR; CAPA tracks to verified; calibration expiry flips status; pour-card approval gate; reports by vendor.
**Kickoff prompt:** *"Read §2,§4 + WP0 + WP5. Build §5 quality on `birla`. Reuse NCR__c from WP4 (create minimal if absent). Delegate object authoring to haiku; you own inspection→NCR flow, calibration scheduled flow, and the quality hub LWC."*

---

### WP6 — Health, Safety & Environment *(datasheet §6)*
**Rows:** 6.1 OHS compliance, 6.2 permit-to-work, 6.3 toolbox talks, 6.4 safety observation, 6.5 incident, 6.6 near-miss, 6.7 HIRA/HAZOP, 6.8 audits, 6.9 emergency response.
**Objects:**
- `Permit_to_Work__c` (AN `PTW-{00000}`): Project__c L, WBS_Item__c L, Permit_Type__c(P: Hot Work;Confined Space;Work at Height;Excavation;Electrical), Status__c(P: Draft;Approved;Active;Expired;Closed), Valid_From__c(DT), Valid_To__c(DT), Area__c(T), Work_Description__c(TA), Issued_By__c L(User).
- `Observation__c` (AN): Project__c L, Type__c(P: Safety;Quality;Environmental), Risk_Level__c(P: Low;Medium;High), Description__c(TA), Action_Required__c(T), Status__c(P: Open;Closed), Observed_By__c L(User), Observation_Date__c(D). *(6.4)*
- `Incident__c` (AN): Project__c L, Type__c(P: Injury;Property;Environmental;Fire), Severity__c(P: Minor;Major;Fatal;Near-Miss), Is_Near_Miss__c(B), Description__c(TA), Investigation__c(TA), CAPA__c(TA), Status__c(P: Reported;Investigating;Closed), Date__c(D). *(6.5/6.6)*
- `Toolbox_Talk__c` (AN): Project__c L, Topic__c(T), Date__c(D), Conducted_By__c L(User), Attendance_Count__c(N), Notes__c(TA). *(6.3)*
- `HIRA__c` (AN): Project__c L, Activity__c(T), Hazard__c(TA), Risk_Rating__c(P: Low;Medium;High;Extreme), Control_Measures__c(TA), Residual_Risk__c(P), Status__c(P: Open;Mitigated;Closed). *(6.7)*
- `Safety_Audit__c` (AN): Project__c L, Audit_Date__c(D), Auditor__c L(User), Score__c(N), Findings__c(TA), Status__c(P: Planned;Completed;Closed). +`Audit_Finding__c` child. *(6.8)*
- `Emergency_Plan__c` (AN): Project__c L, Scenario__c(T), Contacts__c(TA), Drill_Date__c(D), Status__c(P: Active;Drill Due;Reviewed). *(6.9)*
- OHS compliance (6.1): `OHS_Compliance_Item__c` (AN): Project__c L, Requirement__c(T), Status__c(P: Compliant;Gap;N/A), Evidence_URL__c(URL).
**Automation:** Permit expiry scheduled flow (Active→Expired on Valid_To); High-risk Observation/Incident → notification/task; near-miss flagged on Incident.
**UI:** `epcHseHub` (permits/observations/incidents), `epcPermitPlanner`, `epcSafetyDashboard` (TRIR-style indicators).
**Sample data:** ~6 permits (1 expiring), observations, 3 incidents (1 near-miss), toolbox talks, HIRA entries, 1 audit, emergency plan.
**Acceptance:** permit expires automatically; high-risk obs notifies; near-miss tracked; safety dashboard renders indicators.
**Kickoff prompt:** *"Read §2,§4 + WP0 + WP6. Build §6 HSE on `birla`. Delegate object authoring to haiku; you own the permit-expiry scheduled flow, high-risk notification, and HSE hub/dashboard LWC."*

---

### WP7 — Commissioning & Handover *(datasheet §7)*
**Rows:** 7.1 mechanical completion, 7.2 E&I completion, 7.3 pre-commissioning, 7.4 no-load trials, 7.5 load trials, 7.6 commissioning procedure, 7.7 cold/hot commissioning, 7.8 performance testing, 7.9 punch list closure, 7.10 O&M handover, 7.11 training records, 7.12 final acceptance.
**Objects:**
- `Completion__c` (AN `CMP-{00000}`): Project__c L, WBS_Item__c L, System__c(T), Stage__c(P: Mechanical Completion;E&I Completion;Pre-Commissioning;No-Load Trial;Load Trial;Cold Commissioning;Hot Commissioning;Performance Test), Status__c(P: Not Started;In Progress;Complete;Signed Off), Target_Date__c(D), Actual_Date__c(D), Result__c(TA), Signed_Off_By__c L(User). *(covers 7.1–7.8 via Stage)*
- `Commissioning_Procedure__c` (AN): Project__c L, System__c(T), Procedure_Doc_URL__c(URL), Steps_Total__c(N), Steps_Complete__c(N), Status__c(P: Draft;Approved;In Progress;Complete). *(7.6)*
- `Punch_List_Item__c` (AN `PL-{00000}`) **[owned here]**: Project__c L, WBS_Item__c L, Work_Package__c L, Handover_Package__c L, Description__c(TA), Category__c(P: A;B;C), Priority__c(P: High;Medium;Low), Status__c(P: Open;In Progress;Closed), Assigned_To__c L(User), Due_Date__c(D).
- `Handover_Package__c` (AN): Project__c L, Package_Code__c(T), Scope__c(TA), Status__c(P: Draft;In Progress;Ready for Client;Accepted), OM_Manual_URL__c(URL), Client_Acceptance_Date__c(D). *(7.10)*
- `Training_Record__c` (AN): Project__c L, Topic__c(T), Trainee__c L(User), Date__c(D), Status__c(P: Scheduled;Completed), Competency_Verified__c(B). *(7.11)*
- `Final_Acceptance__c` (AN): Project__c L, Handover_Package__c L, Status__c(P: Draft;Submitted;Client Review;Accepted;Certified), Certificate_URL__c(URL), Accepted_By__c(T), Accepted_Date__c(D). *(7.12)*
**Automation:** Punch closure rollup to Handover_Package readiness (all punch closed → Ready for Client); Completion stage progression gate; FAC requires zero open Category-A punch.
**UI:** `epcHandoverBuilder` (package + punch + completion view), `epcCommissioningTracker`.
**Sample data:** completions across stages, 1 commissioning procedure, ~9 punch items, 1 handover package, training records, FAC draft.
**Acceptance:** closing all punch flips handover to Ready; completion stages progress; FAC gated on punch.
**Kickoff prompt:** *"Read §2,§4 + WP0 + WP7. Build §7 commissioning/handover on `birla`. Punch_List_Item__c owned here. Delegate object authoring to haiku; you own punch→handover rollup, FAC gating, and the handover builder LWC."*

---

### WP8 — Reporting & Analytics *(datasheet §9)* — run after data WPs
**Rows:** 9.1 executive dashboard, 9.2 project dashboard, 9.3 KPI monitoring, 9.4 schedule, 9.5 cost, 9.6 procurement, 9.7 engineering, 9.8 construction analytics, 9.9 drill-down, 9.10 custom report builder.
**Build:** custom report types spanning the WP objects; reports per analytic area; **dashboards**: Executive (portfolio EVM/CPI/SPI, safety, RFI SLA), Project (cost/schedule/quality/safety), Procurement, Engineering (RFI/submittal aging, drawing status), Construction (progress/productivity/NCR). Enable drill-down. Confirm report builder access via perm set.
**UI:** a `Project_Command_Center` FlexiPage assembling EVM cards + S-curve + key dashboards; portfolio home page.
**Acceptance:** dashboards reflect sample data in real time; drill from dashboard→report→records; users can clone/build reports.
**Kickoff prompt:** *"Read §2,§4 + all prior WPs (deployed w/ sample data) + WP8. Build §9 reporting on `birla`: report types, reports, dashboards (executive/project/procurement/engineering/construction), Command Center page. Delegate report/dashboard authoring to subagents; you assemble the Command Center + verify drill-down."*

---

### WP9 — AI / Agentforce *(datasheet 8.17, 8.12 AI chatbot)* — stretch, run last
**Build:** an **Agentforce** agent ("EPC Assistant") grounded on Project/RFI/NCR/Daily Progress with a few topics/actions (e.g., "show overdue RFIs for project X", "open NCRs by severity", "project EVM status"). Use `developing-agentforce` skill. Demonstrates 8.17 AI chatbot + 8.24 trust layer talking points.
**Acceptance:** agent answers the 3 sample questions against live PoC data.
**Kickoff prompt:** *"Read §2,§4 + WP8 + WP9. Build an Agentforce 'EPC Assistant' on `birla` grounded on PoC objects with 3 actions (overdue RFIs, open NCRs by severity, project EVM). Use developing-agentforce skill."*

---

## 6. Cross-cutting deliverables (whoever finishes their WP early)
- A **demo script** (`DEMO_SCRIPT.md`) walking RCCPL through Project→schedule→engineering→procurement→construction→quality→HSE→commissioning→dashboards.
- A **datasheet ↔ PoC traceability** note (which built feature evidences which row) — append to the datasheet's "Enclosures" column where "Demo available" is marked.

## 7. Progress tracker  *(update as WPs complete)*
| WP | Section | Status | Thread / notes |
|----|---------|--------|----------------|
| WP0 | Foundation | ✅ Done (2026-06-11) | 4 objects + tabs + EPC Execution app + EPC_PoC permset + record pages deployed to birla org. Sample data: 1 project, 3-level WBS, 2 WPs, 2 milestones. |
| WP1 | Planning & Scheduling | ✅ Done (2026-06-11) | Schema: Baseline_Finish__c, Planned_Finish_Variance__c (Project), Schedule_Variance_Days__c, Is_Delayed__c, AI_Insight__c (WBS_Item). Trigger: WBSRollupHandler (L3→L2→L1→Project, 96% test coverage). Flow: WBS_Duration_Predecessor_Calc. Validation: Baseline_Frozen_Lock. LWCs: epcGanttChart + epcScheduleVariance (both pages). Sample data: 1 project, 27 WBS items (3 levels), 17 delayed, 2 critical path. |
| WP2 | Procurement | ✅ Done (2026-06-11) | 11 objects (MR, MR_Line, RFQ, RFQ_Line, PO, PO_Line, Shipment, GR, Change_Order, Progress_Claim, Force_Majeure_Event) + 2 Project fields (LD_Rate, LD_Accrued). Flows: MR→Approved→auto-RFQ, CO→Approved→budget update, GR→PO status. Approval process: PO 3-stage (Buyer→PM→Finance). LWC: epcProcurementConsole (status board + critical filter, mobile-enabled). Record pages for all new objects. Sample data: 5 MRs, 4 MR lines, 3 RFQs, 5 POs (1 critical, 1 partially received), 4 PO lines, 3 shipments (1 at customs), 1 GR, 2 COs (1 approved → project budget 55M), 2 progress claims, 1 FM event. Acceptance checks: all pass. |
| WP3 | Engineering | ✅ Done (2026-06-11) | 6 objects: Drawing__c (DWG-{00000}), Document_Revision__c (REV-{00000}), Submittal__c (SUB-{00000}), Transmittal__c (TRN-{00000}), Interface__c (INT-{00000}), RFI__c (RFI-{00000}). Formula fields: Days_Open__c (RFI), Days_In_Review__c (Submittal). Trigger: RFITrigger + RFITriggerHandler (Close_Date stamp/clear, 5 tests, 100% pass). Flows: Submittal_Approval_IFC_Notification (after-save CreateAndUpdate → Drawing IFC/GFC), RFI_SLA_Escalation_Daily (scheduled, creates Tasks on overdue RFIs). Validation: Change_Summary required on Document_Revision. LWCs: epcDrawingRegister (filterable by Discipline/Status), epcRfiConsole (Days_Open highlight, stats bar). Both LWCs on Project record page. All 6 objects in EPC Execution app nav + EPC_PoC perm set + Lightning record pages. Sample data: 10 drawings, 13 revisions, 5 submittals (1 approved→IFC), 3 transmittals, 3 interfaces, 8 RFIs (3 closed with Close_Date, 4 overdue). Acceptance checks: all pass. WP4 can reuse RFI__c — note Days_Open__c is a Number formula field (not SOQL queryable inline in WHERE, use Date comparison on Due_Date__c/Submitted_Date__c instead). |
| WP4 | Construction | ✅ Done (2026-06-11) | 9 objects: NCR__c (NCR-{00000}), Daily_Progress__c (DPR-{00000}), Resource__c, Equipment__c, Equipment_Log__c (child MD), Site_Instruction__c, Work_Front__c, Mobilization__c, Contractor_Performance__c. Triggers: DailyProgressTrigger (EV rollup: qty→WP %complete + WBS EV, 7 tests 100% pass) + NCRTrigger (close-date stamp/clear). Apex: DailyProgressTriggerHandler (bulk-safe, rolls up to WBS), NCRTriggerHandler, ConstructionBoardController (getConstructionBoardData, getWorkPackagesForKanban, getEquipmentForProject). LWCs: epcDailyProgressCapture (mobile form + progress bar), epcSiteExecutionBoard (NCR/workfront/progress tabs + KPI strip), epcWorkPackageKanban (status columns + progress bars), epcEquipmentUtil (utilization bars + summary). All objects in EPC Execution app nav + EPC_PoC permset. Sample data: 8 NCRs (2 closed w/ Closed_Date, 2 Critical), 22 DPRs, 5 equipment, 6 logs, 5 work fronts (2 blocked), 3 site instructions, 8 mobilization items, 4 contractor perf records. Acceptance: WP Percent_Complete + EV updated live from DPRs; NCR close-date auto-stamps. |
| WP5 | Quality | ✅ Done (2026-06-11) | 7 objects: Inspection_Test_Plan__c (ITP-{00000}), Inspection_Request__c (IR-{00000}), CAPA__c (CAPA-{00000}), Pour_Card__c (PC-{00000}), Weld_Record__c (WR-{00000}), Calibration_Record__c (CAL-{00000}), IBR_Test__c (IBR-{00000}). Flows: Inspection_Failed_Create_NCR (after-save, failed IR→auto NCR), Calibration_Status_Update (scheduled daily, flips Valid→Due/Expired by date). Apex: QualityHubController (getQualityHubData, getQualityKPIs, getCalibrationAlerts). LWCs: epcQualityHub (ITP/Inspection/NCR/CAPA tabs + status filter + KPI strip), epcQualityDashboard (pass-rate gauge + severity breakdown + calib alerts). All in EPC_PoC permset + EPC Execution app. Sample data: 6 ITPs, 12 IRs (incl. FAT/SAT, failed→auto-NCR), 6 CAPAs, 6 pour cards, 8 weld records, 5 calibrations (2 expired, 2 due), 4 IBR tests. Acceptance: failed inspection auto-spawns NCR (confirmed); calibration expiry tracked; CAPA lifecycle works; quality dashboard renders. |
| WP6 | HSE | ✅ Done (2026-06-11) | 9 objects: Permit_to_Work__c (PTW-{00000}), Observation__c (OBS-{00000}), Incident__c (INC-{00000}), Toolbox_Talk__c (TBT-{00000}), HIRA__c (HIRA-{00000}), Safety_Audit__c (SAU-{00000}), Audit_Finding__c (AF-{00000}, MD child), Emergency_Plan__c (EP-{00000}), OHS_Compliance_Item__c (OHS-{00000}). Flows: Permit_Expiry_Update (scheduled daily, Active PTWs where Valid_To < NOW → Expired), High_Risk_Observation_Task (after-save, High Risk observation → Task for owner). Apex: HseHubController (getHseHubData, getHseKPIs, getExpiringPermits — TRIR, near-miss, active permit counts). LWCs: epcHseHub (Permits/Observations/Incidents/TBT tabs + KPI strip), epcPermitPlanner (permit planner with status/type filter + expiry alert), epcSafetyDashboard (TRIR gauge + incident severity breakdown + audit score). All in EPC_PoC permset + EPC Execution app nav. Sample data: 6 permits (1 expiring, 1 expired), 5 observations (2 High-risk open), 3 incidents (1 near-miss, 1 injury closed, 1 property), 4 toolbox talks (165 total attendees), 3 HIRAs, 1 safety audit (78.5%) + 3 findings, 1 emergency plan, 3 OHS compliance items. |
| WP7 | Commissioning/Handover | ✅ Done (2026-06-11) | 6 objects: Completion__c (CMP-{00000}, 8 stages covering 7.1–7.8), Commissioning_Procedure__c (CP-{00000}), Punch_List_Item__c (PL-{00000}, Cat A/B/C), Handover_Package__c (HP-{00000}), Training_Record__c (TR-{00000}), Final_Acceptance__c (FAC-{00000}). Triggers: PunchListTrigger (after insert/update → rollup all-closed punch to Handover_Package__c → Ready for Client), FinalAcceptanceTrigger (before insert/update → Cat-A gate blocks FAC submission if open Cat-A punch exists). Apex: HandoverController (getHandoverData, getHandoverKPIs, getCommissioningProcedures, getFinalAcceptances). LWCs: epcHandoverBuilder (packages/punch/training/FAC tabs + KPI strip with Cat-A alert + closure rate), epcCommissioningTracker (stage progress grid + procedure datatable). Tests: WP7TriggerTest (5/5 pass, 100%). All in EPC_PoC permset + EPC Execution app. Sample data: 1 handover package, 8 completions (2 Signed Off, 2 complete, 2 In Progress, 2 Not Started), 1 commissioning procedure (18/24 steps), 9 punch items (2 Cat-A open, 4 Cat-B mixed, 3 closed), 4 training records (2 completed, 2 scheduled), 1 FAC (Draft). Acceptance: all-punch-closed → HP flips to Ready for Client (verified); open Cat-A blocks FAC (error confirms 2 items); rollup and gate both work live. |
| WP8 | Reporting & Analytics | ☐ | after data WPs |
| WP9 | AI / Agentforce | ☐ | stretch, last |

## 8. Datasheet rows intentionally NOT built (integration/positioning)
1.1, 1.2 (MSP/P6), 2.5 live-carrier feed, 8.1 (cloud-only positioning), 8.5 offline, 8.10–8.11 (commercial/backup), 8.12–8.16 (SAP/MSP/P6/PowerBI/SCADA integration), 8.18–8.26 (platform/architecture answers), and all of §10–§11. These are answered in the datasheet but are not Salesforce-config build items.
