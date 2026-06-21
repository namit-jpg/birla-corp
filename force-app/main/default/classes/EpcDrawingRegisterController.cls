/**
 * EpcDrawingRegisterController
 * Serves drawings to the epcDrawingRegister LWC.
 * If projectId is provided (record page context), filters by Project__c.
 * Otherwise returns all drawings (app page context).
 * Bulk-safe: uses SOQL, no DML.
 */
public with sharing class EpcDrawingRegisterController {

    @AuraEnabled(cacheable=true)
    public static List<Drawing__c> getDrawings(String projectId) {
        String q = 'SELECT Id, Name, Title__c, Discipline__c, Current_Revision__c, '
                 + 'Status__c, File_Type__c, File_URL__c, Issue_Date__c, Project__c, WBS_Item__c '
                 + 'FROM Drawing__c';
        if (String.isNotBlank(projectId)) {
            q += ' WHERE Project__c = :projectId';
        }
        q += ' ORDER BY Name ASC LIMIT 2000';
        return Database.query(q);
    }
}