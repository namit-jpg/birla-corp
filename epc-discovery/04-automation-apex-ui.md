# Automation, Apex & UI Inventory

Reference inventory of the technical layer. EPC-relevant items are grouped by module; standard/managed framework metadata (Service Cloud swarming, appointments, CMS, identity-verification flows, self-registration controllers) is omitted.

## Apex triggers (handler classes)
The org follows a handler pattern. Confirmed handlers:
- `RFITriggerHandler` — RFI close-date automation (see RFI doc).
- `WBSItemTriggerHandler` — WBS date/budget rollup (see PM doc).
- `PurchaseOrderTriggerHandler`, `EnquiryTeamMemberTriggerHandler`, `EnquiryTaskTriggerHandler`, `BaselineLockingTrigger` (baseline freeze).

## Apex classes by module (EPC-relevant)

| Module | Classes |
|---|---|
| **RFI** | `EPCRFIService`, `RFIController`, `RFITriggerHandler`, `RFIDashboardController`, `rfiQueryController`, `rfiQueryrUtility` |
| **Project / WBS / EVM** | `EVCalculator` (Queueable), `EVDataController`, `EPCEVMService`, `EPCBudgetService`, `WBSController`, `WBSItemCreator`, `WBSItemTriggerHandler`, `WBSTemplateService`, `EpcProjectHeader`, `BaselineLockingTrigger`, `LargeDataRollup` |
| **Site execution / progress** | `EPCDailyProgressService`, `EPCSiteExecutionController`, `EPCMobileDashboardService`, `EPCPhotoUploadService`, `EPCWorkPackageService`, `ResourceAssignmentHandler` |
| **Change / claims** | `EPCChangeOrderService`, `RetentionEngine`, `ApprovalProcessHelper` |
| **Document control** | `DrawingController`, `SimpleDrawingController`, `EPCDrawingService`, `DrawingRevisionService`, `DrawingAnnotationService`, `DrawingAnnotationNotificationService`, `EPCSubmittalService`, `EPCSubmittalTrackerService`, `SubmittalController`, `EPCDocumentService`, `DocumentNumberingService`, `EPCHandoverBuilderService` |
| **Quality / HSE** | `EPCQualityHSEController`, `EPCQualityHseHubService`, `EPCPunchNcrDashboardService`, `EPCSafetyObservationService`, `EPCPermitToWorkPlannerService`, `EPCIRQuickCreateService` |
| **Procurement** | `MaterialRequisitionController`, `MRLineController`, `MaterialTakeoffController`, `EPCMaterialTakeoffService`, `ImportMTOFromCSV`, `EPCProcurementController`, `EPCProcurementConsoleService`, `EpcProcurementController`, `PurchaseOrderController`, `PurchaseOrderTriggerHandler`, `POCreationService`, `EPCPoWorkflowService`, `RFQController_v2`, `RFQDataService`, `RFQQueryController`, `EpcRfqExplorerController`, `RFQPromptBridge`, `SupplierQuoteUploadController`, `QuoteCompareController`, `QuoteGeneratorController`, `EPCVendorKpiService`, `VendorAccountController`, `ProductController`, `ProductStagingController` |
| **Estimation / Tender / BoQ** | `BoqService`, `BoqPdfController`, `TabLineItemProcessor`, `CostingSheetAgentAction`, `CostingSheetEstimationCloneService`, `EpcCostingSheetWorkbookController`, `EpcCostingSheetDetailController`, `EpcCostingSheetControllerVijay`, `EpcCostingSheetControllerAbhijeet`, `TenderCreateController`, `TenderDashboardController`, `TenderDashboardStatsController`, `TenderListingController`, `TenderProposalController`, `TenderAuditBridgeController`, `EPCTenderFinderController`, `CommercialProposalHandler`, `TechnicalProposalController`, `ProposalSubmissionController`, `ProposalSubmissionHandler`, `ProposalDashboardController`, `ProposalTableController` |
| **Integration (ERP/Slack/Email)** | `SapPoPublisher`, `ERPEventsPublisher`, `OracleSubcontractIngest`, `SlackController`, `SlackLWCController`, `SlackActionHandler`, `SlackNotificationService(Impl)`, `SlackApprovalEnqueueHandler`, `SlackApprovalNotifications`, `SlackApprovalNotificationDTO`, `LeadEmailHandler`, `LeadEmailThreadController`, `SendOpportunityFileEmail` |
| **AI / Agentforce** | `InvokeAgentController`, `GoogleNewsPromptAction`, `RFQPromptBridge`, `CostingSheetAgentAction` |
| **Reporting / shared util** | `EPCReportingService`, `EPCNotificationService`, `EPCFeatureService`, `EPCFlowFaultLogger`, `DynamicSoqlService`, `FlowStringUtil`, `HandleErrorLog`, `TimelineController`, `FileController`, `FileUploadController`, `FileUploadHandler` |
| **Test / data gen** | `EPCTestDataGenerator`, `EpcTestDataFactory`, `DeleteMatchingProductCodes`, `SimpleTestClass` |

## Flows (EPC-relevant; trigger type)

**Record-triggered (after save) — core automation:**
| Flow | Drives |
|---|---|
| `EPC Daily Progress Update EV RTF` | EV recalc on daily progress |
| `EPC_RTF_updateDailyProgress` | Daily progress updates |
| `EPC Stage Gate Guard RTF` | Project stage gate G0–G6 enforcement |
| `EPC Approval Process for Project` | Project approval status |
| `EPC Approval Process for Drawing` | Drawing approval |
| `EPC Approval Process for Material Requisition` / `…for MR Line` | MR approval |
| `EPC Approval Process for Material Takeoffs` | MTO approval |
| `EPC Material Requisition Approval to RFQ RTF` | Auto-create RFQ on MR approval |
| `EPC Submittal Workflow RTF` | Submittal review workflow |
| `EPC Timesheet Approval RTF` | Timesheet approval |
| `EPC Punch List Consolidation RTF` | Punch → handover rollup |
| `EPC_ProgressClaim_Monthly_Sched` | Monthly progress claim |
| `EPC Equipment Log Creation RTF` | Equipment log |
| `EPC Warranty Case Assignment RTF` | Warranty case routing |
| `RTF_updatebudjectfromchangeorder` | Change-order → budget |
| `RTF_StockUpdateAFTERpO` / `RTF_UpdateInventoryFrompom` / `RTF_updateTotalStock` | Inventory after PO/receipt |
| `Rtf_mrlinecheck_thresholdlimit` / `RTF_NotifylimitcrossThreshold` | Budget threshold guards |
| `RTF_RfqQueryNotificationFlow` | Tender RFI (RFI_Query) notifications |
| `RTF_WorkpackagestartDateUpdate` / `RTF_CalculatePercentage` | WBS/work-package schedule |
| `Risk Evaluation After Save`, `Reason update`, `RTF_PscoreUpdateFLOW`, `RTF_updatefinaltechnicalscore`, `Send Award Email`, `RTF_Accountmailsendflow`, `RTF_send notification - legal team`, `WBS Item AI Insight Update`, `Flow_Hidden_AI_Data` | misc |

**Record-triggered (before save):** `RTF_Duration&predecessorFLOW` (WBS dates from duration/predecessor).
**Scheduled:** `EPC_RFI_SLA_Scheduler` (RFI SLA aging), `EPC_ProgressClaim_Monthly_Sched`.
**Screen / autolaunched:** `EPC WBS From Template Creation new` (+ `_Sub-Flow`), `Project_Initialization`, `EPC Agent Project Data`, `Upload RFP document`, `Log Enquiry`, `New Enquiry`.
**Prompt (Agentforce/Prompt Builder):** `WBS AI Insight`, `Field Service Mobile: Generate Pre Work Brief`.
**AI vendor:** `Flow_Procurement AI – Intelligent Vendor Decision Engine`, `FlowS_Procurement AI`.

## Lightning Web Components (EPC, 60+)

| Area | Components |
|---|---|
| **Project / EVM** | `epcProjectHeader`, `epcEVM`, `epcSCurve`, `epcStageGateIndicator`, `epcTimeline`, `epcGanttChart`, `portfolioGrid` |
| **WBS** | `epcWbsBuilder`, `epcWbsBuilderAdvanced` |
| **Work packages / execution** | `epcWorkPackageKanban`, `epcSiteExecutionBoard`, `epcDailyProgressCapture`, `epcDailyProgressForm`, `epcDailyProgressLite`, `epcMobileDashboard`, `epcPhotoUpload`, `resourceAllocation`, `resourceAssignmentModal` |
| **RFI** | `epcRfiConsole`, `rfiDashboard`, `rfiCreatePanel`, `epcEngineeringDesk`, `rfiQueryCard`, `rfiQueryCreator` |
| **Change / claims** | `epcChangeOrderConsole`, `epcChangeCostRoom`, `epcChangeCostRoomtwo` |
| **Document control** | `drawingViewer`, `epcDrawingRegister`, `epcDocumentManager`, `epcSubmittalTracker`, `epcHandoverBuilder` |
| **Quality / HSE** | `epcQualityHseHub`, `epcPunchNcrDashboard`, `epcSafetyObservation`, `epcPermitToWorkPlanner`, `epcIrQuickCreate` |
| **Procurement** | `epcProcurementConsole`, `epcPoWorkflow`, `epcRfqExplorer`, `epcQuoteCompare`, `epcquotecomparepocreation`, `quoteGenerator`, `epcMaterialTakeoff`, `epcGrnScanner`, `epcVendorKpi`, `vendorAccountList`, `productStagingCreator`, `rLinesTable` |
| **Estimation / tender / BoQ** | `epcBoqBuilder`, `epcCostingSheetOrginal`, `epcCostingUploader`, `uploadCostSheetFile`, `tenderCreate`, `tenderDashboard`, `tenderDashboardStats`, `tenderListing`, `tenderFilesList`, `epcTenderFinder`, `tenderAuditBridge`, `proposalWizard`, `proposalTable`, `proposalListing`, `proposalsubmission`, `editableTechnicalProposals`, `viewCommercialProposals`, `quoteTemplate`, `newMarginLwc` |
| **Shared / util / integration** | `epcToast`, `apexErrorUtils`, `uploadFile`, `myFlowRedirect`, `leadEmailThread`, `slackMessenger`, `createSQonCSV`, `flexi_grid__*` (managed grid package) |

## Aura components
`ProductStagingCreatorAura`, `navigatetoRecord`, `newTestLwcWrapper`, plus standard community/login (`forgotPassword`, `loginForm`, `selfRegister`, `setExpId`, `setStartUrl`, `SendInvite`).

## Lightning apps
`EPC` (primary), `EPC_MOBILE` (field), `WD_EPC`, `WD_EPC_Tenders`.

## Key console FlexiPages (workspaces)
`Project_Command_Center`, `Engineering_Workspace`, `Procurement_Workspace`, `Quality_HSE_Workspace`, `Site_Execution_Workspace`, `Create_Publish_Tender`. Plus per-object record pages (note multiple versions exist for several objects, e.g. `Work_Package_Record_Page` 1–5, `Change_Order_Record_Page` 1–2 — verify which is assigned to the active app/profile before demo).

## Agentforce / AI
- **Bots:** `EPC_AGENT` (general EPC assistant), `Costing_Sheet_Agent` (estimation assistant).
- **Prompt flows:** `WBS AI Insight` → writes `WBS_Item__c.AI_Insight__c`.
- **AI procurement:** `Flow_Procurement AI – Intelligent Vendor Decision Engine`, `RFQPromptBridge`.
- **Apex entry points:** `InvokeAgentController`, `CostingSheetAgentAction`, `GoogleNewsPromptAction`.

## Integrations
- **ERP:** `SapPoPublisher` (SAP PO push), `OracleSubcontractIngest` (Oracle subcontracts), `ERPEventsPublisher`, `update_po_platformevent_flow` (platform events). `Progress_Claim__c.Oracle_Invoice_ID__c` and `Purchase_Order__c.ERP_PO_Number__c` are the ERP correlation keys.
- **Slack:** `SlackController`, `SlackNotificationService`, `SlackApproval*` (approval notifications), `SalesforceToSlack` / `Send Slack Updates` flows, `slackMessenger` LWC.
- **Email:** `LeadEmailHandler`, `SendOpportunityFileEmail`.
- **Files:** Google Drive URL on Drawings; `FileController`/`FileUploadController`.

## Notable observations for the demo team
1. **Duplicate/parallel fields** on `Project__c` (EVM) and several objects (`Status__c` vs `StatusWD__c`, `CPI__c` vs `Cost_Performance_Index__c`) — multiple build iterations. Verify which field the live UI binds before quoting numbers.
2. **No validation rules** on the core PM/RFI objects — guard logic lives in flows and triggers, so behavior depends on automation being active.
3. **`EVCalculator` project-level write-back is partially commented out**; live EVM KPIs come from `EPCEVMService` (computed on read), not from persisted `Project__c` EVM fields.
4. **Empty-but-built modules:** Timesheets, Crews, Project Teams, Milestones, Equipment, Inventory, Subcontracts, ITP, Transmittal, Handover — demo as configured capability, not live data.
5. **Multiple record-page versions** per object — confirm active assignments.
