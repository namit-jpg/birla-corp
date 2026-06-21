public with sharing class SalesScreenTeamController {

    @AuraEnabled
    public static void saveOpportunityData(Id opportunityId, String opportunityData, String productDetails) {
        // Parse and save the opportunity data
        // This is a stub implementation - extend as needed for actual field mapping
        System.debug('Saving opportunity data for: ' + opportunityId);
    }

    @AuraEnabled
    public static void createSlackListForOpportunity(Id opportunityId) {
        try {
            SlackChannelService.createListForOpportunity(opportunityId);
        } catch (Exception e) {
            throw new AuraHandledException('Could not create Slack list: ' + e.getMessage());
        }
    }
}
