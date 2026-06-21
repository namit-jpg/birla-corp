// -------------------------------------------------------------------
// Demo Project: Satna Line 3 - 1.5 MTPA Clinker Expansion
// 30 WBS items (6 summary phases + 11 sub-phases + 13 leaf packages)
// Status as of Jun-2026: Engineering 100%, Procurement 72%,
//   Civil 65%, Mechanical 30%, E&I 8%, Commissioning 0%
// -------------------------------------------------------------------
Id me = UserInfo.getUserId();

// -- 1. Project ---------------------------------------------------
Project__c proj = new Project__c(
    Start_Date__c    = Date.newInstance(2025, 1, 6),
    Baseline_Finish__c = Date.newInstance(2026, 9, 30),
    End_Date__c      = Date.newInstance(2026, 10, 16),   // already slipping by 11 days
    Project_Manager__c = me,
    Total_Budget__c  = 3800000000.00     // INR 380 Crore
);
insert proj;
Id pid = proj.Id;

// -- 2. WBS Items - insert level-by-level ------------------------
Map<String, Id> wId = new Map<String, Id>();   // code -> WBS Id
List<WBS_Item__c> toIns;

// helper inline
// Level-1 summaries (phases)
toIns = new List<WBS_Item__c>{
    new WBS_Item__c(Project__c=pid, Name__c='Engineering & Design',         Code__c='1', Level__c=1, BAC__c=190000000),
    new WBS_Item__c(Project__c=pid, Name__c='Procurement',                   Code__c='2', Level__c=1, BAC__c=1710000000),
    new WBS_Item__c(Project__c=pid, Name__c='Civil Construction',            Code__c='3', Level__c=1, BAC__c=760000000),
    new WBS_Item__c(Project__c=pid, Name__c='Mechanical Installation',       Code__c='4', Level__c=1, BAC__c=570000000),
    new WBS_Item__c(Project__c=pid, Name__c='Electrical & Instrumentation',  Code__c='5', Level__c=1, BAC__c=380000000),
    new WBS_Item__c(Project__c=pid, Name__c='Commissioning & Handover',      Code__c='6', Level__c=1, BAC__c=190000000)
};
TriggerHelper.isRunning = true; insert toIns; TriggerHelper.isRunning = false;
for (WBS_Item__c w : toIns) wId.put(w.Code__c, w.Id);

// Level-2 sub-phases
toIns = new List<WBS_Item__c>{
    new WBS_Item__c(Project__c=pid, Name__c='Process Engineering',           Code__c='1.1', Level__c=2, Parent_WBS__c=wId.get('1'), BAC__c=76000000),
    new WBS_Item__c(Project__c=pid, Name__c='Civil & Structural Design',     Code__c='1.2', Level__c=2, Parent_WBS__c=wId.get('1'), BAC__c=57000000),
    new WBS_Item__c(Project__c=pid, Name__c='Equipment Specifications',      Code__c='1.3', Level__c=2, Parent_WBS__c=wId.get('1'), BAC__c=57000000),
    new WBS_Item__c(Project__c=pid, Name__c='Long Lead Equipment',           Code__c='2.1', Level__c=2, Parent_WBS__c=wId.get('2'), BAC__c=1140000000),
    new WBS_Item__c(Project__c=pid, Name__c='Bulk Materials',                Code__c='2.2', Level__c=2, Parent_WBS__c=wId.get('2'), BAC__c=570000000),
    new WBS_Item__c(Project__c=pid, Name__c='Site Preparation',              Code__c='3.1', Level__c=2, Parent_WBS__c=wId.get('3'), BAC__c=152000000),
    new WBS_Item__c(Project__c=pid, Name__c='Foundations & Structures',      Code__c='3.2', Level__c=2, Parent_WBS__c=wId.get('3'), BAC__c=608000000),
    new WBS_Item__c(Project__c=pid, Name__c='Equipment Erection',            Code__c='4.1', Level__c=2, Parent_WBS__c=wId.get('4'), BAC__c=380000000),
    new WBS_Item__c(Project__c=pid, Name__c='Piping Installation',           Code__c='4.2', Level__c=2, Parent_WBS__c=wId.get('4'), BAC__c=190000000),
    new WBS_Item__c(Project__c=pid, Name__c='Electrical Systems',            Code__c='5.1', Level__c=2, Parent_WBS__c=wId.get('5'), BAC__c=228000000),
    new WBS_Item__c(Project__c=pid, Name__c='Instrumentation & Control',     Code__c='5.2', Level__c=2, Parent_WBS__c=wId.get('5'), BAC__c=152000000),
    new WBS_Item__c(Project__c=pid, Name__c='Pre-Commissioning',             Code__c='6.1', Level__c=2, Parent_WBS__c=wId.get('6'), BAC__c=95000000),
    new WBS_Item__c(Project__c=pid, Name__c='Trial Operations & Handover',   Code__c='6.2', Level__c=2, Parent_WBS__c=wId.get('6'), BAC__c=95000000)
};
TriggerHelper.isRunning = true; insert toIns; TriggerHelper.isRunning = false;
for (WBS_Item__c w : toIns) wId.put(w.Code__c, w.Id);

// Level-3 leaf work packages (with Baseline dates + progress)
toIns = new List<WBS_Item__c>{

// -- 1.1 Process Engineering (complete Jan-Mar 2025) ---------------
new WBS_Item__c(Project__c=pid, Name__c='Basis of Design Document & Project Execution Plan',
    Code__c='1.1.1', Level__c=3, Parent_WBS__c=wId.get('1.1'),
    Duration__c=10, BAC__c=19000000, Percent_Complete__c=100,
    Baseline_Start__c=Date.newInstance(2025,1,6),   Baseline_Finish__c=Date.newInstance(2025,1,17),
    Actual_Start__c=Date.newInstance(2025,1,6),     Actual_Finish__c=Date.newInstance(2025,1,17),
    Custodian__c=me, Assignee__c=me, Control_Account__c=true),

new WBS_Item__c(Project__c=pid, Name__c='Process Flow Diagrams, Heat & Mass Balance',
    Code__c='1.1.2', Level__c=3, Parent_WBS__c=wId.get('1.1'),
    Duration__c=8, BAC__c=19000000, Percent_Complete__c=100,
    Baseline_Start__c=Date.newInstance(2025,1,20),  Baseline_Finish__c=Date.newInstance(2025,1,29),
    Actual_Start__c=Date.newInstance(2025,1,20),    Actual_Finish__c=Date.newInstance(2025,1,31),
    Custodian__c=me, Assignee__c=me),

new WBS_Item__c(Project__c=pid, Name__c='Piping & Instrumentation Diagrams (P&ID) - IFC Issue',
    Code__c='1.1.3', Level__c=3, Parent_WBS__c=wId.get('1.1'),
    Duration__c=15, BAC__c=38000000, Percent_Complete__c=100,
    Baseline_Start__c=Date.newInstance(2025,2,3),   Baseline_Finish__c=Date.newInstance(2025,2,21),
    Actual_Start__c=Date.newInstance(2025,2,3),     Actual_Finish__c=Date.newInstance(2025,2,28),
    Custodian__c=me, Assignee__c=me),

// -- 1.2 Civil & Structural Design (complete Feb-Apr 2025) ---------
new WBS_Item__c(Project__c=pid, Name__c='Geotechnical Investigation, Bore Log & Soil Report',
    Code__c='1.2.1', Level__c=3, Parent_WBS__c=wId.get('1.2'),
    Duration__c=12, BAC__c=19000000, Percent_Complete__c=100,
    Baseline_Start__c=Date.newInstance(2025,1,6),   Baseline_Finish__c=Date.newInstance(2025,1,21),
    Actual_Start__c=Date.newInstance(2025,1,6),     Actual_Finish__c=Date.newInstance(2025,1,22),
    Custodian__c=me, Assignee__c=me),

new WBS_Item__c(Project__c=pid, Name__c='Foundation Design, GA Drawings & RCC Detailing',
    Code__c='1.2.2', Level__c=3, Parent_WBS__c=wId.get('1.2'),
    Duration__c=15, BAC__c=19000000, Percent_Complete__c=100,
    Baseline_Start__c=Date.newInstance(2025,1,22),  Baseline_Finish__c=Date.newInstance(2025,2,11),
    Actual_Start__c=Date.newInstance(2025,1,23),    Actual_Finish__c=Date.newInstance(2025,2,14),
    Custodian__c=me, Assignee__c=me),

new WBS_Item__c(Project__c=pid, Name__c='Structural Steel Detailed Design, Drawings & BOQ',
    Code__c='1.2.3', Level__c=3, Parent_WBS__c=wId.get('1.2'),
    Duration__c=18, BAC__c=19000000, Percent_Complete__c=100,
    Baseline_Start__c=Date.newInstance(2025,2,12),  Baseline_Finish__c=Date.newInstance(2025,3,7),
    Actual_Start__c=Date.newInstance(2025,2,17),    Actual_Finish__c=Date.newInstance(2025,3,14),
    Custodian__c=me, Assignee__c=me),

// -- 1.3 Equipment Specifications (complete Mar-Apr 2025) ----------
new WBS_Item__c(Project__c=pid, Name__c='Rotary Kiln Technical Specification & Material Requisition',
    Code__c='1.3.1', Level__c=3, Parent_WBS__c=wId.get('1.3'),
    Duration__c=12, BAC__c=19000000, Percent_Complete__c=100,
    Baseline_Start__c=Date.newInstance(2025,2,24),  Baseline_Finish__c=Date.newInstance(2025,3,11),
    Actual_Start__c=Date.newInstance(2025,3,3),     Actual_Finish__c=Date.newInstance(2025,3,18),
    Custodian__c=me, Assignee__c=me),

new WBS_Item__c(Project__c=pid, Name__c='Cement Vertical Roller Mill (VRM) Specification & MR',
    Code__c='1.3.2', Level__c=3, Parent_WBS__c=wId.get('1.3'),
    Duration__c=10, BAC__c=19000000, Percent_Complete__c=100,
    Baseline_Start__c=Date.newInstance(2025,2,24),  Baseline_Finish__c=Date.newInstance(2025,3,7),
    Actual_Start__c=Date.newInstance(2025,3,3),     Actual_Finish__c=Date.newInstance(2025,3,14),
    Custodian__c=me, Assignee__c=me),

new WBS_Item__c(Project__c=pid, Name__c='Preheater / ILC Calciner Engineering & Specification',
    Code__c='1.3.3', Level__c=3, Parent_WBS__c=wId.get('1.3'),
    Duration__c=15, BAC__c=19000000, Percent_Complete__c=100,
    Baseline_Start__c=Date.newInstance(2025,2,24),  Baseline_Finish__c=Date.newInstance(2025,3,14),
    Actual_Start__c=Date.newInstance(2025,3,3),     Actual_Finish__c=Date.newInstance(2025,3,21),
    Custodian__c=me, Assignee__c=me),

// -- 2.1 Long Lead Equipment (Apr-Dec 2025, delayed) ---------------
new WBS_Item__c(Project__c=pid, Name__c='Rotary Kiln Supply - FLSmidth ROTAX-2 (incl. Shop Inspection)',
    Code__c='2.1.1', Level__c=3, Parent_WBS__c=wId.get('2.1'),
    Duration__c=45, BAC__c=456000000, Percent_Complete__c=100,
    Baseline_Start__c=Date.newInstance(2025,3,17),  Baseline_Finish__c=Date.newInstance(2025,5,16),
    Actual_Start__c=Date.newInstance(2025,3,24),    Actual_Finish__c=Date.newInstance(2025,6,6),
    Custodian__c=me, Assignee__c=me),

new WBS_Item__c(Project__c=pid, Name__c='Cement VRM Supply & Third-Party Shop Inspection',
    Code__c='2.1.2', Level__c=3, Parent_WBS__c=wId.get('2.1'),
    Duration__c=40, BAC__c=380000000, Percent_Complete__c=95,
    Baseline_Start__c=Date.newInstance(2025,3,10),  Baseline_Finish__c=Date.newInstance(2025,5,2),
    Actual_Start__c=Date.newInstance(2025,3,17),    Actual_Finish__c=null,
    Custodian__c=me, Assignee__c=me),

new WBS_Item__c(Project__c=pid, Name__c='Preheater Tower Equipment Supply & ITP Inspection',
    Code__c='2.1.3', Level__c=3, Parent_WBS__c=wId.get('2.1'),
    Duration__c=50, BAC__c=304000000, Percent_Complete__c=85,
    Baseline_Start__c=Date.newInstance(2025,3,24),  Baseline_Finish__c=Date.newInstance(2025,6,2),
    Actual_Start__c=Date.newInstance(2025,3,31),    Actual_Finish__c=null,
    Custodian__c=me, Assignee__c=me),

// -- 2.2 Bulk Materials (May-Aug 2025) -----------------------------
new WBS_Item__c(Project__c=pid, Name__c='Structural Steel Fabrication & Supply to Site',
    Code__c='2.2.1', Level__c=3, Parent_WBS__c=wId.get('2.2'),
    Duration__c=25, BAC__c=190000000, Percent_Complete__c=100,
    Baseline_Start__c=Date.newInstance(2025,3,17),  Baseline_Finish__c=Date.newInstance(2025,4,18),
    Actual_Start__c=Date.newInstance(2025,3,24),    Actual_Finish__c=Date.newInstance(2025,5,2),
    Custodian__c=me, Assignee__c=me),

new WBS_Item__c(Project__c=pid, Name__c='Process Piping, Valves, Flanges & Fittings Supply',
    Code__c='2.2.2', Level__c=3, Parent_WBS__c=wId.get('2.2'),
    Duration__c=20, BAC__c=114000000, Percent_Complete__c=100,
    Baseline_Start__c=Date.newInstance(2025,3,3),   Baseline_Finish__c=Date.newInstance(2025,3,28),
    Actual_Start__c=Date.newInstance(2025,3,3),     Actual_Finish__c=Date.newInstance(2025,4,4),
    Custodian__c=me, Assignee__c=me),

new WBS_Item__c(Project__c=pid, Name__c='HT/LT Cables, MCC Panels & Instrumentation Supply',
    Code__c='2.2.3', Level__c=3, Parent_WBS__c=wId.get('2.2'),
    Duration__c=22, BAC__c=266000000, Percent_Complete__c=80,
    Baseline_Start__c=Date.newInstance(2025,3,3),   Baseline_Finish__c=Date.newInstance(2025,4,2),
    Actual_Start__c=Date.newInstance(2025,3,3),     Actual_Finish__c=null,
    Custodian__c=me, Assignee__c=me),

// -- 3.1 Site Preparation (Apr-May 2025, complete) -----------------
new WBS_Item__c(Project__c=pid, Name__c='Site Clearing, Grubbing, Demolition & Temporary Roads',
    Code__c='3.1.1', Level__c=3, Parent_WBS__c=wId.get('3.1'),
    Duration__c=10, BAC__c=57000000, Percent_Complete__c=100,
    Baseline_Start__c=Date.newInstance(2025,1,27),  Baseline_Finish__c=Date.newInstance(2025,2,7),
    Actual_Start__c=Date.newInstance(2025,1,27),    Actual_Finish__c=Date.newInstance(2025,2,10),
    Custodian__c=me, Assignee__c=me),

new WBS_Item__c(Project__c=pid, Name__c='Bulk Earthworks: Excavation, Cut-Fill, Compaction & Drainage',
    Code__c='3.1.2', Level__c=3, Parent_WBS__c=wId.get('3.1'),
    Duration__c=15, BAC__c=95000000, Percent_Complete__c=100,
    Baseline_Start__c=Date.newInstance(2025,2,10),  Baseline_Finish__c=Date.newInstance(2025,3,3),
    Actual_Start__c=Date.newInstance(2025,2,11),    Actual_Finish__c=Date.newInstance(2025,3,7),
    Custodian__c=me, Assignee__c=me),

// -- 3.2 Foundations & Structures (May-Sep 2025) -------------------
new WBS_Item__c(Project__c=pid, Name__c='Rotary Kiln Raft Foundation - Piling, PCC & RCC',
    Code__c='3.2.1', Level__c=3, Parent_WBS__c=wId.get('3.2'),
    Duration__c=25, BAC__c=190000000, Percent_Complete__c=100,
    Baseline_Start__c=Date.newInstance(2025,3,10),  Baseline_Finish__c=Date.newInstance(2025,4,11),
    Actual_Start__c=Date.newInstance(2025,3,10),    Actual_Finish__c=Date.newInstance(2025,4,18),
    Custodian__c=me, Assignee__c=me),

new WBS_Item__c(Project__c=pid, Name__c='Cement VRM Foundation, Pedestal & Grouting Pads',
    Code__c='3.2.2', Level__c=3, Parent_WBS__c=wId.get('3.2'),
    Duration__c=20, BAC__c=152000000, Percent_Complete__c=100,
    Baseline_Start__c=Date.newInstance(2025,3,10),  Baseline_Finish__c=Date.newInstance(2025,4,4),
    Actual_Start__c=Date.newInstance(2025,3,10),    Actual_Finish__c=Date.newInstance(2025,4,11),
    Custodian__c=me, Assignee__c=me),

new WBS_Item__c(Project__c=pid, Name__c='Preheater Tower Structural Steel Erection (5-Stage, 105m)',
    Code__c='3.2.3', Level__c=3, Parent_WBS__c=wId.get('3.2'),
    Duration__c=35, BAC__c=266000000, Percent_Complete__c=90,
    Baseline_Start__c=Date.newInstance(2025,5,12),  Baseline_Finish__c=Date.newInstance(2025,7,2),
    Actual_Start__c=Date.newInstance(2025,5,19),    Actual_Finish__c=null,
    Custodian__c=me, Assignee__c=me),

// -- 4.1 Equipment Erection (Aug-Dec 2025) -------------------------
new WBS_Item__c(Project__c=pid, Name__c='Rotary Kiln Shell Assembly, Riding Ring & Drive Erection',
    Code__c='4.1.1', Level__c=3, Parent_WBS__c=wId.get('4.1'),
    Duration__c=30, BAC__c=190000000, Percent_Complete__c=55,
    Baseline_Start__c=Date.newInstance(2025,5,19),  Baseline_Finish__c=Date.newInstance(2025,7,2),
    Actual_Start__c=Date.newInstance(2025,6,9),     Actual_Finish__c=null,
    Custodian__c=me, Assignee__c=me),

new WBS_Item__c(Project__c=pid, Name__c='Cement VRM Erection, Roller Alignment & Gearbox Installation',
    Code__c='4.1.2', Level__c=3, Parent_WBS__c=wId.get('4.1'),
    Duration__c=20, BAC__c=114000000, Percent_Complete__c=30,
    Baseline_Start__c=Date.newInstance(2025,4,25),  Baseline_Finish__c=Date.newInstance(2025,5,23),
    Actual_Start__c=Date.newInstance(2025,5,5),     Actual_Finish__c=null,
    Custodian__c=me, Assignee__c=me),

new WBS_Item__c(Project__c=pid, Name__c='Preheater Cyclone, Calciner & Riser Duct Installation',
    Code__c='4.1.3', Level__c=3, Parent_WBS__c=wId.get('4.1'),
    Duration__c=25, BAC__c=76000000, Percent_Complete__c=20,
    Baseline_Start__c=Date.newInstance(2025,7,7),   Baseline_Finish__c=Date.newInstance(2025,8,11),
    Actual_Start__c=Date.newInstance(2025,8,4),     Actual_Finish__c=null,
    Custodian__c=me, Assignee__c=me),

// -- 4.2 Piping (Oct 2025 - Jan 2026) -----------------------------
new WBS_Item__c(Project__c=pid, Name__c='Process Piping Fabrication, Erection, NDE & Hydro Test',
    Code__c='4.2.1', Level__c=3, Parent_WBS__c=wId.get('4.2'),
    Duration__c=25, BAC__c=133000000, Percent_Complete__c=10,
    Baseline_Start__c=Date.newInstance(2025,7,7),   Baseline_Finish__c=Date.newInstance(2025,8,8),
    Actual_Start__c=Date.newInstance(2025,9,1),     Actual_Finish__c=null,
    Custodian__c=me, Assignee__c=me),

new WBS_Item__c(Project__c=pid, Name__c='Utility Piping: Compressed Air, Cooling Water & Fuel Oil',
    Code__c='4.2.2', Level__c=3, Parent_WBS__c=wId.get('4.2'),
    Duration__c=20, BAC__c=57000000, Percent_Complete__c=5,
    Baseline_Start__c=Date.newInstance(2025,7,7),   Baseline_Finish__c=Date.newInstance(2025,8,1),
    Actual_Start__c=Date.newInstance(2025,9,1),     Actual_Finish__c=null,
    Custodian__c=me, Assignee__c=me),

// -- 5.1 Electrical Systems (Oct 2025 - Feb 2026) -----------------
new WBS_Item__c(Project__c=pid, Name__c='HT/LT Cable Laying, Tray Installation & Termination',
    Code__c='5.1.1', Level__c=3, Parent_WBS__c=wId.get('5.1'),
    Duration__c=25, BAC__c=114000000, Percent_Complete__c=12,
    Baseline_Start__c=Date.newInstance(2025,7,14),  Baseline_Finish__c=Date.newInstance(2025,8,15),
    Actual_Start__c=Date.newInstance(2025,9,8),     Actual_Finish__c=null,
    Custodian__c=me, Assignee__c=me),

new WBS_Item__c(Project__c=pid, Name__c='Motor Control Centre, VFD Panels & Substation Installation',
    Code__c='5.1.2', Level__c=3, Parent_WBS__c=wId.get('5.1'),
    Duration__c=20, BAC__c=76000000, Percent_Complete__c=5,
    Baseline_Start__c=Date.newInstance(2025,8,18),  Baseline_Finish__c=Date.newInstance(2025,9,12),
    Actual_Start__c=null, Actual_Finish__c=null,
    Custodian__c=me, Assignee__c=me),

new WBS_Item__c(Project__c=pid, Name__c='Plant Lighting, Earthing Grid & Lightning Protection',
    Code__c='5.1.3', Level__c=3, Parent_WBS__c=wId.get('5.1'),
    Duration__c=15, BAC__c=38000000, Percent_Complete__c=3,
    Baseline_Start__c=Date.newInstance(2025,9,15),  Baseline_Finish__c=Date.newInstance(2025,10,3),
    Actual_Start__c=null, Actual_Finish__c=null,
    Custodian__c=me, Assignee__c=me),

// -- 5.2 Instrumentation (Nov 2025 - Mar 2026) --------------------
new WBS_Item__c(Project__c=pid, Name__c='Field Instrumentation, Transmitters, Hook-Up & Impulse Tubing',
    Code__c='5.2.1', Level__c=3, Parent_WBS__c=wId.get('5.2'),
    Duration__c=20, BAC__c=76000000, Percent_Complete__c=5,
    Baseline_Start__c=Date.newInstance(2025,8,25),  Baseline_Finish__c=Date.newInstance(2025,9,19),
    Actual_Start__c=null, Actual_Finish__c=null,
    Custodian__c=me, Assignee__c=me),

new WBS_Item__c(Project__c=pid, Name__c='DCS/PLC Engineering, FAT, SAT, Loop Check & Historian',
    Code__c='5.2.2', Level__c=3, Parent_WBS__c=wId.get('5.2'),
    Duration__c=25, BAC__c=76000000, Percent_Complete__c=0,
    Baseline_Start__c=Date.newInstance(2025,9,22),  Baseline_Finish__c=Date.newInstance(2025,10,24),
    Actual_Start__c=null, Actual_Finish__c=null,
    Custodian__c=me, Assignee__c=me),

// -- 6.1 Pre-Commissioning (Dec 2025 - Jan 2026) -------------------
new WBS_Item__c(Project__c=pid, Name__c='Mechanical Completion, Punch List A/B Clearance & MC Certificate',
    Code__c='6.1.1', Level__c=3, Parent_WBS__c=wId.get('6.1'),
    Duration__c=10, BAC__c=38000000, Percent_Complete__c=0,
    Baseline_Start__c=Date.newInstance(2025,11,3),  Baseline_Finish__c=Date.newInstance(2025,11,14),
    Actual_Start__c=null, Actual_Finish__c=null,
    Custodian__c=me, Assignee__c=me),

new WBS_Item__c(Project__c=pid, Name__c='Loop Checking, Calibration, SIL Verification & HAZOP Closeout',
    Code__c='6.1.2', Level__c=3, Parent_WBS__c=wId.get('6.1'),
    Duration__c=12, BAC__c=57000000, Percent_Complete__c=0,
    Baseline_Start__c=Date.newInstance(2025,11,17), Baseline_Finish__c=Date.newInstance(2025,12,2),
    Actual_Start__c=null, Actual_Finish__c=null,
    Custodian__c=me, Assignee__c=me),

// -- 6.2 Trial Operations (Jan-Mar 2026) ---------------------------
new WBS_Item__c(Project__c=pid, Name__c='Cold Commissioning, No-Load Trial Run & Alignment Verification',
    Code__c='6.2.1', Level__c=3, Parent_WBS__c=wId.get('6.2'),
    Duration__c=12, BAC__c=38000000, Percent_Complete__c=0,
    Baseline_Start__c=Date.newInstance(2025,12,3),  Baseline_Finish__c=Date.newInstance(2025,12,18),
    Actual_Start__c=null, Actual_Finish__c=null,
    Custodian__c=me, Assignee__c=me),

new WBS_Item__c(Project__c=pid, Name__c='Hot Commissioning, 72-Hr Performance Test & RFSU Handover',
    Code__c='6.2.2', Level__c=3, Parent_WBS__c=wId.get('6.2'),
    Duration__c=15, BAC__c=57000000, Percent_Complete__c=0,
    Baseline_Start__c=Date.newInstance(2025,12,22), Baseline_Finish__c=Date.newInstance(2026,1,9),
    Actual_Start__c=null, Actual_Finish__c=null,
    Custodian__c=me, Assignee__c=me)
};
TriggerHelper.isRunning = true; insert toIns; TriggerHelper.isRunning = false;
for (WBS_Item__c w : toIns) wId.put(w.Code__c, w.Id);

// -- 3. WBS Dependencies ------------------------------------------
List<WBS_Dependency__c> deps = new List<WBS_Dependency__c>{
    // 1.1 Process chain
    new WBS_Dependency__c(Predecessor__c=wId.get('1.1.1'), Successor__c=wId.get('1.1.2'), Dependency_Type__c='FS'),
    new WBS_Dependency__c(Predecessor__c=wId.get('1.1.2'), Successor__c=wId.get('1.1.3'), Dependency_Type__c='FS'),
    // 1.2 Civil design - starts with process SS, then sequential
    new WBS_Dependency__c(Predecessor__c=wId.get('1.1.1'), Successor__c=wId.get('1.2.1'), Dependency_Type__c='SS'),
    new WBS_Dependency__c(Predecessor__c=wId.get('1.2.1'), Successor__c=wId.get('1.2.2'), Dependency_Type__c='FS'),
    new WBS_Dependency__c(Predecessor__c=wId.get('1.2.2'), Successor__c=wId.get('1.2.3'), Dependency_Type__c='FS'),
    // 1.3 Equip specs follow P&ID
    new WBS_Dependency__c(Predecessor__c=wId.get('1.1.3'), Successor__c=wId.get('1.3.1'), Dependency_Type__c='FS'),
    new WBS_Dependency__c(Predecessor__c=wId.get('1.1.3'), Successor__c=wId.get('1.3.2'), Dependency_Type__c='FS'),
    new WBS_Dependency__c(Predecessor__c=wId.get('1.1.3'), Successor__c=wId.get('1.3.3'), Dependency_Type__c='FS'),
    // 2.1 Long lead triggered by specs
    new WBS_Dependency__c(Predecessor__c=wId.get('1.3.1'), Successor__c=wId.get('2.1.1'), Dependency_Type__c='FS'),
    new WBS_Dependency__c(Predecessor__c=wId.get('1.3.2'), Successor__c=wId.get('2.1.2'), Dependency_Type__c='FS'),
    new WBS_Dependency__c(Predecessor__c=wId.get('1.3.3'), Successor__c=wId.get('2.1.3'), Dependency_Type__c='FS'),
    // 2.2 Bulk materials follow drawings
    new WBS_Dependency__c(Predecessor__c=wId.get('1.2.3'), Successor__c=wId.get('2.2.1'), Dependency_Type__c='FS'),
    new WBS_Dependency__c(Predecessor__c=wId.get('1.1.3'), Successor__c=wId.get('2.2.2'), Dependency_Type__c='FS'),
    new WBS_Dependency__c(Predecessor__c=wId.get('1.1.3'), Successor__c=wId.get('2.2.3'), Dependency_Type__c='FS'),
    // 3.1 Site prep follows geo
    new WBS_Dependency__c(Predecessor__c=wId.get('1.2.1'), Successor__c=wId.get('3.1.1'), Dependency_Type__c='FS'),
    new WBS_Dependency__c(Predecessor__c=wId.get('3.1.1'), Successor__c=wId.get('3.1.2'), Dependency_Type__c='FS'),
    // 3.2 Foundations follow earthworks + design
    new WBS_Dependency__c(Predecessor__c=wId.get('3.1.2'), Successor__c=wId.get('3.2.1'), Dependency_Type__c='FS'),
    new WBS_Dependency__c(Predecessor__c=wId.get('1.2.2'), Successor__c=wId.get('3.2.1'), Dependency_Type__c='FS'),
    new WBS_Dependency__c(Predecessor__c=wId.get('3.1.2'), Successor__c=wId.get('3.2.2'), Dependency_Type__c='FS'),
    new WBS_Dependency__c(Predecessor__c=wId.get('1.2.2'), Successor__c=wId.get('3.2.2'), Dependency_Type__c='FS'),
    // Preheater tower needs steel supply + earthworks
    new WBS_Dependency__c(Predecessor__c=wId.get('2.2.1'), Successor__c=wId.get('3.2.3'), Dependency_Type__c='FS'),
    new WBS_Dependency__c(Predecessor__c=wId.get('3.1.2'), Successor__c=wId.get('3.2.3'), Dependency_Type__c='FS'),
    // 4.1 Erection needs equipment delivery + foundation
    new WBS_Dependency__c(Predecessor__c=wId.get('2.1.1'), Successor__c=wId.get('4.1.1'), Dependency_Type__c='FS'),
    new WBS_Dependency__c(Predecessor__c=wId.get('3.2.1'), Successor__c=wId.get('4.1.1'), Dependency_Type__c='FS'),
    new WBS_Dependency__c(Predecessor__c=wId.get('2.1.2'), Successor__c=wId.get('4.1.2'), Dependency_Type__c='FS'),
    new WBS_Dependency__c(Predecessor__c=wId.get('3.2.2'), Successor__c=wId.get('4.1.2'), Dependency_Type__c='FS'),
    new WBS_Dependency__c(Predecessor__c=wId.get('2.1.3'), Successor__c=wId.get('4.1.3'), Dependency_Type__c='FS'),
    new WBS_Dependency__c(Predecessor__c=wId.get('3.2.3'), Successor__c=wId.get('4.1.3'), Dependency_Type__c='FS'),
    // 4.2 Piping follows kiln erection + material supply
    new WBS_Dependency__c(Predecessor__c=wId.get('4.1.1'), Successor__c=wId.get('4.2.1'), Dependency_Type__c='FS'),
    new WBS_Dependency__c(Predecessor__c=wId.get('2.2.2'), Successor__c=wId.get('4.2.1'), Dependency_Type__c='FS'),
    new WBS_Dependency__c(Predecessor__c=wId.get('4.2.1'), Successor__c=wId.get('4.2.2'), Dependency_Type__c='SS', Lag_Days__c=5),
    // 5.1 Electrical follows structures + materials
    new WBS_Dependency__c(Predecessor__c=wId.get('2.2.3'), Successor__c=wId.get('5.1.1'), Dependency_Type__c='FS'),
    new WBS_Dependency__c(Predecessor__c=wId.get('3.2.3'), Successor__c=wId.get('5.1.1'), Dependency_Type__c='FS'),
    new WBS_Dependency__c(Predecessor__c=wId.get('5.1.1'), Successor__c=wId.get('5.1.2'), Dependency_Type__c='FS'),
    new WBS_Dependency__c(Predecessor__c=wId.get('5.1.2'), Successor__c=wId.get('5.1.3'), Dependency_Type__c='SS', Lag_Days__c=3),
    // 5.2 Instruments follow kiln erection + cabling
    new WBS_Dependency__c(Predecessor__c=wId.get('4.1.1'), Successor__c=wId.get('5.2.1'), Dependency_Type__c='FS'),
    new WBS_Dependency__c(Predecessor__c=wId.get('5.1.1'), Successor__c=wId.get('5.2.1'), Dependency_Type__c='FS'),
    new WBS_Dependency__c(Predecessor__c=wId.get('5.2.1'), Successor__c=wId.get('5.2.2'), Dependency_Type__c='FS'),
    // 6.1 Pre-comm follows piping complete + DCS
    new WBS_Dependency__c(Predecessor__c=wId.get('4.2.1'), Successor__c=wId.get('6.1.1'), Dependency_Type__c='FS'),
    new WBS_Dependency__c(Predecessor__c=wId.get('5.2.2'), Successor__c=wId.get('6.1.1'), Dependency_Type__c='FS'),
    new WBS_Dependency__c(Predecessor__c=wId.get('6.1.1'), Successor__c=wId.get('6.1.2'), Dependency_Type__c='FS'),
    // 6.2 Trial ops follow pre-comm
    new WBS_Dependency__c(Predecessor__c=wId.get('6.1.2'), Successor__c=wId.get('6.2.1'), Dependency_Type__c='FS'),
    new WBS_Dependency__c(Predecessor__c=wId.get('6.2.1'), Successor__c=wId.get('6.2.2'), Dependency_Type__c='FS')
};
TriggerHelper.isRunning = true; insert deps; TriggerHelper.isRunning = false;

// -- 4. Run CPM to compute float, critical path & current schedule -
CPMEngine.recalculate(pid);

// -- 5. Run delay risk engine --------------------------------------
WBSDelayRiskService.evaluate(pid);

System.debug('Project created: ' + pid);
System.debug('Open: /lightning/r/Project__c/' + pid + '/view');

