public with sharing class EPCBudgetService {
    
    @AuraEnabled(cacheable=true)
    public static List<WBS_Item__c> getBudgetByWBS(Id projectId) {
        try {
            return [
                SELECT Id, Code__c, Name__c, BAC__c, AC__c,
                       PV__c, EV__c, Percent_Complete__c, Project__c
                FROM WBS_Item__c 
                WHERE Project__c = :projectId 
                WITH SECURITY_ENFORCED
                ORDER BY Code__c ASC
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving budget data: ' + e.getMessage());
        }
    }
}