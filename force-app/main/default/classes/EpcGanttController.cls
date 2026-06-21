public with sharing class EpcGanttController {

    private static final String OBJ_PROJECT = 'Project__c';
    private static final String OBJ_WBS     = 'WBS_Item__c';

    @AuraEnabled(cacheable=true)
    public static List<WBS_Item__c> getWBSItems(Id recordId, String objectType) {
        Id projectId;

        if (recordId == null) {
            Project__c p = [SELECT Id FROM Project__c ORDER BY LastModifiedDate DESC LIMIT 1];
            projectId = p?.Id;
        } else if (objectType == OBJ_PROJECT || String.isBlank(objectType)) {
            projectId = recordId;
        } else if (objectType == OBJ_WBS) {
            List<WBS_Item__c> items = [
                SELECT Project__c
                FROM   WBS_Item__c
                WHERE  Id = :recordId
                WITH USER_MODE
                LIMIT  1
            ];
            if (items.isEmpty() || items[0].Project__c == null) {
                return new List<WBS_Item__c>();
            }
            projectId = items[0].Project__c;
        } else {
            throw new AuraHandledException('Unsupported objectType: ' + objectType);
        }

        if (projectId == null) return new List<WBS_Item__c>();

        return [
            SELECT Id,
                   Name,
                   Code__c,
                   Level__c,
                   Baseline_Start__c,
                   Baseline_Finish__c,
                   Current_Start__c,
                   Current_Finish__c,
                   Duration__c,
                   BAC__c,
                   Percent_Complete__c,
                   Critical_Path__c,
                   Is_Delayed__c,
                   Schedule_Variance_Days__c,
                   Parent_WBS__c,
                   Project__c
            FROM   WBS_Item__c
            WHERE  Project__c = :projectId
            WITH   USER_MODE
            ORDER BY Level__c ASC NULLS LAST, Code__c ASC NULLS LAST
            LIMIT  500
        ];
    }
}
