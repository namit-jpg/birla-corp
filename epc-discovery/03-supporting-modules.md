# Supporting Modules — feeding the PM & RFI workflow

These modules surround Project Management and are tightly coupled to it (most reference `Project__c` and `WBS_Item__c`). Documented here at module depth; the priority modules (RFI, PM) are in their own docs.

---

## A. Document Control / Engineering

The engineering deliverable backbone — Drawings + revisions, markups, transmittals, submittals. RFIs reference Drawings (`RFI__c.Drawing__c`).

### Drawing (`Drawing__c`, a0B, 45 recs)
`Drawing_Number__c`, `Title__c`, `Current_Revision__c`/`Current_Revision_Number__c`/`Revision__c`, `Discipline__c`, `File__c`, `File_Type__c` (PDF/DWG/DXF/3D Model/Image), `Google_Drive_URL__c`, `Issue_Date__c`, `Project__c` (required), `StatusWD__c` = Draft / Pending / For Review / Approved / Rejected / Recall / **IFC** (Issued For Construction).
- Apex: `DrawingController`, `SimpleDrawingController`, `EPCDrawingService`, `DrawingRevisionService`.
- LWC: `drawingViewer`, `epcDrawingRegister`, `epcEngineeringDesk`.
- Flow: **`EPC Approval Process for Drawing`** (RecordAfterSave) drives `StatusWD__c`.

### Drawing Annotation (`Drawing_Annotation__c`, a0w, 47) + Reply (`Drawing_Annotation_Reply__c`, a0x, 3)
On-drawing markup: `Annotation_Type__c` (Cloud/Text/Arrow/Highlight/Measurement/Rectangle/Circle), `Coordinates__c` (JSON, 128k), `Comment__c`, `Status__c` (Active/Resolved/Archived), `Created_By__c`, parent `Drawing__c`. Replies thread under an annotation.
- Apex: `DrawingAnnotationService`, `DrawingAnnotationNotificationService`. LWC: `drawingViewer`.

### Document Revision (`Document_Revision__c`, a0C, 0)
Revision register: `Drawing__c`, `Rev_Code__c`/`Revision_Number__c`, `Reason__c`, `Superseded__c`, `Issued_By__c`, `Issue_Date__c`, `Status__c`. (Schema-only.)

### Submittal (`Submittal__c`, a0D, 19)
Formal submission for review/approval (shop drawings, material data): `Project__c`, `Drawing__c`, `WBS_Item__c`, `Type__c`, `Discipline__c`, `Status__c` (Draft/Submitted/Under_Review/Pending/Approved/Approved as Noted/Rejected), `Reviewer__c`, `Submission_Date__c`/`Due_Date__c`/`Review_Date__c`, `Days_In_Review__c`, `Review_Comments__c`.
- Apex: `SubmittalController`, `EPCSubmittalService`, `EPCSubmittalTrackerService`. LWC: `epcSubmittalTracker`.
- Flow: **`EPC Submittal Workflow RTF`** (RecordAfterSave).

### Transmittal (`Transmittal__c`, a0L, 0) & Handover Package (`Handover_Package__c`, a08, 0)
Transmittal = document issue record (`Purpose__c`, `Recipients__c`, `Sent_Date__c`, `Drawing__c`). Handover Package = close-out bundle (`Package_Code__c`, `Scope__c`, `Status__c` Draft→In Progress→Ready for Client→Complete); Punch List Items roll into it. Apex `EPCHandoverBuilderService`, LWC `epcHandoverBuilder`. (Both schema-only.)

---

## B. Quality & HSE

Site quality and health-safety-environment. All reference `Project__c`, most reference `WBS_Item__c`/`Work_Package__c`. Surfaced in `Quality_HSE_Workspace`.

### NCR — Non-Conformance Report (`NCR__c`, a0F, 8)
`Project__c` (req), `Status__c` (Open/Under_Investigation/Corrective_Action/Closed), `Severity__c`, `Category__c`, `Type__c`, `Root_Cause__c`, `Corrective_Action__c`, `Opened_By__c`/`Assigned_To__c`/`Responsible_Party__c`, `Identified_Date__c`/`Opened_Date__c`/`Resolution_Date__c`/`Closed_Date__c`.

### Observation (`Observation__c`, a0H, 12)
Safety/quality/environmental observation: `Type__c` (Safety/Quality/Environmental), `Risk_Level__c`, `Status__c` (Open/Closed), `Action_Required__c`, `Location__c`, `Observed_By__c`, `Observation_Date__c`. Apex `EPCSafetyObservationService`, LWC `epcSafetyObservation`.

### Punch List Item (`Punch_List_Item__c`, a0E, 9)
Snag/defect close-out: `Description__c` (req), `Status__c` (Open/In Progress/Closed, req), `Priority__c`, `Category__c`, `Assigned_To__c`, `Due_Date__c`, links to `Work_Package__c`, `WBS_Item__c`, `Project__c`, `Handover_Package__c`.
- Flow: **`EPC Punch List Consolidation RTF`** (RecordAfterSave) — rolls punch items into handover.

### Inspection Request (`Inspection_Request__c`, a0K, 5) & ITP (`Inspection_Test_Plan__c`, a0S, 0)
IR = request for inspection (`Status__c` Requested/Accepted/Rejected/Passed/Failed, `Result__c`, `Lot__c`, `Area__c`, `Requested_Date__c`/`Inspected_Date__c`, links to WBS/Work Package/Purchase Order/ITP). ITP = the test plan (`Discipline__c`, `Hold_Witness_Points__c`, `Status__c`). (ITP schema-only.)

### Permit to Work (`Permit_to_Work__c`, a0G, 37)
HSE work permits: `Permit_Type__c` (Hot_Work/Confined_Space/Working_at_Height), `Status__c` (Draft/Approved/Active/Expired/Closed), `Valid_From__c`/`Valid_To__c` (datetime), `Area__c`/`Location__c`, `Work_Description__c`, `Issued_By__c`. Apex `EPCPermitToWorkPlannerService`, LWC `epcPermitToWorkPlanner`.

### Risk Evaluation (`Risk_Evaluation__c`, a1N, 19)
Pre-bid / project risk assessment — a large structured questionnaire (~55 fields) pairing each risk with a **mitigation plan**: commercial risks (Bank Guarantees, LDs, Payment Terms, Performance Guarantees, Price Basis, Taxes, Insurance) and technical risks (Design Complexity, Engineering Integration, Grid Interconnection, HSE, Material/Equipment Quality, Regulatory Compliance, Resource Availability, Site/Soil Conditions, Technology). Links to `Opportunity`. `Final_Go_ahead__c` gate. Flow: **`Risk Evaluation After Save`**. LWC quality hub: `epcQualityHseHub`, `epcPunchNcrDashboard`. Apex: `EPCQualityHSEController`, `EPCQualityHseHubService`, `EPCPunchNcrDashboardService`.

---

## C. Procurement

The buy-side chain, anchored to the project and WBS. Material need → requisition → RFQ → award → PO → receipt.

```
Material_Takeoff__c (a0N,25)  from Drawing/WBS — quantities needed
        │
Material_Requisition__c (a03,27) ──< MR_Line__c (a0X,96)   "what to buy"
        │  Status: Draft→Submitted→Approved→RFQ_Issued
        ▼
RFQ__c (42) ──< RFQ_Line__c (98)   ──< RFQ_Line_Award__c (0)
        └──< RFQ_Vendor__c (0)        ▲
Supplier__c (0) / Supplier_Quote__c (78) ─┘  vendor responses
        │
Purchase_Order__c (a0I,65) ──< PO_Line__c (a0W,92)
        │  Approval chain: Buyer → PM → Finance
        ▼
Goods_Receipt__c (a0c,25) ──< Receipt_Line__c (0)
Subcontract__c (1) ── Subcontract_Package__c (0) ── Subcontract_Invoice__c (0)
Inventory__c / Inventory_Location__c / Inventory_Stock__c / Material_Issue__c
```

### Material Takeoff (`Material_Takeoff__c`, 25)
Quantities derived from drawings: `Drawing__c`, `WBS_Item__c`, `Material_Code__c`/`MaterialWD__c`(→Product2), `Required_Qty__c`, `UoM__c`, `Need_By_Date__c`, `Status__c` (Draft/Pending/Approved/Rejected/Recall/Issued). Apex `MaterialTakeoffController`, `EPCMaterialTakeoffService`, `ImportMTOFromCSV`; LWC `epcMaterialTakeoff`. Flow **`EPC Approval Process for Material Takeoffs`**.

### Material Requisition (`Material_Requisition__c`, 27) + MR_Line (96)
Purchase request: `Project__c` (req), `WBS_Item__c`, `Work_Package__c`, `Priority__c` (Low/Medium/High/Critical), `Needed_By__c`, `Total_Estimated_Cost__c`, `Status__c` (Draft/Submitted/Approved/Rejected/Recall/RFQ_Issued), `Requested_By__c`/`Approved_By__c`. Lines: `Material__c`(→Product2), `Qty__c`, `Estimated_Unit/Total_Cost__c`, `Technical_Specs__c`, `Supplier_Quote__c`, `Category__c`/`Tag__c`.
- Apex: `MaterialRequisitionController`, `MRLineController`. LWC: surfaced in `epcProcurementConsole`.
- Flows: **`EPC Approval Process for Material Requisition`**, **`EPC Approval Process for MR Line`**, **`EPC Material Requisition Approval to RFQ RTF`** (auto-creates RFQ on approval), **`Rtf_mrlinecheck_thresholdlimit`** / **`RTF_NotifylimitcrossThreshold`** (budget threshold guards).

### RFQ family
`RFQ__c` (42) ─< `RFQ_Line__c` (98); vendors invited via `RFQ_Vendor__c`; bids compared and awarded via `RFQ_Line_Award__c`. Apex `RFQController_v2`, `RFQDataService`, `RFQQueryController`, `EpcRfqExplorerController`, `RFQPromptBridge` (AI). LWC `epcRfqExplorer`, `epcQuoteCompare`, `quoteGenerator`. AI flow **`Flow_Procurement AI – Intelligent Vendor Decision Engine`** scores vendors. `Supplier_Quote__c` (78) holds vendor pricing; `SupplierQuoteUploadController` ingests quotes. Flow **`Send Award Email`**.

### Purchase Order (`Purchase_Order__c`, 65) + PO_Line (92)
`Project__c`, `Vendor__c`(→Account), `Material_Requisition__c`, `Supplier_Quote__c`, `WBS_Item__c`, `Total_Value__c`, `Status__c` (Draft/Submitted for Approval/Buyer Approved/PM Approved/Finance Approved/Issued/Partially Received/Closed/Rejected), `Approval_Stage__c` (Buyer/PM/Finance), `ERP_PO_Number__c`, `Inco_Terms__c`, `Payment_Terms__c`. Lines carry `Qty_Received__c`/`Qty_Remaining__c` for receipt tracking + `WBS_Item__c` (this is the **AC source for EVM** — see PM doc §5).
- Apex: `PurchaseOrderController`, `PurchaseOrderTriggerHandler`, `POCreationService`, `EPCPoWorkflowService`, `EpcProcurementController`. LWC: `epcPoWorkflow`, `epcProcurementConsole`. Workspace `Procurement_Workspace`.
- ERP integration: `SapPoPublisher`, `ERPEventsPublisher`, `OracleSubcontractIngest`, `update_po_platformevent_flow`. Flow **`RTF_StockUpdateAFTERpO`**.

### Goods Receipt (`Goods_Receipt__c`, 25)
Receiving: `Purchase_Order__c`, `PO_Line__c`, `Received_Qty__c`, `Received_By__c`, `Receipt_Date__c`, `StatusWD__c` (Accepted/Rejected-Minor/Partial), `Condition_Rating__c`. LWC `epcGrnScanner`. Flows **`RTF_UpdateInventoryFrompom`**, **`RTF_updateTotalStock`** update inventory.

### Inventory & Subcontracts (mostly schema-only)
`Inventory__c`/`Inventory_Location__c`/`Inventory_Stock__c`/`Material_Issue__c` (warehouse), `Subcontract__c`(1)/`Subcontract_Package__c`/`Subcontract_Invoice__c` (subcontract management; `OracleSubcontractIngest` integration).

---

## D. Estimation & Tendering (pre-award)

The sell-side / bid phase that precedes a project. Heavily built (the BoQ engine is the largest data set in the org).

- **Tender (`Tender__c`, 20)** + `Tender_Document__c` — the opportunity to bid; `RFI_Query__c` clarifications hang off it (see RFI doc Part B). Apex `TenderCreateController`, `TenderDashboardController`, `TenderListingController`, `EPCTenderFinderController`, `TenderProposalController`, `TenderAuditBridgeController`. LWC `tenderCreate`, `tenderDashboard`, `tenderListing`, `epcTenderFinder`. FlexiPage `Create_Publish_Tender`.
- **Enquiry / team (`Enquiry_team_members__c`, 228)** — bid team; Apex `EnquiryTeamMemberTriggerHandler`, `EnquiryTaskTriggerHandler`; flow `log_enquiry`, `migrate_Team_Member_to_Opp_on_Lead_Converted`.
- **Costing Sheet (`Costing_Sheet__c`, 73)** — estimate workbook; Apex `EpcCostingSheetWorkbookController`, `EpcCostingSheetDetailController`, `CostingSheetEstimationCloneService`, `CostingSheetAgentAction`; LWC `epcCostingSheetOrginal`, `epcCostingUploader`; **`Costing_Sheet_Agent`** Agentforce bot. Tab `EPC_Costing`.
- **BoQ engine** — **`Tab_Line_Item__c` (14,505!)**, `Tab__c` (700), `Template_Master__c`/`Template_Tab__c`/`Template_Row__c`/`Template_Column__c`/`Template_Location__c`, `BoQ_Item__c`. A spreadsheet-style Bill of Quantities builder. Apex `BoqService`, `BoqPdfController`, `TabLineItemProcessor`, `EpcRfqExplorerController`; LWC `epcBoqBuilder`. (This is its own large subsystem — flag for a separate deep-dive if the demo needs BoQ.)
- **Proposals** — `Commercial_Proposal__c` (10), `Technical_Proposal__c` (9), `Proposal_Submission__c` (12), `Quote__c`/`Quote_Item__c`. Apex `CommercialProposalHandler`, `TechnicalProposalController`, `ProposalSubmissionHandler`, `ProposalDashboardController`, `QuoteGeneratorController`, `QuoteCompareController`; LWC `proposalWizard`, `proposalTable`, `proposalListing`, `editableTechnicalProposals`, `viewCommercialProposals`, `quoteTemplate`.

> The estimation/tender area is large and somewhat separate from the PM/RFI execution story. It is in scope as the upstream feeder (a won tender becomes a project), but consider a dedicated discovery pass if the demo emphasizes bidding/BoQ.
