/**
 * @description Handler class for WBS_ItemTrigger containing the business logic.
 * Calculates the roll-up dates for parent WBS items.
 */
public with sharing class WBSItemTriggerHandler {

    /**
     * @description Recalculates the Baseline_Start__c (min) and Baseline_Finish__c (max) 
     * for parent WBS items when Level 3 children are updated.
     * @param newWBSItems List of new WBS_Item__c records from the trigger.
     * @param oldWBSItemMap Map of old WBS_Item__c records from the trigger.
     */
    public static void recalculateParentDates(List<WBS_Item__c> newWBSItems, Map<Id, WBS_Item__c> oldWBSItemMap) {

        // 1. Collect unique Parent WBS IDs whose children (Level 3) have changed.
        Set<Id> parentIdsToRecalculatelevel3 = new Set<Id>();
        Set<Id> parentIdsToRecalculatelevel2 = new Set<Id>();
        Set<Id> parentIdsToRecalculatelevel1 = new Set<Id>();
        for (WBS_Item__c newItem : newWBSItems) 
        {
            WBS_Item__c oldItem = oldWBSItemMap.get(newItem.Id);
            
            // CRITERIA:
            // a) The WBS item must be Level 3.
            // b) It must have a Parent_WBS__c.
            // c) Either the Baseline_Start__c OR Baseline_Finish__c must have changed.
            if (newItem.Level__c == 3 && newItem.Parent_WBS__c != null) 
            {
                Boolean startChanged = newItem.Baseline_Start__c != oldItem.Baseline_Start__c;
                Boolean finishChanged = newItem.Baseline_Finish__c != oldItem.Baseline_Finish__c;

                if (startChanged || finishChanged) {
                    parentIdsToRecalculatelevel3.add(newItem.Parent_WBS__c);
                    calculatedatesonlevel2(parentIdsToRecalculatelevel3);
                    
                }
            }
             else if (newItem.Level__c == 2 && newItem.Parent_WBS__c != null)
             {
               Boolean startChanged = newItem.Baseline_Start__c != oldItem.Baseline_Start__c;
                Boolean finishChanged = newItem.Baseline_Finish__c != oldItem.Baseline_Finish__c;

                if (startChanged || finishChanged) {
                    parentIdsToRecalculatelevel2.add(newItem.Parent_WBS__c);
                   // parentIdsToRecalculatelevel2(parentIdsToRecalculate);
                   calculatedatesonlevel1(parentIdsToRecalculatelevel2);
                }  
             }
            
                    else if (newItem.Level__c == 1 && newItem.Parent_WBS__c == null)
                        {
                            Boolean startChanged = newItem.Baseline_Start__c != oldItem.Baseline_Start__c;
                            Boolean finishChanged = newItem.Baseline_Finish__c != oldItem.Baseline_Finish__c;
                        
                            if (startChanged || finishChanged) {
                                Set<Id> level1Ids = new Set<Id>{ newItem.Id };
                                updateprojectenddate(level1Ids); // ✅ pass correct set
                            }
                        }
            
            
        }
    }
        
    
    public static void calculatedatesonlevel1(set<Id> parentIdsToRecalculatelevel1) // level 2 to level 1 
    {
        if (!parentIdsToRecalculatelevel1.isEmpty()) 
       {
        // 2. Use Aggregate SOQL to calculate the Min Start and Max Finish for all relevant parents.
        // This is highly efficient and respects governor limits.
        List<AggregateResult> results = [
            SELECT Parent_WBS__c parentId,
                   MIN(Baseline_Start__c) minStart,
                   MAX(Baseline_Finish__c) maxFinish,
            	   SUM(BAC__c) totalBAC
            FROM WBS_Item__c
            WHERE Parent_WBS__c IN :parentIdsToRecalculatelevel1
            // Only aggregate the dates from Level 3 children, which drive the parent dates.
            AND Level__c = 2 
            GROUP BY Parent_WBS__c
        ];

        // 3. Prepare parent records for update.
        List<WBS_Item__c> parentsToUpdate = new List<WBS_Item__c>();

        for (AggregateResult ar : results) {
            Id parentId = (Id)ar.get('parentId');
            Date calculatedMinStart = (Date)ar.get('minStart');
            Date calculatedMaxFinish = (Date)ar.get('maxFinish');
            decimal totalamount = (Decimal)ar.get('totalBAC');
            
                 Integer durationDays = 0;
                    if (calculatedMinStart != null && calculatedMaxFinish != null) {
                        durationDays = calculatedMinStart.daysBetween(calculatedMaxFinish) + 1; // +1 if inclusive
                    }
                    
                    parentsToUpdate.add(new WBS_Item__c(
                        Id = parentId,
                        Baseline_Start__c = calculatedMinStart,
                        Baseline_Finish__c = calculatedMaxFinish,
                        Duration__c = durationDays,
                        BAC__c = totalamount
                    ));
                }
            
        

        // 4. Perform the DML operation outside the loop to bulkify the code.
        if (!parentsToUpdate.isEmpty()) {
            try {
                system.debug(parentsToUpdate);
                update parentsToUpdate;
            } catch (DmlException e) {
                // Best practice is to handle errors, maybe log them or send notifications.
                System.debug('Error updating parent WBS Items: ' + e.getMessage());
            }
        }
            
        
       }
        
    }
    
    
    
    
    public static void calculatedatesonlevel2(set<Id>parentIdsToRecalculate) // level 3 to upadte level 2 
    {
           
             if (!parentIdsToRecalculate.isEmpty()) 
       {
        // 2. Use Aggregate SOQL to calculate the Min Start and Max Finish for all relevant parents.
        // This is highly efficient and respects governor limits.
        List<AggregateResult> results = [
            SELECT Parent_WBS__c parentId,
                   MIN(Baseline_Start__c) minStart,
                   MAX(Baseline_Finish__c) maxFinish,
            	   SUM(BAC__c) totalBAC
            FROM WBS_Item__c
            WHERE Parent_WBS__c IN :parentIdsToRecalculate
            // Only aggregate the dates from Level 3 children, which drive the parent dates.
            AND Level__c = 3 
            GROUP BY Parent_WBS__c
        ];

        // 3. Prepare parent records for update.
        List<WBS_Item__c> parentsToUpdate = new List<WBS_Item__c>();

       for (AggregateResult ar : results) {
                    Id parentId = (Id)ar.get('parentId');
                    Date calculatedMinStart = (Date)ar.get('minStart');
                    Date calculatedMaxFinish = (Date)ar.get('maxFinish');
                    
                    Integer durationDays = 0;
                    if (calculatedMinStart != null && calculatedMaxFinish != null) {
                        durationDays = calculatedMinStart.daysBetween(calculatedMaxFinish)  +1 ;// if inclusive
                    }
                    
                    parentsToUpdate.add(new WBS_Item__c(
                        Id = parentId,
                        Baseline_Start__c = calculatedMinStart,
                        Baseline_Finish__c = calculatedMaxFinish,
                        Duration__c = durationDays,
                        BAC__c = (Decimal)ar.get('totalBAC')
                    ));
                }


        // 4. Perform the DML operation outside the loop to bulkify the code.
        if (!parentsToUpdate.isEmpty()) {
            try {
                update parentsToUpdate;
            } catch (DmlException e) {
                // Best practice is to handle errors, maybe log them or send notifications.
                System.debug('Error updating parent WBS Items: ' + e.getMessage());
            }
        }
            
        }

        /* Exit if no parents need recalculation
        if (parentIdsToRecalculate.isEmpty()) 
        {
            return;
        }

        // 2. Use Aggregate SOQL to calculate the Min Start and Max Finish for all relevant parents.
        // This is highly efficient and respects governor limits.
        List<AggregateResult> results = [
            SELECT Parent_WBS__c parentId,
                   MIN(Baseline_Start__c) minStart,
                   MAX(Baseline_Finish__c) maxFinish
            FROM WBS_Item__c
            WHERE Parent_WBS__c IN :parentIdsToRecalculate
            // Only aggregate the dates from Level 3 children, which drive the parent dates.
            AND Level__c = 3 
            GROUP BY Parent_WBS__c
        ];

        // 3. Prepare parent records for update.
        List<WBS_Item__c> parentsToUpdate = new List<WBS_Item__c>();

        for (AggregateResult ar : results) {
            Id parentId = (Id)ar.get('parentId');
            Date calculatedMinStart = (Date)ar.get('minStart');
            Date calculatedMaxFinish = (Date)ar.get('maxFinish');
            
            parentsToUpdate.add(new WBS_Item__c(
                Id = parentId,
                // Update the parent's baseline dates with the calculated min/max
                Baseline_Start__c = calculatedMinStart,
                Baseline_Finish__c = calculatedMaxFinish
            ));
        }

        // 4. Perform the DML operation outside the loop to bulkify the code.
        if (!parentsToUpdate.isEmpty()) {
            try {
                update parentsToUpdate;
            } catch (DmlException e) {
                // Best practice is to handle errors, maybe log them or send notifications.
                System.debug('Error updating parent WBS Items: ' + e.getMessage());
            }
        }*/
    }
    
   public static void updateprojectenddate(Set<Id> wbsItemIds)// level 1 - project update
{
    System.debug('WBS Items to recalc: ' + wbsItemIds);

    if (wbsItemIds.isEmpty()) {
        return;
    }

    // 1️⃣ Aggregate min start & max finish per Project
    List<AggregateResult> results = [
        SELECT Project__c,
               MIN(Baseline_Start__c) minStart,
               MAX(Baseline_Finish__c) maxFinish,
        	SUM(BAC__c) totalBAC
			  
        FROM WBS_Item__c
        WHERE Id IN :wbsItemIds
        AND Level__c = 1
        GROUP BY Project__c
    ];

    // 2️⃣ Collect Project Ids
    Set<Id> projectIds = new Set<Id>();
    for (AggregateResult ar : results) {
        if (ar.get('Project__c') != null) {
            projectIds.add((Id)ar.get('Project__c'));
        }
    }

    // 3️⃣ Query actual Project records
    Map<Id, Project__c> projectMap = new Map<Id, Project__c>(
        [SELECT Id, Start_Date__c, End_Date__c,BAC__c FROM Project__c WHERE Id IN :projectIds]
    );

    // 4️⃣ Update each Project’s start and end date
    List<Project__c> projectsToUpdate = new List<Project__c>();
    for (AggregateResult ar : results) {
        Id projId = (Id)ar.get('Project__c');
        if (projectMap.containsKey(projId)) {
            Project__c proj = projectMap.get(projId);
            proj.Start_Date__c = (Date)ar.get('minStart');
            proj.End_Date__c = (Date)ar.get('maxFinish');
            proj.BAC__c = ar.get('totalBAC') != null ? (Decimal)ar.get('totalBAC') : 0;
            projectsToUpdate.add(proj);
        }
    }

    // 5️⃣ DML outside the loop
    if (!projectsToUpdate.isEmpty()) {
        try {
            update projectsToUpdate;
            System.debug('Updated Projects: ' + projectsToUpdate);
        } catch (DmlException e) {
            System.debug('❌ Error updating Projects: ' + e.getMessage());
        }
    }
}

        
    }