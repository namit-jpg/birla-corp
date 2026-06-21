# RFI Module — Deep Dive

The org has **two distinct RFI concepts** that serve different phases of the EPC lifecycle. Do not confuse them — they are separate objects with separate UI and automation.

| | `RFI__c` — **Construction / Engineering RFI** | `RFI_Query__c` — **Tender RFI / Clarification** |
|---|---|---|
| Phase | Project execution & engineering | Bidding / tender clarification |
| Anchored to | `Project__c` (also WBS, Work Package, Drawing) | `Tender__c` |
| Key prefix | `a01` | `a0t` |
| Records | 25 | 12 |
| Purpose | Formal question to designer/client requiring a documented answer, with SLA tracking | Bidder's clarification question against a published tender |
| Primary UI | `epcRfiConsole`, `rfiDashboard`, `rfiCreatePanel`, `epcEngineeringDesk` | `rfiQueryCard`, `rfiQueryCreator`, `tenderDashboard` |
| Controllers | `EPCRFIService`, `RFIController`, `RFITriggerHandler` | `rfiQueryController`, `RFIDashboardController` |

---

## Part A — Construction RFI (`RFI__c`)

The classic construction RFI: site/engineering raises a formal question, it is assigned and tracked against an SLA, answered, and closed. It links to the project schedule (WBS/Work Package) and to engineering deliverables (Drawing).

### Schema (`RFI__c`, prefix `a01`)

| Group | Fields |
|---|---|
| **Identity** | `Name` (RFI Number, auto), `Subject__c`, `Description__c`, `Category__c`, `Discipline__c`, `Work_type__c` |
| **Question / Answer** | `Question_Rich__c` (rich, 32k), `Answer_Rich__c` (rich, 32k), `Response__c`, `Instructions__c` |
| **Status & priority** | `Status__c` = Draft / Open / Under_Review / On Hold / Closed · `Priority__c` = High / Medium / Low · `Is_Active__c` |
| **People** | `Submitted_By__c`, `Assigned_To__c`, `Answered_By__c`, `Auto_Assign_To__c` (text user-id for template auto-assign), `OwnerId` |
| **Dates** | `Submitted_Date__c`, `Due_Date__c`, `Required_By__c`, `Response_Date__c`, `Answered_On__c`, `Close_Date__c` |
| **SLA metrics** | `SLA_Hours__c`, `Days_Open__c`, `AgeingBucket__c` |
| **Project links** | `Project__c`, `WBS_Item__c`, `Work_Package__c`, `Drawing__c` |
| **Template fields** | `Master_Label__c`, `Subject_Template__c`, `Question_Template__c`, `Sort_Order__c` (used with the `RFI_Template__mdt` mechanism, below) |

`Work_Package__c` also carries a reverse lookup `RFI__c` — a work package can point at the RFI blocking it.

### RFI lifecycle

```
 Draft ──► Open ──► Under_Review ──► Closed
              │           │             ▲
              └──► On Hold ┘             │
                                  (reopen clears Close_Date)
```

**Status automation (`RFITriggerHandler`, before insert/update):**
- On insert with `Status__c = Closed` and no `Close_Date__c` → set `Close_Date__c = TODAY`.
- On update, when status transitions **into** `Closed` and `Close_Date__c` is blank → set it to TODAY (a user-supplied close date is preserved).
- On update, when status transitions **out of** `Closed` (reopen) → `Close_Date__c` is cleared (audit intent).

`RFIController.updateRFIStatus` / `respondToRFI` additionally stamp `Response_Date__c = TODAY` when moving to Closed.

### SLA engine (`EPCRFIService`)

This is the analytical heart of the RFI module and the best demo asset. SLA target hours are derived from **priority**:

| Priority | SLA target |
|---|---|
| High | 8 hours |
| Medium | 24 hours |
| Low | 48 hours |
| (none) | 24 hours default |

`getSLAMetrics(projectId, startDate, endDate, includeDetails, includeTrends)` returns an `SLAMetrics` object:
- **Headline:** total RFIs, compliant count, **compliance rate %**, **avg response time (hrs)**, overdue count.
- **Status distribution** (count per status).
- **Overdue RFI details** (number, subject, due date, days overdue, assignee).
- **Team performance** (per assignee: total, compliant, compliance rate, avg response time) — *included when `includeDetails`*.
- **SLA exceptions** (breached RFIs with reason + days overdue) — *included when `includeDetails`*.
- **Trend data** (weekly compliance rate & response time series) — *included when `includeTrends`*.

Compliance logic: an RFI counts as "responded" when `Status__c ∈ {Closed, Responded}`; response time = `LastModifiedDate − CreatedDate`; compliant if response time ≤ SLA target for its priority. Draft/Cancelled are treated as within-SLA.

### Other `EPCRFIService` capabilities
- `getRFIs(projectId)` — cacheable list for the console.
- `createRFI` / `updateRFI` — single-record CRUD.
- `updateBulkRfiDetails(ids, status, priority, assignee)` — **bulk status/priority/reassignment** from the console.
- `exportRFIs(ids)` → CSV (RFI #, Subject, Status, Priority, Due Date, Assigned To).
- `getActiveUsers()` — assignee picker.

### `RFIController` (powers `epcEngineeringDesk`)
- `getRFIs(projectId)` — ordered by due date, limit 100.
- `getRFIMetrics(projectId)` — `{totalRFIs, openRFIs, overdueRFIs, avgResponseTime}` (avg of `Days_Open__c` on closed RFIs).
- `respondToRFI(id, response, status)`, `updateRFIStatus(id, status)`, `reassignRFI(id, userId)`.

### RFI Templates — `RFI_Template__mdt` (Custom Metadata)
Standardised RFIs are seeded from a **custom metadata type** `RFI_Template__mdt` (note: *not* a custom object — it's CMDT, so check Setup → Custom Metadata Types for the records). Fields: `Category__c`, `Subject_Template__c`, `Question_Template__c`, `Priority__c`, `SLA_Hours__c`, `Discipline__c`, `Work_Type__c`, `Is_Active__c`, `Sort_Order__c`, `Instructions__c`, `Auto_Assign_To__c`.

- `EPCRFIService.getRFITemplates()` — active templates ordered by category/sort.
- `createRfiFromTemplate(developerName, projectId)` — clones a template into a new `RFI__c`: copies subject/question, sets Status=Open + priority, derives `Due_Date__c = TODAY + ceil(SLA_Hours/24)`, and auto-assigns to `Auto_Assign_To__c` if it holds a valid user Id.

### RFI automation (Flows)
- **`EPC_RFI_SLA_Scheduler`** — *Scheduled* autolaunched flow. Periodic sweep that ages open RFIs / drives `AgeingBucket__c` & SLA breach handling.

### RFI UI components (LWC)
| Component | Role |
|---|---|
| `epcRfiConsole` | Main RFI console — list, filter, bulk update, export |
| `rfiDashboard` | RFI metrics / SLA dashboard |
| `rfiCreatePanel` | Create-RFI panel (incl. from template) |
| `epcEngineeringDesk` | Engineering desk surface that embeds RFI handling (uses `RFIController`) |

FlexiPage: `RFI_Record_Page`. Tab: `RFI__c`. Engineering workspace: `Engineering_Workspace`.

---

## Part B — Tender RFI / Clarification (`RFI_Query__c`)

Used during **bidding**: a bidder raises clarification questions against a published `Tender__c`; the tender owner responds. Lighter weight than the construction RFI — no SLA engine.

### Schema (`RFI_Query__c`, prefix `a0t`)
| Field | Notes |
|---|---|
| `Name` | Auto number |
| `Tender__c` | Parent tender (lookup) |
| `Query_text__c` | The clarification question (260 char) |
| `Response__c` | The answer (2550 char) |
| `Category__c` | Vendor Assessment / Solution Assessment / Preliminary Commercials |
| `Status__c` | Draft → Submitted → In Review → Responded → Reopened → Closed |

### Lifecycle & logic
- `rfiQueryController.createRFI(tenderId, queryText)` — creates with `Status = Draft`.
- `rfiQueryController.updateRFIResponse(id, response)` — sets `Response__c` and flips `Status = Responded`.
- `RFIDashboardController.getRFIQueries(tenderId)` / `updateRFIQuery(record)` — dashboard list + edit.
- **`RTF_RfqQueryNotificationFlow`** (RecordAfterSave on `RFI_Query__c`) — notification on new/updated tender query.

### UI components (LWC)
`rfiQueryCard`, `rfiQueryCreator`, plus surfaced inside `tenderDashboard` / `tenderDashboardStats`. Tab: `RFI_Query__c`.

---

## Demo cheat-sheet

- **Construction RFI story:** Open Project Command Center → `epcRfiConsole`/`rfiDashboard` → show open vs overdue, SLA compliance %, team performance, bulk-reassign, create-from-template, CSV export. Tie an RFI to a Drawing + WBS Item to show schedule impact.
- **SLA framing:** High=8h / Medium=24h / Low=48h; compliance computed from create→last-modified.
- **Tender RFI story:** Open a `Tender__c` → tender dashboard → bidder raises `RFI_Query__c` → owner responds → status flips to Responded (notification fires).
- **Data ready:** 25 construction RFIs, 12 tender queries.
