# WarpDrive EPC Org — Discovery Documentation

> Discovery captured **2026-06-11** for demo preparation. Focus: **RFI** and **Project Management**, plus the supporting modules that drive the PM workflow.

## Org facts

| Item | Value |
|---|---|
| Org name | WarpDrive EPC Org |
| Alias | `epc` |
| Username | shubham.nayak@warpdrivetech.in.epc |
| Instance | https://wdepcorg-dev-ed.develop.my.salesforce.com |
| Org Id | 00Dbn00000qOFGzEAO |
| Edition | Developer Edition |
| API version | 66.0 |

Connect: `sf data query -o epc ...` / `sf org open -o epc`

**What is EPC?** Engineering, Procurement & Construction — the org models the full project lifecycle of a contractor: tendering/estimation → award → project setup (WBS) → engineering/document control → procurement → site execution → progress & earned value → quality/HSE → handover.

## Documentation index

| Doc | Contents |
|---|---|
| [01-rfi-module.md](01-rfi-module.md) | **RFI deep dive** — construction RFI (`RFI__c`) + tender RFI (`RFI_Query__c`), SLA engine, templates, automation, UI |
| [02-project-management.md](02-project-management.md) | **PM deep dive** — Project, WBS hierarchy, Work Packages, EVM engine, Daily Progress, Progress Claims, Change Orders, resources/timesheets |
| [03-supporting-modules.md](03-supporting-modules.md) | Document Control, Quality/HSE, Procurement, Estimation & Tendering — the modules feeding the PM workflow |
| [04-automation-apex-ui.md](04-automation-apex-ui.md) | Full inventory: Apex classes, Flows, LWC, Aura, Apps, FlexiPages, Agentforce bots |

Working artifacts: `raw/` (per-object describe JSON), `apex/` (retrieved class bodies), `counts.txt` (record volumes), `describe.py` (helper).

## Module map (86 custom objects)

```
ESTIMATION / TENDERING        PROJECT MANAGEMENT (core)        SITE EXECUTION
  Tender, Tender_Document       Project ──┬─ WBS_Item            Daily_Progress
  Enquiry_team_members          (EVM,     ├─ Work_Package        Resource
  Costing_Sheet                  G0-G6)   ├─ Milestone           Crew / Project_Team
  BoQ_Item                                ├─ WBS_Template(_Item) Timesheet(_line)
  Commercial/Technical_Proposal           └─ Change_Order        Equipment(_Log/_assignment)
  Proposal_Submission                                            Progress_Claim
  Quote, Quote_Item             RFI (engineering)
  Tab/Template_* (BoQ builder)    RFI__c ── RFI_Query__c       QUALITY / HSE
                                                                 NCR, Observation
DOCUMENT CONTROL              PROCUREMENT                        Punch_List_Item
  Drawing                       Material_Takeoff                 Inspection_Request
  Drawing_Annotation(_Reply)    Material_Requisition / MR_Line   Inspection_Test_Plan
  Document_Revision             RFQ / RFQ_Line / RFQ_Vendor      Permit_to_Work
  Submittal                       RFQ_Line_Award                 Risk_Evaluation
  Transmittal                   Supplier / Supplier_Quote        Handover_Package
                                Purchase_Order / PO_Line       
                                Goods_Receipt / Receipt_Line   REFERENCE / CONFIG
                                Subcontract(_Package/_Invoice)   Country, Location, Rate
                                Inventory(_Location/_Stock)      Operating_Unit, Account_Site
                                Material_Issue                   Default_Value, Mapping_Schema
```

## Data volumes (records present, 2026-06-11)

Populated objects indicate what is demo-ready. Empty objects are schema-only.

| Tier | Objects |
|---|---|
| **High (>100)** | Tab_Line_Item (14,505), WBS_Item (1,236), Tab (700), Default_Value (489), Template_Column (314), WBS_Template_Item (233), Enquiry_team_members (228), Quote_Item (164), Template_Row (117) |
| **Medium (20–100)** | RFQ_Line (98), MR_Line (96), Work_Package (93), PO_Line (92), Supplier_Quote (78), Costing_Sheet (73), Purchase_Order (65), Daily_Progress (59), Drawing_Annotation (47), Drawing (45), RFQ (42), Permit_to_Work (37), Resource (36), Project (29), Material_Requisition (27), **RFI (25)**, Material_Takeoff (25), Goods_Receipt (25), Tender (20) |
| **Low (1–19)** | Submittal (19), Risk_Evaluation (19), **RFI_Query (12)**, Observation (12), Change_Order (12), Commercial/Technical_Proposal (10/9), Punch_List_Item (9), NCR (8), WBS_Template (7), Progress_Claim (6), Inspection_Request (5), Quote (3), BoQ_Item (3) |
| **Empty (0)** | Milestone, Project_Team, Timesheet(_line), Crew, Supplier, RFQ_Item/Vendor/Line_Award, Subcontract_*, Equipment_*, Inventory/Material_Issue, Handover_Package, Inspection_Test_Plan, Transmittal, and reference objects |

> **Demo note:** PM, RFI, Procurement, Document Control, and Quality/HSE all have live data. **Timesheets, Milestones, Crew, Project Team, and Equipment are schema-only** (built but not populated) — avoid demoing those as data-driven.

## Lightning apps

| App | Purpose |
|---|---|
| **EPC** | Primary EPC application (project controls console) |
| **EPC_MOBILE** | Field/site mobile experience (utility bar configured) |
| **WD_EPC** | EPC workspace variant |
| **WD_EPC_Tenders** | Tendering / proposal workspace |

Key console FlexiPages (record/workspace pages): `Project_Command_Center`, `Engineering_Workspace`, `Procurement_Workspace`, `Quality_HSE_Workspace`, `Site_Execution_Workspace`, `Create_Publish_Tender`.

## Agentforce

Two bots are configured: **`EPC_AGENT`** and **`Costing_Sheet_Agent`** (see [04-automation-apex-ui.md](04-automation-apex-ui.md)). AI also surfaces via Prompt-template flows (`WBS AI Insight`, `Flow_Procurement AI – Intelligent Vendor Decision Engine`) and the `WBS_Item__c.AI_Insight__c` field.
