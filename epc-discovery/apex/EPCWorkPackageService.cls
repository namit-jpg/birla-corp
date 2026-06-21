public with sharing class EPCWorkPackageService {
    
    @AuraEnabled(cacheable=true)
    public static List<Work_Package__c> getWorkPackages(Id projectId) {
        try {
            System.debug('projectId => ' + projectId);
            return [
                SELECT Id, Name, CreatedDate, LastModifiedDate, Project__c,
                       Status__c, Planned_Qty__c, Unit__c, Percent_Complete__c, Notes__c, End_Date__c
                FROM Work_Package__c 
                WHERE Project__c = :projectId 
                WITH SECURITY_ENFORCED
                ORDER BY Name ASC
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving work packages: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static Work_Package__c createWorkPackage(Work_Package__c workPackage) {
        try {
            insert workPackage;
            return workPackage;
        } catch (Exception e) {
            throw new AuraHandledException('Error creating work package: ' + e.getMessage());
        }
    }
    
/*    @AuraEnabled
    public static Work_Package__c updateWorkPackage(Id workPackageId, Map<String, Object> updates) {
        try {
            Work_Package__c wp = [SELECT Id, Status__c, Percent_Complete__c, Notes__c, End_Date__c FROM Work_Package__c WHERE Id = :workPackageId LIMIT 1];
            for (String field : updates.keySet()) {
                wp.put(field, updates.get(field));
            }
            update wp;
            return [SELECT Id, Status__c, Percent_Complete__c, Notes__c, End_Date__c FROM Work_Package__c WHERE Id = :workPackageId LIMIT 1];
        } catch (Exception e) {
            throw new AuraHandledException('Error updating work package: ' + e.getMessage());
        }
    }*/
    
        /**
     * @description Updates a work package with new values.
     * @param workPackageId The ID of the Work_Package__c record to update.
     * @param updates A map of field API names to their new values.
     * @return The updated Work_Package__c record.
     */
    @AuraEnabled
    public static Work_Package__c updateWorkPackage(Id workPackageId, Map<String, Object> updates) {
        try {
            // --- MODIFICATION 1: ADDED Start_Date__c TO THE QUERY ---
            // This is crucial to ensure the field is loaded into memory and not accidentally cleared on update.
            Work_Package__c wp = [SELECT Id, Status__c, Percent_Complete__c, Notes__c, Start_Date__c, End_Date__c 
                                 FROM Work_Package__c 
                                 WHERE Id = :workPackageId 
                                 LIMIT 1];

            // --- MODIFICATION 2: ADDED THE NEW DATE-SETTING LOGIC ---
            // This block checks if the 'Status__c' field is being changed in this update.
            if (updates.containsKey('Status__c')) {
                // Get the new status value from the incoming data.
                String newStatus = (String)updates.get('Status__c');

                // RULE 1: If the new status is 'In Progress', set the Start Date to today.
                if (newStatus == 'In_Progress') {
                    // We add the Start_Date__c to the 'updates' map.
                    // The loop below will then apply it to the record automatically.
                    updates.put('Start_Date__c', System.today());
                }
                // RULE 2: If the new status is 'Completed', set the End Date to today.
                else if (newStatus == 'Completed') {
                    updates.put('End_Date__c', System.today());
                }
            }

            // This original loop now applies both the original updates AND our new, automated date updates.
            for (String field : updates.keySet()) {
                wp.put(field, updates.get(field));
            }
            
            update wp;

            // --- MODIFICATION 3: ADDED Start_Date__c TO THE RETURN QUERY ---
            // This ensures the calling component receives the newly set Start Date.
            return [SELECT Id, Status__c, Percent_Complete__c, Notes__c, Start_Date__c, End_Date__c 
                    FROM Work_Package__c 
                    WHERE Id = :workPackageId 
                    LIMIT 1];

        } catch (Exception e) {
            throw new AuraHandledException('Error updating work package: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static void updateWorkPackageStatus(List<Daily_Progress__c> progressList) {
        // Collect all related Work Package Ids
        Set<Id> workPackageIds = new Set<Id>();
        for (Daily_Progress__c dp : progressList) {
            if (dp.Work_Package__c != null) {
                workPackageIds.add(dp.Work_Package__c);
            }
        }

        if (workPackageIds.isEmpty()) return;

        // Query related Work Packages
        List<Work_Package__c> workPackages = [
            SELECT Id, Status__c, Percent_Complete__c
            FROM Work_Package__c
            WHERE Id IN :workPackageIds
        ];

        List<Work_Package__c> updates = new List<Work_Package__c>();

        for (Work_Package__c wp : workPackages) {
            // If On Hold and progress > 0, move to In Progress
            if (wp.Status__c == 'On_Hold' && wp.Percent_Complete__c > 0) {
                wp.Status__c = 'In_Progress';
                updates.add(wp);
            }
        }

        if (!updates.isEmpty()) {
            update updates;
        }
    }
    
    @AuraEnabled
    public static void deleteWorkPackage(Id workPackageId) {
        try {
            delete [SELECT Id FROM Work_Package__c WHERE Id = :workPackageId LIMIT 1];
        } catch (Exception e) {
            throw new AuraHandledException('Error deleting work package: ' + e.getMessage());
        }
    }
     @AuraEnabled(cacheable=true)
   public static Map<String, List<Resource__c>> groupResourcesByFamily(Id workPackageId) {
    // 1. Query for Resources related to the specific Work_Package__c ID.
    // NOTE: It's best practice to pass in workPackageId as a parameter to a method.
    List<Resource__c> resourceList = [
        SELECT Id, Product__r.Name, Product__r.Family, Quantity__c,Product__r.QuantityUnitOfMeasure 
        FROM Resource__c 
        WHERE Work_Package__c = :workPackageId
        WITH SECURITY_ENFORCED
    ];

    // 2. Initialize the map to hold the grouped resources.
    Map<String, List<Resource__c>> productsByFamily = new Map<String, List<Resource__c>>();

    // 3. Iterate over the queried resources to group them.
    for (Resource__c res : resourceList) {
        // Determine the key: use Product_Family__c or 'Uncategorized' if blank/null.
        String familyKey = String.isNotBlank(res.Product__r.Family) ? res.Product__r.Family : 'Uncategorized';
        
        // Use the get() and put() pattern:
        // Attempt to retrieve the list for the key.
        List<Resource__c> familyResources = productsByFamily.get(familyKey);
        
        // If the list is null (key not yet in the map), initialize a new list and put it back.
        if (familyResources == null) {
            familyResources = new List<Resource__c>();
            productsByFamily.put(familyKey, familyResources);
        }
        
        // Add the current resource to the list.
        familyResources.add(res);
    }
    
    return productsByFamily;
} 
       /* // 2. Extract unique Product IDs into a Set, then convert to a List.
        Set<Id> materialIds = new Set<Id>();
        for (Resource__c line : resourselist) {
            // Only add if the lookup is populated
            if (line.Product__c != null) {
                materialIds.add(line.Product__c);
            }
        }
        system.debug(materialIds);
        
        // 3. Call the helper method to fetch the product details grouped by family.
        if (materialIds.isEmpty()) {
            return new Map<String, List<Product2>>();
        }
        
        // Pass the list of unique IDs to the helper method
        return getProductDetails(new List<Id>(materialIds));
    }
*/
 
  /*  public static Map<String, List<Product2>> getProductDetails(List<Id> productIds) {
        
        if (productIds == null || productIds.isEmpty()) {
            return new Map<String, List<Product2>>();
        }
        
        // Query the required fields for all products in the list
        List<Product2> products = [
            SELECT Id, ProductCode, Name, Family, Qty__c, 	QuantityUnitOfMeasure 
            FROM Product2 
            WHERE Id IN :productIds AND IsActive = TRUE
        ];
        
        Map<String, List<Product2>> productsByFamily = new Map<String, List<Product2>>();

        for (Product2 prod : products) 
        {
            // Use 'Uncategorized' if the Family field is null or blank
            String familyKey = String.isNotBlank(prod.Family) ? prod.Family : 'Uncategorized';
            
            // Initialize the list if the family key doesn't exist
            if (!productsByFamily.containsKey(familyKey)) {
                productsByFamily.put(familyKey, new List<Product2>());
            }
            
            // Add the product to the corresponding family list
            productsByFamily.get(familyKey).add(prod);
        }
        
        return productsByFamily;
    }*/

}