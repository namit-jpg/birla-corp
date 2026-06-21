public with sharing class EPCDailyProgressService {

    /**
     * Creates a new Daily Progress record.
     * @param progressData A Daily_Progress__c object containing the data to be saved.
     * @return The newly created Daily_Progress__c record with its ID.
     */
    @AuraEnabled
    public static Daily_Progress__c createDailyProgress(Daily_Progress__c progressData) {
        try {
            // Server-side validation for required fields
            if (progressData.Date__c == null) {
                throw new AuraHandledException('Date is a required field.');
            }
            if (progressData.Work_Package__c == null) {
                throw new AuraHandledException('Work Package is a required field.');
            }
            
            insert progressData;
            System.debug('✅ Daily Progress created with ID: ' + progressData.Id);
            return progressData;
        } catch (DmlException dmlEx) {
            System.debug('DML Error creating daily progress: ' + dmlEx.getMessage());
            throw new AuraHandledException('A database error occurred. Please check your data.');
        } catch (Exception e) {
            System.debug('Unexpected error creating daily progress: ' + e.getMessage());
            throw new AuraHandledException('An unexpected error occurred while saving progress.');
        }
    }

    /**
     * Retrieves all Project records for the Project picker.
     */
    @AuraEnabled(cacheable=true)
    public static List<Project__c> getAllProjects() {
        try {
            return [
                SELECT Id, Name
                FROM Project__c
                WITH SECURITY_ENFORCED
                ORDER BY Name ASC
            ];
        } catch (Exception e) {
            System.debug('Error retrieving projects: ' + e.getMessage());
            throw new AuraHandledException('Error retrieving projects.');
        }
    }

    /**
     * Retrieves Work Package records related to a specific Project.
     */
    @AuraEnabled(cacheable=true)
    public static List<Work_Package__c> getProjectRelatedWBSItems(Id projectId) {
        try {
            if (projectId == null) {
                return new List<Work_Package__c>();
            }
            return [
                SELECT Id, Name
                FROM Work_Package__c
                WHERE Project__c = :projectId
                WITH SECURITY_ENFORCED
                ORDER BY Name ASC
            ];
        } catch (Exception e) {
            System.debug('Error retrieving WBS items: ' + e.getMessage());
            throw new AuraHandledException('Error retrieving work packages.');
        }
    }

    /**
     * Daily progress rows for a project (LWCs reference this class; query implementation lives on EPCSiteExecutionController).
     */
    @AuraEnabled(cacheable=true)
    public static List<Daily_Progress__c> getDailyProgress(Id projectId) {
        return EPCSiteExecutionController.getDailyProgress(projectId);
    }

    /**
     * Inserts Daily Progress and related Resource__c records in one transaction.
     */
   @AuraEnabled
public static Id saveDailyProgress(Daily_Progress__c progressRecord, List<Object> materialLines) {
    // Set a Savepoint to ensure atomicity
    Savepoint sp = Database.setSavepoint();

    // --- 1. Insert Parent Daily_Progress__c ---
    try {
        if (progressRecord.Project__c == null || 
            progressRecord.Work_Package__c == null || 
            progressRecord.Date__c == null) {
            throw new AuraHandledException('Project, Work Package, and Date are required on the main form.');
        }
        insert progressRecord;
        System.debug('✅ Daily Progress record inserted. ID: ' + progressRecord.Id);
    } catch (DmlException e) {
        System.debug('❌ Error inserting Daily_Progress__c: ' + e.getMessage());
        throw new AuraHandledException('Failed to create Daily Progress record: ' + e.getDmlMessage(0));
    } catch (Exception e) {
        System.debug('❌ Unexpected error inserting Daily_Progress__c: ' + e.getMessage());
        throw new AuraHandledException('Unexpected error creating Daily Progress record.');
    }

    Id newDailyProgressId = progressRecord.Id;

    // --- 2. Build quantity map for Resource update ---
    if (materialLines != null && !materialLines.isEmpty()) {
        Map<Id, List<Decimal>> dailyProgressQuantityMap = new Map<Id, List<Decimal>>();
        Map<Id, Map<String, Object>> fieldValueMap = new Map<Id, Map<String, Object>>();

        for (Object lineObj : materialLines) {
            if (lineObj == null) {
                System.debug('⚠️ Skipping null material line');
                continue;
            }

            String jsonLine = JSON.serialize(lineObj);
            Map<String, Object> lineMap = (Map<String, Object>) JSON.deserializeUntyped(jsonLine);

            // --- Existing Resource Id ---
            if (!lineMap.containsKey('Id') || lineMap.get('Id') == null) 
            {
                Database.rollback(sp);
                throw new AuraHandledException('Each material line must have an existing Resource record Id. No new record will be created.');
            }

            Id resourceId = (Id) lineMap.get('Id');
            System.debug('🆔 Resource Id for update: ' + resourceId);

            // --- Quantity ---
            if (!lineMap.containsKey('Qty_Installed__c') || lineMap.get('Qty_Installed__c') == null) {
                Database.rollback(sp);
                throw new AuraHandledException('Quantity is required for Resource record Id: ' + resourceId);
            }

            Decimal qtyValue = (Decimal) lineMap.get('Qty_Installed__c');

            if (!dailyProgressQuantityMap.containsKey(resourceId)) 
            {
                dailyProgressQuantityMap.put(resourceId, new List<Decimal>());
            }
            dailyProgressQuantityMap.get(resourceId).add(qtyValue);

            // --- Other fields ---
            fieldValueMap.put(resourceId, lineMap);
        }

        // --- 3. Update Existing Resource__c Records ---
        if (!dailyProgressQuantityMap.isEmpty()) 
        {
            List<Resource__c> recordsToUpdate = [
                SELECT Id,Daily_Progress__c,Quantity_Used__c, Product__c, Work_Package__c, Name
                FROM Resource__c
                WHERE Id IN :dailyProgressQuantityMap.keySet()
            ];

            for (Resource__c res : recordsToUpdate) 
            {
                Decimal existingQty = res.Quantity_Used__c != null ? res.Quantity_Used__c : 0;
                Decimal addedQty = 0;

                for (Decimal q : dailyProgressQuantityMap.get(res.Id)) 
                {
                    addedQty += (q != null ? q : 0);
                }

                res.Quantity_Used__c = existingQty + addedQty;
				res.Daily_Progress__c = newDailyProgressId;
                // --- Update Product ---
                if (fieldValueMap.containsKey(res.Id) &&
                    fieldValueMap.get(res.Id).containsKey('Product__c') &&
                    fieldValueMap.get(res.Id).get('Product__c') != null)
                {
                    res.Product__c = (Id) fieldValueMap.get(res.Id).get('Product__c');
                }

                // --- Update Work Package ---
                res.Work_Package__c = progressRecord.Work_Package__c;

                // --- Update Name (fallback) ---
                if (fieldValueMap.get(res.Id).containsKey('Product_Family__c') &&
                    fieldValueMap.get(res.Id).get('Product_Family__c') != null) 
                {
                    res.Name = (String) fieldValueMap.get(res.Id).get('Product_Family__c');
                } else if (String.isBlank(res.Name))
                {
                    res.Name = 'DP Resource ' + System.now().getTime();
                }

                System.debug('🔁 Updating Resource: ' + res.Id +
                             ' | Old Qty: ' + existingQty +
                             ' | Add Qty: ' + addedQty +
                             ' | New Qty: ' + res.Quantity_Used__c +
                             ' | Product__c: ' + res.Product__c +
                             ' | Work_Package__c: ' + res.Work_Package__c +
                             ' | Name: ' + res.Name);
            }

            try {
                update recordsToUpdate;
                System.debug('✅ ' + recordsToUpdate.size() + ' Resource__c records updated successfully for Daily Progress ID: ' + newDailyProgressId);
            } catch (DmlException e) {
                Database.rollback(sp);
                System.debug('❌ Error updating Resource__c records: ' + e.getMessage());
                throw new AuraHandledException('Error updating existing Resource records: ' + e.getDmlMessage(0));
            }
        }
    }

    // --- 4. Return Daily Progress Id ---
    System.debug('📌 Returning Daily Progress Id: ' + newDailyProgressId);
    return newDailyProgressId;
}

}