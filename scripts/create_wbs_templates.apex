// ═══════════════════════════════════════════════════════════════════
// WBS Templates for Birla Corp EPC Org
// Run in: VS Code  Ctrl+Shift+P → SFDX: Execute Anonymous Apex
//         OR Dev Console → Debug → Open Execute Anonymous Window
// ═══════════════════════════════════════════════════════════════════

// ──────────────────────────────────────────────────────────────────
// TEMPLATE 1 : Cement Plant EPC – Full Lifecycle (Greenfield / Brown)
// 34 work packages across 6 phases
// ──────────────────────────────────────────────────────────────────
WBS_Template__c t1 = new WBS_Template__c(
    Name = 'Cement Plant Construction – EPC Full Lifecycle',
    Is_Active__c = true
);
insert t1;

Map<String, Id> ids = new Map<String, Id>();
List<WBS_Template_Item__c> ins;

// ── Level 1 (phases) ────────────────────────────────────────────
ins = new List<WBS_Template_Item__c>{
    new WBS_Template_Item__c(WBS_Template__c=t1.Id, Name='Engineering & Design',          Code__c='1', Level__c=1, Sequence__c=1),
    new WBS_Template_Item__c(WBS_Template__c=t1.Id, Name='Procurement',                   Code__c='2', Level__c=1, Sequence__c=2),
    new WBS_Template_Item__c(WBS_Template__c=t1.Id, Name='Civil Construction',             Code__c='3', Level__c=1, Sequence__c=3),
    new WBS_Template_Item__c(WBS_Template__c=t1.Id, Name='Mechanical Installation',        Code__c='4', Level__c=1, Sequence__c=4),
    new WBS_Template_Item__c(WBS_Template__c=t1.Id, Name='Electrical & Instrumentation',  Code__c='5', Level__c=1, Sequence__c=5),
    new WBS_Template_Item__c(WBS_Template__c=t1.Id, Name='Commissioning & Handover',      Code__c='6', Level__c=1, Sequence__c=6)
};
insert ins;
for (WBS_Template_Item__c ti : ins) ids.put(ti.Code__c, ti.Id);

// ── Level 2 (disciplines) ───────────────────────────────────────
ins = new List<WBS_Template_Item__c>{
    new WBS_Template_Item__c(WBS_Template__c=t1.Id, Name='Process Engineering',            Code__c='1.1', Level__c=2, Sequence__c=1, Parent_Template_Item__c=ids.get('1')),
    new WBS_Template_Item__c(WBS_Template__c=t1.Id, Name='Civil & Structural Design',      Code__c='1.2', Level__c=2, Sequence__c=2, Parent_Template_Item__c=ids.get('1')),
    new WBS_Template_Item__c(WBS_Template__c=t1.Id, Name='Equipment Specifications',       Code__c='1.3', Level__c=2, Sequence__c=3, Parent_Template_Item__c=ids.get('1')),
    new WBS_Template_Item__c(WBS_Template__c=t1.Id, Name='Long Lead Equipment',            Code__c='2.1', Level__c=2, Sequence__c=1, Parent_Template_Item__c=ids.get('2')),
    new WBS_Template_Item__c(WBS_Template__c=t1.Id, Name='Bulk Materials & Sub-Contracts', Code__c='2.2', Level__c=2, Sequence__c=2, Parent_Template_Item__c=ids.get('2')),
    new WBS_Template_Item__c(WBS_Template__c=t1.Id, Name='Site Preparation',               Code__c='3.1', Level__c=2, Sequence__c=1, Parent_Template_Item__c=ids.get('3')),
    new WBS_Template_Item__c(WBS_Template__c=t1.Id, Name='Foundations & Structures',       Code__c='3.2', Level__c=2, Sequence__c=2, Parent_Template_Item__c=ids.get('3')),
    new WBS_Template_Item__c(WBS_Template__c=t1.Id, Name='Equipment Erection',             Code__c='4.1', Level__c=2, Sequence__c=1, Parent_Template_Item__c=ids.get('4')),
    new WBS_Template_Item__c(WBS_Template__c=t1.Id, Name='Piping Installation',            Code__c='4.2', Level__c=2, Sequence__c=2, Parent_Template_Item__c=ids.get('4')),
    new WBS_Template_Item__c(WBS_Template__c=t1.Id, Name='Electrical Systems',             Code__c='5.1', Level__c=2, Sequence__c=1, Parent_Template_Item__c=ids.get('5')),
    new WBS_Template_Item__c(WBS_Template__c=t1.Id, Name='Instrumentation & Control',      Code__c='5.2', Level__c=2, Sequence__c=2, Parent_Template_Item__c=ids.get('5')),
    new WBS_Template_Item__c(WBS_Template__c=t1.Id, Name='Pre-Commissioning',              Code__c='6.1', Level__c=2, Sequence__c=1, Parent_Template_Item__c=ids.get('6')),
    new WBS_Template_Item__c(WBS_Template__c=t1.Id, Name='Trial Operations & Handover',    Code__c='6.2', Level__c=2, Sequence__c=2, Parent_Template_Item__c=ids.get('6'))
};
insert ins;
for (WBS_Template_Item__c ti : ins) ids.put(ti.Code__c, ti.Id);

// ── Level 3 (work packages) ─────────────────────────────────────
ins = new List<WBS_Template_Item__c>{
// 1.1 Process Engineering
new WBS_Template_Item__c(WBS_Template__c=t1.Id, Name='Basis of Design (BOD) Document',                        Code__c='1.1.1', Level__c=3, Sequence__c=1,  Parent_Template_Item__c=ids.get('1.1'), Typical_Duration_Days__c=10, Budget_Percentage__c=0.50, Control_Account__c=true),
new WBS_Template_Item__c(WBS_Template__c=t1.Id, Name='Process Flow Diagrams (PFD) & Heat Balance',             Code__c='1.1.2', Level__c=3, Sequence__c=2,  Parent_Template_Item__c=ids.get('1.1'), Typical_Duration_Days__c=8,  Budget_Percentage__c=0.50, Predecessor_Code__c='1.1.1', Dependency_Type__c='FS'),
new WBS_Template_Item__c(WBS_Template__c=t1.Id, Name='Piping & Instrumentation Diagrams (P&ID)',               Code__c='1.1.3', Level__c=3, Sequence__c=3,  Parent_Template_Item__c=ids.get('1.1'), Typical_Duration_Days__c=15, Budget_Percentage__c=1.00, Predecessor_Code__c='1.1.2', Dependency_Type__c='FS'),
// 1.2 Civil & Structural Design
new WBS_Template_Item__c(WBS_Template__c=t1.Id, Name='Geotechnical Investigation & Soil Report',               Code__c='1.2.1', Level__c=3, Sequence__c=1,  Parent_Template_Item__c=ids.get('1.2'), Typical_Duration_Days__c=12, Budget_Percentage__c=0.50, Predecessor_Code__c='1.1.1', Dependency_Type__c='SS'),
new WBS_Template_Item__c(WBS_Template__c=t1.Id, Name='Foundation Design, GA & Structural Drawings',            Code__c='1.2.2', Level__c=3, Sequence__c=2,  Parent_Template_Item__c=ids.get('1.2'), Typical_Duration_Days__c=15, Budget_Percentage__c=0.80, Predecessor_Code__c='1.2.1', Dependency_Type__c='FS'),
new WBS_Template_Item__c(WBS_Template__c=t1.Id, Name='Structural Steel Detailed Design & BOQ',                 Code__c='1.2.3', Level__c=3, Sequence__c=3,  Parent_Template_Item__c=ids.get('1.2'), Typical_Duration_Days__c=18, Budget_Percentage__c=0.70, Predecessor_Code__c='1.2.2', Dependency_Type__c='FS'),
// 1.3 Equipment Specifications
new WBS_Template_Item__c(WBS_Template__c=t1.Id, Name='Rotary Kiln Technical Specification & Material Reqn',    Code__c='1.3.1', Level__c=3, Sequence__c=1,  Parent_Template_Item__c=ids.get('1.3'), Typical_Duration_Days__c=12, Budget_Percentage__c=0.50, Predecessor_Code__c='1.1.3', Dependency_Type__c='FS'),
new WBS_Template_Item__c(WBS_Template__c=t1.Id, Name='Cement Mill (VRM / Ball Mill) Specification & MR',       Code__c='1.3.2', Level__c=3, Sequence__c=2,  Parent_Template_Item__c=ids.get('1.3'), Typical_Duration_Days__c=10, Budget_Percentage__c=0.50, Predecessor_Code__c='1.1.3', Dependency_Type__c='FS'),
new WBS_Template_Item__c(WBS_Template__c=t1.Id, Name='Preheater / Calciner Engineering & Specification',       Code__c='1.3.3', Level__c=3, Sequence__c=3,  Parent_Template_Item__c=ids.get('1.3'), Typical_Duration_Days__c=15, Budget_Percentage__c=0.80, Predecessor_Code__c='1.1.3', Dependency_Type__c='FS'),
// 2.1 Long Lead Equipment
new WBS_Template_Item__c(WBS_Template__c=t1.Id, Name='Rotary Kiln Supply – FLSmidth / KHD (incl. Shop Insp)', Code__c='2.1.1', Level__c=3, Sequence__c=1,  Parent_Template_Item__c=ids.get('2.1'), Typical_Duration_Days__c=45, Budget_Percentage__c=12.00, Predecessor_Code__c='1.3.1', Dependency_Type__c='FS'),
new WBS_Template_Item__c(WBS_Template__c=t1.Id, Name='Cement Mill Supply & Shop Inspection',                   Code__c='2.1.2', Level__c=3, Sequence__c=2,  Parent_Template_Item__c=ids.get('2.1'), Typical_Duration_Days__c=40, Budget_Percentage__c=10.00, Predecessor_Code__c='1.3.2', Dependency_Type__c='FS'),
new WBS_Template_Item__c(WBS_Template__c=t1.Id, Name='Preheater Tower Equipment Supply & Inspection',          Code__c='2.1.3', Level__c=3, Sequence__c=3,  Parent_Template_Item__c=ids.get('2.1'), Typical_Duration_Days__c=50, Budget_Percentage__c=8.00,  Predecessor_Code__c='1.3.3', Dependency_Type__c='FS'),
// 2.2 Bulk Materials
new WBS_Template_Item__c(WBS_Template__c=t1.Id, Name='Structural Steel Fabrication & Supply',                  Code__c='2.2.1', Level__c=3, Sequence__c=1,  Parent_Template_Item__c=ids.get('2.2'), Typical_Duration_Days__c=25, Budget_Percentage__c=5.00,  Predecessor_Code__c='1.2.3', Dependency_Type__c='FS'),
new WBS_Template_Item__c(WBS_Template__c=t1.Id, Name='Process Piping, Valves & Fittings Supply',               Code__c='2.2.2', Level__c=3, Sequence__c=2,  Parent_Template_Item__c=ids.get('2.2'), Typical_Duration_Days__c=20, Budget_Percentage__c=3.00,  Predecessor_Code__c='1.1.3', Dependency_Type__c='FS'),
new WBS_Template_Item__c(WBS_Template__c=t1.Id, Name='HT/LT Electrical, Cable & Instrumentation Supply',      Code__c='2.2.3', Level__c=3, Sequence__c=3,  Parent_Template_Item__c=ids.get('2.2'), Typical_Duration_Days__c=22, Budget_Percentage__c=4.00,  Predecessor_Code__c='1.1.3', Dependency_Type__c='FS'),
// 3.1 Site Preparation
new WBS_Template_Item__c(WBS_Template__c=t1.Id, Name='Site Clearing, Grubbing & Vegetation Removal',           Code__c='3.1.1', Level__c=3, Sequence__c=1,  Parent_Template_Item__c=ids.get('3.1'), Typical_Duration_Days__c=10, Budget_Percentage__c=1.00,  Predecessor_Code__c='1.2.1', Dependency_Type__c='FS'),
new WBS_Template_Item__c(WBS_Template__c=t1.Id, Name='Bulk Earthworks: Excavation, Cut-Fill & Compaction',     Code__c='3.1.2', Level__c=3, Sequence__c=2,  Parent_Template_Item__c=ids.get('3.1'), Typical_Duration_Days__c=15, Budget_Percentage__c=1.50,  Predecessor_Code__c='3.1.1', Dependency_Type__c='FS'),
// 3.2 Foundations & Structures
new WBS_Template_Item__c(WBS_Template__c=t1.Id, Name='Rotary Kiln Raft Foundation – Piling & RCC',             Code__c='3.2.1', Level__c=3, Sequence__c=1,  Parent_Template_Item__c=ids.get('3.2'), Typical_Duration_Days__c=25, Budget_Percentage__c=3.00,  Predecessor_Code__c='3.1.2', Dependency_Type__c='FS'),
new WBS_Template_Item__c(WBS_Template__c=t1.Id, Name='Cement Mill Raft Foundation & Grouting Pads',            Code__c='3.2.2', Level__c=3, Sequence__c=2,  Parent_Template_Item__c=ids.get('3.2'), Typical_Duration_Days__c=20, Budget_Percentage__c=2.50,  Predecessor_Code__c='3.1.2', Dependency_Type__c='FS'),
new WBS_Template_Item__c(WBS_Template__c=t1.Id, Name='Preheater Tower Structural Steel Erection',              Code__c='3.2.3', Level__c=3, Sequence__c=3,  Parent_Template_Item__c=ids.get('3.2'), Typical_Duration_Days__c=35, Budget_Percentage__c=5.00,  Predecessor_Code__c='2.2.1,3.1.2', Dependency_Type__c='FS'),
// 4.1 Equipment Erection
new WBS_Template_Item__c(WBS_Template__c=t1.Id, Name='Rotary Kiln Assembly, Shell Welding & Erection',         Code__c='4.1.1', Level__c=3, Sequence__c=1,  Parent_Template_Item__c=ids.get('4.1'), Typical_Duration_Days__c=30, Budget_Percentage__c=6.00,  Predecessor_Code__c='2.1.1,3.2.1', Dependency_Type__c='FS'),
new WBS_Template_Item__c(WBS_Template__c=t1.Id, Name='Cement Mill Erection, Alignment & Trial Grinding',       Code__c='4.1.2', Level__c=3, Sequence__c=2,  Parent_Template_Item__c=ids.get('4.1'), Typical_Duration_Days__c=20, Budget_Percentage__c=4.00,  Predecessor_Code__c='2.1.2,3.2.2', Dependency_Type__c='FS'),
new WBS_Template_Item__c(WBS_Template__c=t1.Id, Name='Preheater Cyclone & Calciner Installation',              Code__c='4.1.3', Level__c=3, Sequence__c=3,  Parent_Template_Item__c=ids.get('4.1'), Typical_Duration_Days__c=25, Budget_Percentage__c=5.00,  Predecessor_Code__c='2.1.3,3.2.3', Dependency_Type__c='FS'),
// 4.2 Piping Installation
new WBS_Template_Item__c(WBS_Template__c=t1.Id, Name='Process Piping Fabrication, Erection & Hydro Test',      Code__c='4.2.1', Level__c=3, Sequence__c=1,  Parent_Template_Item__c=ids.get('4.2'), Typical_Duration_Days__c=25, Budget_Percentage__c=3.50,  Predecessor_Code__c='2.2.2,4.1.1', Dependency_Type__c='FS'),
new WBS_Template_Item__c(WBS_Template__c=t1.Id, Name='Utility & Service Piping (Air, Water, Fuel Oil)',        Code__c='4.2.2', Level__c=3, Sequence__c=2,  Parent_Template_Item__c=ids.get('4.2'), Typical_Duration_Days__c=20, Budget_Percentage__c=2.00,  Predecessor_Code__c='4.2.1', Dependency_Type__c='SS'),
// 5.1 Electrical Systems
new WBS_Template_Item__c(WBS_Template__c=t1.Id, Name='HT/LT Cable Laying, Tray Routing & Termination',        Code__c='5.1.1', Level__c=3, Sequence__c=1,  Parent_Template_Item__c=ids.get('5.1'), Typical_Duration_Days__c=25, Budget_Percentage__c=3.00,  Predecessor_Code__c='2.2.3,3.2.3', Dependency_Type__c='FS'),
new WBS_Template_Item__c(WBS_Template__c=t1.Id, Name='Motor Control Centre (MCC) & VFD Installation',         Code__c='5.1.2', Level__c=3, Sequence__c=2,  Parent_Template_Item__c=ids.get('5.1'), Typical_Duration_Days__c=20, Budget_Percentage__c=2.50,  Predecessor_Code__c='5.1.1', Dependency_Type__c='FS'),
new WBS_Template_Item__c(WBS_Template__c=t1.Id, Name='Lighting, Earthing, Lightning Protection & UPS',        Code__c='5.1.3', Level__c=3, Sequence__c=3,  Parent_Template_Item__c=ids.get('5.1'), Typical_Duration_Days__c=15, Budget_Percentage__c=1.50,  Predecessor_Code__c='5.1.2', Dependency_Type__c='SS'),
// 5.2 Instrumentation & Control
new WBS_Template_Item__c(WBS_Template__c=t1.Id, Name='Field Instrumentation, Hook-Up & Impulse Tubing',        Code__c='5.2.1', Level__c=3, Sequence__c=1,  Parent_Template_Item__c=ids.get('5.2'), Typical_Duration_Days__c=20, Budget_Percentage__c=2.50,  Predecessor_Code__c='4.1.1,5.1.1', Dependency_Type__c='FS'),
new WBS_Template_Item__c(WBS_Template__c=t1.Id, Name='DCS/PLC Engineering, FAT, SAT & Historian Setup',       Code__c='5.2.2', Level__c=3, Sequence__c=2,  Parent_Template_Item__c=ids.get('5.2'), Typical_Duration_Days__c=25, Budget_Percentage__c=3.00,  Predecessor_Code__c='5.2.1', Dependency_Type__c='FS'),
// 6.1 Pre-Commissioning
new WBS_Template_Item__c(WBS_Template__c=t1.Id, Name='Mechanical Completion Certificate & Punchlist A/B',     Code__c='6.1.1', Level__c=3, Sequence__c=1,  Parent_Template_Item__c=ids.get('6.1'), Typical_Duration_Days__c=10, Budget_Percentage__c=1.00,  Predecessor_Code__c='4.2.1,5.2.2', Dependency_Type__c='FS'),
new WBS_Template_Item__c(WBS_Template__c=t1.Id, Name='Loop Check, Calibration, SIL & Interlock Verification', Code__c='6.1.2', Level__c=3, Sequence__c=2,  Parent_Template_Item__c=ids.get('6.1'), Typical_Duration_Days__c=12, Budget_Percentage__c=0.80,  Predecessor_Code__c='6.1.1', Dependency_Type__c='FS'),
// 6.2 Trial Operations
new WBS_Template_Item__c(WBS_Template__c=t1.Id, Name='Cold Commissioning & No-Load Trial Run',                 Code__c='6.2.1', Level__c=3, Sequence__c=1,  Parent_Template_Item__c=ids.get('6.2'), Typical_Duration_Days__c=12, Budget_Percentage__c=0.80,  Predecessor_Code__c='6.1.2', Dependency_Type__c='FS'),
new WBS_Template_Item__c(WBS_Template__c=t1.Id, Name='Hot Commissioning, Performance Test & RFSU Handover',   Code__c='6.2.2', Level__c=3, Sequence__c=2,  Parent_Template_Item__c=ids.get('6.2'), Typical_Duration_Days__c=15, Budget_Percentage__c=1.00,  Predecessor_Code__c='6.2.1', Dependency_Type__c='FS')
};
insert ins;
System.debug('Template 1 created – ' + t1.Id + '  leaf items: ' + ins.size());

// ──────────────────────────────────────────────────────────────────
// TEMPLATE 2 : Captive Power Plant (CPP) – 50 MW Coal/Lignite
// 23 work packages across 5 phases
// ──────────────────────────────────────────────────────────────────
WBS_Template__c t2 = new WBS_Template__c(
    Name = 'Captive Power Plant (CPP) – 50 MW EPC',
    Is_Active__c = true
);
insert t2;

ids = new Map<String, Id>();

ins = new List<WBS_Template_Item__c>{
    new WBS_Template_Item__c(WBS_Template__c=t2.Id, Name='Engineering & FEED',               Code__c='1', Level__c=1, Sequence__c=1),
    new WBS_Template_Item__c(WBS_Template__c=t2.Id, Name='Procurement',                      Code__c='2', Level__c=1, Sequence__c=2),
    new WBS_Template_Item__c(WBS_Template__c=t2.Id, Name='Civil Construction',               Code__c='3', Level__c=1, Sequence__c=3),
    new WBS_Template_Item__c(WBS_Template__c=t2.Id, Name='Mechanical & Electrical Works',    Code__c='4', Level__c=1, Sequence__c=4),
    new WBS_Template_Item__c(WBS_Template__c=t2.Id, Name='Commissioning & COD',              Code__c='5', Level__c=1, Sequence__c=5)
};
insert ins;
for (WBS_Template_Item__c ti : ins) ids.put(ti.Code__c, ti.Id);

ins = new List<WBS_Template_Item__c>{
    new WBS_Template_Item__c(WBS_Template__c=t2.Id, Name='FEED & Basic Engineering',         Code__c='1.1', Level__c=2, Sequence__c=1, Parent_Template_Item__c=ids.get('1')),
    new WBS_Template_Item__c(WBS_Template__c=t2.Id, Name='Detailed Engineering',             Code__c='1.2', Level__c=2, Sequence__c=2, Parent_Template_Item__c=ids.get('1')),
    new WBS_Template_Item__c(WBS_Template__c=t2.Id, Name='Major Equipment',                  Code__c='2.1', Level__c=2, Sequence__c=1, Parent_Template_Item__c=ids.get('2')),
    new WBS_Template_Item__c(WBS_Template__c=t2.Id, Name='Balance of Plant Materials',       Code__c='2.2', Level__c=2, Sequence__c=2, Parent_Template_Item__c=ids.get('2')),
    new WBS_Template_Item__c(WBS_Template__c=t2.Id, Name='Site & Foundations',               Code__c='3.1', Level__c=2, Sequence__c=1, Parent_Template_Item__c=ids.get('3')),
    new WBS_Template_Item__c(WBS_Template__c=t2.Id, Name='Civil Structures',                 Code__c='3.2', Level__c=2, Sequence__c=2, Parent_Template_Item__c=ids.get('3')),
    new WBS_Template_Item__c(WBS_Template__c=t2.Id, Name='Boiler & Auxiliaries',             Code__c='4.1', Level__c=2, Sequence__c=1, Parent_Template_Item__c=ids.get('4')),
    new WBS_Template_Item__c(WBS_Template__c=t2.Id, Name='Turbine, Generator & Electrical',  Code__c='4.2', Level__c=2, Sequence__c=2, Parent_Template_Item__c=ids.get('4')),
    new WBS_Template_Item__c(WBS_Template__c=t2.Id, Name='Pre-Commissioning',                Code__c='5.1', Level__c=2, Sequence__c=1, Parent_Template_Item__c=ids.get('5')),
    new WBS_Template_Item__c(WBS_Template__c=t2.Id, Name='Trial Run & COD',                  Code__c='5.2', Level__c=2, Sequence__c=2, Parent_Template_Item__c=ids.get('5'))
};
insert ins;
for (WBS_Template_Item__c ti : ins) ids.put(ti.Code__c, ti.Id);

ins = new List<WBS_Template_Item__c>{
// 1.1 FEED
new WBS_Template_Item__c(WBS_Template__c=t2.Id, Name='Site Feasibility & Electrical Load Study',               Code__c='1.1.1', Level__c=3, Sequence__c=1, Parent_Template_Item__c=ids.get('1.1'), Typical_Duration_Days__c=12, Budget_Percentage__c=0.80, Control_Account__c=true),
new WBS_Template_Item__c(WBS_Template__c=t2.Id, Name='Boiler & Turbine Configuration Study',                   Code__c='1.1.2', Level__c=3, Sequence__c=2, Parent_Template_Item__c=ids.get('1.1'), Typical_Duration_Days__c=10, Budget_Percentage__c=0.80, Predecessor_Code__c='1.1.1', Dependency_Type__c='FS'),
new WBS_Template_Item__c(WBS_Template__c=t2.Id, Name='Grid Connectivity & Synchronisation Study',             Code__c='1.1.3', Level__c=3, Sequence__c=3, Parent_Template_Item__c=ids.get('1.1'), Typical_Duration_Days__c=8,  Budget_Percentage__c=0.60, Predecessor_Code__c='1.1.1', Dependency_Type__c='SS'),
// 1.2 Detailed Engineering
new WBS_Template_Item__c(WBS_Template__c=t2.Id, Name='Boiler Foundation & Civil Drawings',                    Code__c='1.2.1', Level__c=3, Sequence__c=1, Parent_Template_Item__c=ids.get('1.2'), Typical_Duration_Days__c=14, Budget_Percentage__c=0.80, Predecessor_Code__c='1.1.2', Dependency_Type__c='FS'),
new WBS_Template_Item__c(WBS_Template__c=t2.Id, Name='Turbine Hall Foundation & Pedestal Drawings',           Code__c='1.2.2', Level__c=3, Sequence__c=2, Parent_Template_Item__c=ids.get('1.2'), Typical_Duration_Days__c=12, Budget_Percentage__c=0.80, Predecessor_Code__c='1.1.2', Dependency_Type__c='FS'),
new WBS_Template_Item__c(WBS_Template__c=t2.Id, Name='SLD, Protection & Switchyard Drawings',                Code__c='1.2.3', Level__c=3, Sequence__c=3, Parent_Template_Item__c=ids.get('1.2'), Typical_Duration_Days__c=15, Budget_Percentage__c=1.00, Predecessor_Code__c='1.1.3', Dependency_Type__c='FS'),
// 2.1 Major Equipment
new WBS_Template_Item__c(WBS_Template__c=t2.Id, Name='CFBC/AFBC Boiler Supply (Thermax/BHEL)',               Code__c='2.1.1', Level__c=3, Sequence__c=1, Parent_Template_Item__c=ids.get('2.1'), Typical_Duration_Days__c=50, Budget_Percentage__c=15.00, Predecessor_Code__c='1.1.2', Dependency_Type__c='FS'),
new WBS_Template_Item__c(WBS_Template__c=t2.Id, Name='Steam Turbine Generator Supply (BHEL/BHEL-Triveni)',   Code__c='2.1.2', Level__c=3, Sequence__c=2, Parent_Template_Item__c=ids.get('2.1'), Typical_Duration_Days__c=45, Budget_Percentage__c=18.00, Predecessor_Code__c='1.1.2', Dependency_Type__c='FS'),
new WBS_Template_Item__c(WBS_Template__c=t2.Id, Name='Main Transformer, HT Switchgear & DG Set',            Code__c='2.1.3', Level__c=3, Sequence__c=3, Parent_Template_Item__c=ids.get('2.1'), Typical_Duration_Days__c=30, Budget_Percentage__c=8.00,  Predecessor_Code__c='1.2.3', Dependency_Type__c='FS'),
// 2.2 BoP Materials
new WBS_Template_Item__c(WBS_Template__c=t2.Id, Name='Piping, Valves & Fittings Supply',                     Code__c='2.2.1', Level__c=3, Sequence__c=1, Parent_Template_Item__c=ids.get('2.2'), Typical_Duration_Days__c=25, Budget_Percentage__c=4.00,  Predecessor_Code__c='1.2.1', Dependency_Type__c='FS'),
new WBS_Template_Item__c(WBS_Template__c=t2.Id, Name='Instrument, Control & DCS System Supply',             Code__c='2.2.2', Level__c=3, Sequence__c=2, Parent_Template_Item__c=ids.get('2.2'), Typical_Duration_Days__c=28, Budget_Percentage__c=5.00,  Predecessor_Code__c='1.2.3', Dependency_Type__c='FS'),
// 3.1 Site & Foundations
new WBS_Template_Item__c(WBS_Template__c=t2.Id, Name='Site Clearing, Preparation & Earthworks',              Code__c='3.1.1', Level__c=3, Sequence__c=1, Parent_Template_Item__c=ids.get('3.1'), Typical_Duration_Days__c=12, Budget_Percentage__c=1.00,  Predecessor_Code__c='1.2.1', Dependency_Type__c='FS'),
new WBS_Template_Item__c(WBS_Template__c=t2.Id, Name='Boiler Raft Foundation (Piling + RCC)',                Code__c='3.1.2', Level__c=3, Sequence__c=2, Parent_Template_Item__c=ids.get('3.1'), Typical_Duration_Days__c=25, Budget_Percentage__c=3.00,  Predecessor_Code__c='3.1.1', Dependency_Type__c='FS'),
new WBS_Template_Item__c(WBS_Template__c=t2.Id, Name='Turbine Hall Foundation & Pedestal',                   Code__c='3.1.3', Level__c=3, Sequence__c=3, Parent_Template_Item__c=ids.get('3.1'), Typical_Duration_Days__c=22, Budget_Percentage__c=2.50,  Predecessor_Code__c='3.1.1', Dependency_Type__c='FS'),
// 3.2 Civil Structures
new WBS_Template_Item__c(WBS_Template__c=t2.Id, Name='Cooling Tower, Pump House & Water Treatment',          Code__c='3.2.1', Level__c=3, Sequence__c=1, Parent_Template_Item__c=ids.get('3.2'), Typical_Duration_Days__c=18, Budget_Percentage__c=2.00,  Predecessor_Code__c='3.1.1', Dependency_Type__c='FS'),
new WBS_Template_Item__c(WBS_Template__c=t2.Id, Name='Coal/Fuel Handling Yard & Ash Silo',                   Code__c='3.2.2', Level__c=3, Sequence__c=2, Parent_Template_Item__c=ids.get('3.2'), Typical_Duration_Days__c=20, Budget_Percentage__c=2.00,  Predecessor_Code__c='3.1.1', Dependency_Type__c='FS'),
// 4.1 Boiler
new WBS_Template_Item__c(WBS_Template__c=t2.Id, Name='Boiler Erection, Refractory & Hydro Test',             Code__c='4.1.1', Level__c=3, Sequence__c=1, Parent_Template_Item__c=ids.get('4.1'), Typical_Duration_Days__c=30, Budget_Percentage__c=6.00,  Predecessor_Code__c='2.1.1,3.1.2', Dependency_Type__c='FS'),
new WBS_Template_Item__c(WBS_Template__c=t2.Id, Name='ESP, FGD & Fuel Handling System Installation',        Code__c='4.1.2', Level__c=3, Sequence__c=2, Parent_Template_Item__c=ids.get('4.1'), Typical_Duration_Days__c=22, Budget_Percentage__c=3.00,  Predecessor_Code__c='4.1.1', Dependency_Type__c='SS'),
// 4.2 Turbine & Electrical
new WBS_Template_Item__c(WBS_Template__c=t2.Id, Name='Steam Turbine Erection, Alignment & Lube Oil Flush',  Code__c='4.2.1', Level__c=3, Sequence__c=1, Parent_Template_Item__c=ids.get('4.2'), Typical_Duration_Days__c=25, Budget_Percentage__c=5.00,  Predecessor_Code__c='2.1.2,3.1.3', Dependency_Type__c='FS'),
new WBS_Template_Item__c(WBS_Template__c=t2.Id, Name='Generator, Transformer & Switchyard Erection',        Code__c='4.2.2', Level__c=3, Sequence__c=2, Parent_Template_Item__c=ids.get('4.2'), Typical_Duration_Days__c=20, Budget_Percentage__c=4.00,  Predecessor_Code__c='4.2.1,2.1.3', Dependency_Type__c='FS'),
new WBS_Template_Item__c(WBS_Template__c=t2.Id, Name='BoP Piping, Cabling & Instrument Installation',       Code__c='4.2.3', Level__c=3, Sequence__c=3, Parent_Template_Item__c=ids.get('4.2'), Typical_Duration_Days__c=22, Budget_Percentage__c=4.00,  Predecessor_Code__c='4.1.1,2.2.1', Dependency_Type__c='FS'),
// 5.1 Pre-Commissioning
new WBS_Template_Item__c(WBS_Template__c=t2.Id, Name='Steam Blowing, Hydro Test & Chemical Cleaning',        Code__c='5.1.1', Level__c=3, Sequence__c=1, Parent_Template_Item__c=ids.get('5.1'), Typical_Duration_Days__c=15, Budget_Percentage__c=1.00,  Predecessor_Code__c='4.2.3', Dependency_Type__c='FS'),
new WBS_Template_Item__c(WBS_Template__c=t2.Id, Name='Control & Protection Loop Check & SCADA Verification', Code__c='5.1.2', Level__c=3, Sequence__c=2, Parent_Template_Item__c=ids.get('5.1'), Typical_Duration_Days__c=12, Budget_Percentage__c=0.80,  Predecessor_Code__c='2.2.2,4.2.2', Dependency_Type__c='FS'),
// 5.2 Trial Run
new WBS_Template_Item__c(WBS_Template__c=t2.Id, Name='First Roll of Turbine & Grid Synchronisation',         Code__c='5.2.1', Level__c=3, Sequence__c=1, Parent_Template_Item__c=ids.get('5.2'), Typical_Duration_Days__c=10, Budget_Percentage__c=0.80,  Predecessor_Code__c='5.1.1,5.1.2', Dependency_Type__c='FS'),
new WBS_Template_Item__c(WBS_Template__c=t2.Id, Name='72-Hour Performance Guarantee Run & COD Certificate',  Code__c='5.2.2', Level__c=3, Sequence__c=2, Parent_Template_Item__c=ids.get('5.2'), Typical_Duration_Days__c=15, Budget_Percentage__c=1.00,  Predecessor_Code__c='5.2.1', Dependency_Type__c='FS')
};
insert ins;
System.debug('Template 2 created – ' + t2.Id + '  leaf items: ' + ins.size());
System.debug('Both templates complete. Refresh Templates modal in wbsTreeGrid to see them.');
