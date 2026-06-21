public with sharing class rfiQueryController {
    
    @AuraEnabled(cacheable=true)
    public static List<RFI_Query__c> getRFIQueries(Id tenderId) {
        return [
            SELECT Id, Query_text__c, Response__c, Status__c, CreatedDate 
            FROM RFI_Query__c 
            WHERE Tender__c = :tenderId 
            WITH SECURITY_ENFORCED
            ORDER BY CreatedDate DESC
        ];
    }

    @AuraEnabled
    public static void updateRFIResponse(Id rfiId, String response) {
        try {
            RFI_Query__c rfi = new RFI_Query__c(
                Id = rfiId,
                Response__c = response,
                Status__c = 'Responded'
            );
            update rfi;
        } catch (Exception e) {
            throw new AuraHandledException('Error updating RFI: ' + e.getMessage());
        }
    }
	 @AuraEnabled
    public static RFI_Query__c createRFI(Id tenderId, String queryText) {
        try {
            RFI_Query__c newRfi = new RFI_Query__c(
                Tender__c = tenderId,
                Query_text__c = queryText,
                Status__c = 'Draft'
            );
            insert newRfi;
            return newRfi;
        } catch (Exception e) {
            throw new AuraHandledException('Error creating RFI: ' + e.getMessage());
        }
    }
}