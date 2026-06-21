/**
 * @description Earned Value Calculator for EPC Projects
 * @author EPC Salesforce Team
 * @version 1.0
 */
public class EVCalculator implements Queueable, Database.AllowsCallouts {
    
    private Id projectId;
    private Boolean isRecursive = false;
    
    /**
     * @description Constructor for EVCalculator
     * @param projectId The project ID to calculate EV for
     */
    public EVCalculator(Id projectId) {
        this.projectId = projectId;
    }
    
    /**
     * @description Enqueue EV calculation for a project
     * @param projectId The project ID
     */
    public static void enqueue(Id projectId) {
        if (projectId == null) {
            throw new IllegalArgumentException('Project ID is required');
        }
        
        EVCalculator calculator = new EVCalculator(projectId);
        System.enqueueJob(calculator);
    }
    
    /**
     * @description Execute EV calculations
     * @param context The queueable context
     */
    public void execute(QueueableContext context) {
        try {
            // Calculate EV for the project
            calculateProjectEV();
            
            // If this is the first run, enqueue child WBS calculations
            if (!isRecursive) {
                enqueueChildCalculations();
            }
            
        } catch (Exception e) {
            // Log error and create error record
            createErrorRecord('EV Calculation failed: ' + e.getMessage(), e.getStackTraceString());
        }
    }
    
    /**
     * @description Calculate EV for the entire project
     */
    private void calculateProjectEV() {
        // Get project with all WBS items
        List<Project__c> projects = [
            SELECT Id, Name, Number__c,
                   (SELECT Id, Name, Code__c, Level__c, Control_Account__c,
                           BAC__c, PV__c, EV__c, AC__c, SPI__c, CPI__c,
                           Percent_Complete__c, Baseline_Start__c, Baseline_Finish__c,
                           Current_Start__c, Current_Finish__c
                    FROM WBS_Items__r
                    ORDER BY Level__c ASC, Code__c ASC)
            FROM Project__c
            WHERE Id = :projectId
            LIMIT 1
        ];
        
        if (projects.isEmpty()) {
            throw new EVCalculationException('Project not found: ' + projectId);
        }
        
        Project__c project = projects[0];
        List<WBS_Item__c> wbsItems = project.WBS_Items__r;
        
        // Calculate EV for each WBS item (bottom-up)
        Map<Id, WBS_Item__c> wbsMap = new Map<Id, WBS_Item__c>(wbsItems);
        Map<Id, List<WBS_Item__c>> childrenMap = buildChildrenMap(wbsItems);
        
        // Process WBS items from bottom to top
        for (WBS_Item__c wbs : wbsItems) {
            calculateWBSItemEV(wbs, childrenMap, wbsMap);
        }
        
        // Update WBS items
        update wbsItems;
        
        // Calculate project-level EV
        calculateProjectLevelEV(project, wbsItems);
        
        // Update project
        update project;
    }
    
    /**
     * @description Build map of parent to children relationships
     * @param wbsItems List of WBS items
     * @return Map of parent ID to list of children
     */
    private Map<Id, List<WBS_Item__c>> buildChildrenMap(List<WBS_Item__c> wbsItems) {
        Map<Id, List<WBS_Item__c>> childrenMap = new Map<Id, List<WBS_Item__c>>();
        
        for (WBS_Item__c wbs : wbsItems) {
            if (wbs.Parent_WBS__c != null) {
                if (!childrenMap.containsKey(wbs.Parent_WBS__c)) {
                    childrenMap.put(wbs.Parent_WBS__c, new List<WBS_Item__c>());
                }
                childrenMap.get(wbs.Parent_WBS__c).add(wbs);
            }
        }
        
        return childrenMap;
    }
    
    /**
     * @description Calculate EV for a single WBS item
     * @param wbs The WBS item
     * @param childrenMap Map of parent to children
     * @param wbsMap Map of all WBS items
     */
    private void calculateWBSItemEV(WBS_Item__c wbs, Map<Id, List<WBS_Item__c>> childrenMap, Map<Id, WBS_Item__c> wbsMap) {
        // If this is a leaf node (no children), calculate from daily progress
        if (!childrenMap.containsKey(wbs.Id)) {
            calculateLeafWBSItemEV(wbs);
        } else {
            // This is a parent node, roll up from children
            calculateParentWBSItemEV(wbs, childrenMap.get(wbs.Id));
        }
        
        // Calculate SPI and CPI
        calculateWBSItemIndices(wbs);
    }
    
    /**
     * @description Calculate EV for a leaf WBS item (no children)
     * @param wbs The WBS item
     */
    private void calculateLeafWBSItemEV(WBS_Item__c wbs) {
        // Get daily progress for this WBS item
        List<Daily_Progress__c> progressRecords = [
            SELECT Id, Qty_Installed__c, Percent_Complete_Day__c
            FROM Daily_Progress__c
            WHERE WBS_Item__c = :wbs.Id
        ];
        
        // Calculate physical percent complete
        Decimal totalQty = 0;
        Decimal completedQty = 0;
        
        for (Daily_Progress__c progress : progressRecords) {
            if (progress.Qty_Installed__c != null) {
                completedQty += progress.Qty_Installed__c;
            }
        }
        
        // Calculate percent complete
        if (wbs.Planned_Quantity__c != null && wbs.Planned_Quantity__c > 0) {
            wbs.Percent_Complete__c = (completedQty / wbs.Planned_Quantity__c) * 100;
        } else {
            wbs.Percent_Complete__c = 0;
        }
        
        // Calculate EV
        if (wbs.BAC__c != null) {
            wbs.EV__c = (wbs.BAC__c * wbs.Percent_Complete__c) / 100;
        } else {
            wbs.EV__c = 0;
        }
        
        // Calculate PV (Planned Value)
        wbs.PV__c = calculatePlannedValue(wbs);
        
        // Get actual cost from related records
        wbs.AC__c = calculateActualCost(wbs.Id);
    }
    
    /**
     * @description Calculate EV for a parent WBS item (roll up from children)
     * @param wbs The WBS item
     * @param children List of child WBS items
     */
    private void calculateParentWBSItemEV(WBS_Item__c wbs, List<WBS_Item__c> children) {
        Decimal totalEV = 0;
        Decimal totalPV = 0;
        Decimal totalAC = 0;
        Decimal totalBAC = 0;
        Decimal totalPercentComplete = 0;
        Integer childCount = 0;
        
        for (WBS_Item__c child : children) {
            if (child.EV__c != null) totalEV += child.EV__c;
            if (child.PV__c != null) totalPV += child.PV__c;
            if (child.AC__c != null) totalAC += child.AC__c;
            if (child.BAC__c != null) totalBAC += child.BAC__c;
            if (child.Percent_Complete__c != null) totalPercentComplete += child.Percent_Complete__c;
            childCount++;
        }
        
        // Set rollup values
        wbs.EV__c = totalEV;
        wbs.PV__c = totalPV;
        wbs.AC__c = totalAC;
        
        // Calculate percent complete as weighted average
        if (childCount > 0) {
            wbs.Percent_Complete__c = totalPercentComplete / childCount;
        }
        
        // If BAC is not set, use sum of children
        if (wbs.BAC__c == null || wbs.BAC__c == 0) {
            wbs.BAC__c = totalBAC;
        }
    }
    
    /**
     * @description Calculate Planned Value for a WBS item
     * @param wbs The WBS item
     * @return Planned Value
     */
    private Decimal calculatePlannedValue(WBS_Item__c wbs) {
        if (wbs.BAC__c == null || wbs.Baseline_Start__c == null || wbs.Baseline_Finish__c == null) {
            return 0;
        }
        
        Date today = Date.today();
        Date startDate = wbs.Baseline_Start__c;
        Date finishDate = wbs.Baseline_Finish__c;
        
        // Calculate planned percent complete based on time
        if (today <= startDate) {
            return 0;
        } else if (today >= finishDate) {
            return wbs.BAC__c;
        } else {
            // Linear interpolation
            Integer totalDays = startDate.daysBetween(finishDate);
            Integer elapsedDays = startDate.daysBetween(today);
            Decimal plannedPercent = (Decimal.valueOf(elapsedDays) / Decimal.valueOf(totalDays)) * 100;
            return (wbs.BAC__c * plannedPercent) / 100;
        }
    }
    
    /**
     * @description Calculate Actual Cost for a WBS item
     * @param wbsItemId The WBS item ID
     * @return Actual Cost
     */
    private Decimal calculateActualCost(Id wbsItemId) {
        // Sum costs from various sources (PO lines, timesheets, etc.)
        Decimal totalCost = 0;
        
        // Add PO line costs
        List<AggregateResult> poCosts = [
            SELECT SUM(Extended_Price__c) totalCost
            FROM PO_Line__c
            WHERE WBS_Item__c = :wbsItemId
        ];
        
        if (!poCosts.isEmpty() && poCosts[0].get('totalCost') != null) {
            totalCost += (Decimal) poCosts[0].get('totalCost');
        }
        
        // Add timesheet costs (if applicable)
        // This would be implemented based on your timesheet structure
        
        return totalCost;
    }
    
    /**
     * @description Calculate SPI and CPI for a WBS item
     * @param wbs The WBS item
     */
    private void calculateWBSItemIndices(WBS_Item__c wbs) {
        // Calculate SPI (Schedule Performance Index)
        if (wbs.PV__c != null && wbs.PV__c != 0) {
            wbs.SPI__c = wbs.EV__c / wbs.PV__c;
        } else {
            wbs.SPI__c = 0;
        }
        
        // Calculate CPI (Cost Performance Index)
        if (wbs.AC__c != null && wbs.AC__c != 0) {
            wbs.CPI__c = wbs.EV__c / wbs.AC__c;
        } else {
            wbs.CPI__c = 0;
        }
    }
    
    /**
     * @description Calculate project-level EV metrics
     * @param project The project
     * @param wbsItems List of WBS items
     */
    private void calculateProjectLevelEV(Project__c project, List<WBS_Item__c> wbsItems) {
        Decimal totalEV = 0;
        Decimal totalPV = 0;
        Decimal totalAC = 0;
        Decimal totalBAC = 0;
        
        for (WBS_Item__c wbs : wbsItems) {
            if (wbs.EV__c != null) totalEV += wbs.EV__c;
            if (wbs.PV__c != null) totalPV += wbs.PV__c;
            if (wbs.AC__c != null) totalAC += wbs.AC__c;
            if (wbs.BAC__c != null) totalBAC += wbs.BAC__c;
        }
        
        // Set project-level fields (these would need to be added to Project__c)
        // project.EV__c = totalEV;
        // project.PV__c = totalPV;
        // project.AC__c = totalAC;
        // project.BAC__c = totalBAC;
        
        // Calculate project-level indices
        if (totalPV != 0) {
            // project.SPI__c = totalEV / totalPV;
        }
        
        if (totalAC != 0) {
            // project.CPI__c = totalEV / totalAC;
        }
    }
    
    /**
     * @description Enqueue calculations for child WBS items
     */
    private void enqueueChildCalculations() {
        // Get all WBS items for this project that have children
        Set<Id> parentWBSIds = new Set<Id>();
        for (WBS_Item__c wbs : [SELECT Parent_WBS__c FROM WBS_Item__c WHERE Project__c = :projectId AND Parent_WBS__c != null]) {
            parentWBSIds.add(wbs.Parent_WBS__c);
        }
        
        List<WBS_Item__c> parentWBSItems = [
            SELECT Id
            FROM WBS_Item__c
            WHERE Id IN :parentWBSIds
        ];
        
        // Enqueue individual calculations for each parent WBS item
        for (WBS_Item__c wbs : parentWBSItems) {
            EVCalculator childCalculator = new EVCalculator(wbs.Id);
            childCalculator.isRecursive = true;
            System.enqueueJob(childCalculator);
        }
    }
    
    /**
     * @description Create error record for tracking
     * @param errorMessage The error message
     * @param stackTrace The stack trace
     */
    private void createErrorRecord(String errorMessage, String stackTrace) {
        // Create error log record (you would need to create this object)
        // Error_Log__c errorLog = new Error_Log__c(
        //     Error_Message__c = errorMessage,
        //     Stack_Trace__c = stackTrace,
        //     Project__c = projectId,
        //     Process__c = 'EV Calculation'
        // );
        // insert errorLog;
    }
    
    /**
     * @description Custom exception for EV calculation errors
     */
    public class EVCalculationException extends Exception {}
}