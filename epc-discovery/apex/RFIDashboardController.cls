public with sharing class RFIDashboardController {

    @AuraEnabled(cacheable=true)
    public static List<RFI_Query__c> getRFIQueries(Id tenderId) {
        if (tenderId == null) {
            return new List<RFI_Query__c>();
        }

        return [
            SELECT Id, Name, Status__c, Category__c, Owner.Name
            FROM RFI_Query__c
            WHERE Tender__c = :tenderId
            WITH SECURITY_ENFORCED
            ORDER BY CreatedDate DESC
        ];
    }

    // Fixed method: accept single record, properly named
    @AuraEnabled
public static void updateRFIQuery(Map<String, Object> rfiRecord) {
    RFI_Query__c rfi = (RFI_Query__c) JSON.deserialize(JSON.serialize(rfiRecord), RFI_Query__c.class);
    update rfi;
}
}