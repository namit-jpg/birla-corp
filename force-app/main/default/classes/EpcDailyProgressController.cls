public with sharing class EpcDailyProgressController {

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getWorkPackageDetails(Id wpId) {
        Map<String, Object> result = new Map<String, Object>();
        if (wpId == null) return result;

        List<Work_Package__c> wps = [
            SELECT Id, Name, Planned_Qty__c, Percent_Complete__c, Budget__c, WBS_Item__c
            FROM Work_Package__c
            WHERE Id = :wpId
            LIMIT 1
        ];
        if (!wps.isEmpty()) result.put('wp', wps[0]);

        result.put('recentDprs', [
            SELECT Id, Name, Date__c, Qty_Installed__c, Planned_Quantity__c,
                   Hours_Worked__c, Crew_Size__c, Productivity__c,
                   Weather__c, Safety_Incidents__c, Quality_Issues__c
            FROM Daily_Progress__c
            WHERE Work_Package__c = :wpId
            ORDER BY Date__c DESC
            LIMIT 15
        ]);

        return result;
    }

    @AuraEnabled(cacheable=false)
    public static List<Daily_Progress__c> getRecentDprs(Id wpId) {
        if (wpId == null) return new List<Daily_Progress__c>();
        return [
            SELECT Id, Name, Date__c, Qty_Installed__c, Planned_Quantity__c,
                   Hours_Worked__c, Crew_Size__c, Productivity__c,
                   Weather__c, Safety_Incidents__c, Quality_Issues__c
            FROM Daily_Progress__c
            WHERE Work_Package__c = :wpId
            ORDER BY Date__c DESC
            LIMIT 15
        ];
    }
}
