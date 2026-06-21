/**
 * @description Controller class for managing RFIs in the epcEngineeringDesk LWC component
 * @author EPC Implementation Team
 */
public with sharing class RFIController {
    
    /**
     * @description Get RFIs for a project
     * @param projectId The ID of the project
     * @return List of RFI__c records
     */
    @AuraEnabled(cacheable=true)
    public static List<RFI__c> getRFIs(Id projectId) {
        return [SELECT Id, Name, Subject__c, Status__c,  
                Due_Date__c, Submitted_Date__c, Response_Date__c,Priority__c,
                Submitted_By__c, Submitted_By__r.Name, Assigned_To__c, Assigned_To__r.Name,
                Days_Open__c, Description__c, Response__c
                FROM RFI__c 
                WHERE Project__c = :projectId
                WITH SECURITY_ENFORCED
                ORDER BY Due_Date__c ASC
                LIMIT 100];
    }
    
    /**
     * @description Get RFI metrics for a project
     * @param projectId The ID of the project
     * @return Map of metric names to values
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getRFIMetrics(Id projectId) {
        Map<String, Object> metrics = new Map<String, Object>();
        
        // Get total RFIs count
        Integer totalRFIs = [SELECT COUNT() FROM RFI__c WHERE Project__c = :projectId WITH SECURITY_ENFORCED];
        metrics.put('totalRFIs', totalRFIs);
        
        // Get open RFIs count
        Integer openRFIs = [SELECT COUNT() FROM RFI__c 
                          WHERE Project__c = :projectId AND Status__c != 'Closed' WITH SECURITY_ENFORCED];
        metrics.put('openRFIs', openRFIs);
        
        // Get overdue RFIs count
        Integer overdueRFIs = [SELECT COUNT() FROM RFI__c 
                             WHERE Project__c = :projectId 
                             AND Status__c != 'Closed' 
                             AND Due_Date__c < TODAY WITH SECURITY_ENFORCED];
        metrics.put('overdueRFIs', overdueRFIs);
        
        // Calculate average response time
        AggregateResult avgResult = [SELECT AVG(Days_Open__c) avgDays 
                                   FROM RFI__c 
                                   WHERE Project__c = :projectId 
                                   AND Status__c = 'Closed' WITH SECURITY_ENFORCED];
        
        Decimal avgResponseTime = (Decimal)avgResult.get('avgDays');
        metrics.put('avgResponseTime', avgResponseTime != null ? avgResponseTime.setScale(1) : 0);
        
        return metrics;
    }
    
    /**
     * @description Update the status of an RFI
     * @param rfiId The ID of the RFI
     * @param status The new status
     * @return The updated RFI
     */
    @AuraEnabled
    public static RFI__c updateRFIStatus(Id rfiId, String status) {
        RFI__c rfi = [
            SELECT Id, Status__c, Response_Date__c
            FROM RFI__c
            WHERE Id = :rfiId
            WITH SECURITY_ENFORCED
        ];
        rfi.Status__c = status;
        
        // If closing, set the response date
        if (status == 'Closed') {
            rfi.Response_Date__c = Date.today();
        }
        
        update rfi;
        return rfi;
    }
    
    /**
     * @description Respond to an RFI
     * @param rfiId The ID of the RFI
     * @param response The response text
     * @param status The new status
     * @return The updated RFI
     */
    @AuraEnabled
    public static RFI__c respondToRFI(Id rfiId, String response, String status) {
        RFI__c rfi = [
            SELECT Id, Status__c, Response__c, Response_Date__c
            FROM RFI__c
            WHERE Id = :rfiId
            WITH SECURITY_ENFORCED
        ];
        rfi.Response__c = response;
        rfi.Status__c = status;
        
        // If closing, set the response date
        if (status == 'Closed') {
            rfi.Response_Date__c = Date.today();
        }
        
        update rfi;
        return rfi;
    }
    
    /**
     * @description Reassign an RFI
     * @param rfiId The ID of the RFI
     * @param assignedToId The ID of the user to assign the RFI to
     * @return The updated RFI
     */
    @AuraEnabled
    public static RFI__c reassignRFI(Id rfiId, Id assignedToId) {
        RFI__c rfi = [
            SELECT Id, Assigned_To__c
            FROM RFI__c
            WHERE Id = :rfiId
            WITH SECURITY_ENFORCED
        ];
        rfi.Assigned_To__c = assignedToId;
        update rfi;
        return rfi;
    }
}