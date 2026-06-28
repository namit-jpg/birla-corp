public with sharing class EpcDailyProgressController {

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getWbsDetails(Id wbsId) {
        Map<String, Object> result = new Map<String, Object>();
        if (wbsId == null) return result;

        List<WBS_Item__c> items = [
            SELECT Id, Name__c, Code__c, Percent_Complete__c, BAC__c
            FROM WBS_Item__c
            WHERE Id = :wbsId
            LIMIT 1
        ];
        if (!items.isEmpty()) result.put('wbs', items[0]);

        result.put('recentDprs', [
            SELECT Id, Name, Date__c, Percent_Complete_Day__c,
                   Hours_Worked__c, Crew_Size__c,
                   Weather__c, Safety_Incidents__c, Quality_Issues__c
            FROM Daily_Progress__c
            WHERE WBS_Item__c = :wbsId AND Work_Package__c = null
            ORDER BY Date__c DESC
            LIMIT 15
        ]);

        return result;
    }

    @AuraEnabled(cacheable=false)
    public static List<Daily_Progress__c> getRecentDprs(Id wbsId) {
        if (wbsId == null) return new List<Daily_Progress__c>();
        return [
            SELECT Id, Name, Date__c, Percent_Complete_Day__c,
                   Hours_Worked__c, Crew_Size__c,
                   Weather__c, Safety_Incidents__c, Quality_Issues__c
            FROM Daily_Progress__c
            WHERE WBS_Item__c = :wbsId AND Work_Package__c = null
            ORDER BY Date__c DESC
            LIMIT 15
        ];
    }
}
