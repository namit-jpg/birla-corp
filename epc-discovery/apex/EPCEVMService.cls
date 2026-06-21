public with sharing class EPCEVMService {
    
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getEVMData(Id projectId) {
        try {
            // Get project data
            Project__c project = [SELECT Id, Start_Date__c, End_Date__c FROM Project__c WHERE Id = :projectId WITH SECURITY_ENFORCED];
            
            // Get WBS items for EVM calculation
            List<WBS_Item__c> wbsItems = [
                SELECT Id, BAC__c, AC__c, Percent_Complete__c
                FROM WBS_Item__c 
                WHERE Project__c = :projectId
                WITH SECURITY_ENFORCED
            ];
            
            // Calculate EVM metrics
            Decimal plannedValue = 0;
            Decimal earnedValue = 0;
            Decimal actualCost = 0;
            
            for(WBS_Item__c item : wbsItems) {
                plannedValue += (item.BAC__c != null ? item.BAC__c : 0);
                earnedValue += (item.BAC__c != null && item.Percent_Complete__c != null ? 
                               item.BAC__c * (item.Percent_Complete__c / 100) : 0);
                actualCost += (item.AC__c != null ? item.AC__c : 0);
            }
            
            // Calculate CPI and SPI
            Decimal cpi = actualCost > 0 ? earnedValue / actualCost : 0;
            Decimal spi = plannedValue > 0 ? earnedValue / plannedValue : 0;
            
            Map<String, Object> evmData = new Map<String, Object>();
            evmData.put('CPI', cpi);
            evmData.put('SPI', spi);
            evmData.put('Planned_Value__c', plannedValue);
            evmData.put('Earned_Value__c', earnedValue);
            evmData.put('Actual_Cost__c', actualCost);
            
            return evmData;
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving EVM data: ' + e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> calculateEVM(Id wbsItemId) {
        try {
            WBS_Item__c wbsItem = [SELECT Id, BAC__c, AC__c, Percent_Complete__c FROM WBS_Item__c WHERE Id = :wbsItemId WITH SECURITY_ENFORCED];
            
            Decimal plannedValue = wbsItem.BAC__c != null ? wbsItem.BAC__c : 0;
            Decimal earnedValue = wbsItem.BAC__c != null && wbsItem.Percent_Complete__c != null ? 
                                wbsItem.BAC__c * (wbsItem.Percent_Complete__c / 100) : 0;
            Decimal actualCost = wbsItem.AC__c != null ? wbsItem.AC__c : 0;
            
            Map<String, Object> result = new Map<String, Object>();
            result.put('plannedValue', plannedValue);
            result.put('earnedValue', earnedValue);
            result.put('actualCost', actualCost);
            
            return result;
        } catch (Exception e) {
            throw new AuraHandledException('Error calculating EVM: ' + e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> calculateProgress(Id projectId) {
        try {
            List<WBS_Item__c> wbsItems = [
                SELECT Id, BAC__c, Percent_Complete__c
                FROM WBS_Item__c 
                WHERE Project__c = :projectId 
                WITH SECURITY_ENFORCED
            ];
            
            Decimal totalBudget = 0;
            Decimal totalProgress = 0;
            
            for(WBS_Item__c item : wbsItems) {
                totalBudget += (item.BAC__c != null ? item.BAC__c : 0);
                totalProgress += (item.BAC__c != null && item.Percent_Complete__c != null ? 
                                item.BAC__c * (item.Percent_Complete__c / 100) : 0);
            }
            
            Map<String, Object> result = new Map<String, Object>();
            result.put('totalBudget', totalBudget);
            result.put('totalProgress', totalProgress);
            result.put('progressPercentage', totalBudget > 0 ? (totalProgress / totalBudget) * 100 : 0);
            
            return result;
        } catch (Exception e) {
            throw new AuraHandledException('Error calculating progress: ' + e.getMessage());
        }
    }
}