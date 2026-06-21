/**
 * EpcRfiConsoleController
 * Serves RFI records to the epcRfiConsole LWC.
 * If projectId is provided (record page context), filters by Project__c.
 */
public with sharing class EpcRfiConsoleController {

    @AuraEnabled(cacheable=true)
    public static List<RFI__c> getRfis(String projectId) {
        String q = 'SELECT Id, Name, Subject__c, Status__c, Priority__c, Discipline__c, '
                 + 'Days_Open__c, Due_Date__c, Submitted_Date__c, Close_Date__c, '
                 + 'Project__c, Assigned_To__c '
                 + 'FROM RFI__c';
        if (String.isNotBlank(projectId)) {
            q += ' WHERE Project__c = :projectId';
        }
        q += ' ORDER BY Due_Date__c ASC NULLS LAST LIMIT 2000';
        return Database.query(q);
    }
}