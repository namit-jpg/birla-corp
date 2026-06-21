public with sharing class RFITriggerHandler {
    /**
     * before insert: if a new record is inserted with Status__c = 'Closed' and no Close_Date__c,
     * set Close_Date__c to today's date.
     */
    public static void handleBeforeInsert(List<RFI__c> newList) {
        Date today = Date.today();
        for (RFI__c r : newList) {
            if (r.Status__c == 'Closed' && r.Close_Date__c == null) {
                r.Close_Date__c = today;
            }
        }
    }

    /**
     * before update: when Status__c transitions to 'Closed' and Close_Date__c is empty, set it to today.
     * If Status__c is changed away from 'Closed', clear Close_Date__c to reflect reopening (audit intent).
     * If a user manually provides a date while closing, keep their value.
     */
    public static void handleBeforeUpdate(List<RFI__c> newList, Map<Id, RFI__c> oldMap) {
        Date today = Date.today();
        for (RFI__c r : newList) {
            RFI__c oldR = oldMap.get(r.Id);
            Boolean becameClosed = (oldR.Status__c != 'Closed' && r.Status__c == 'Closed');
            Boolean becameOpen = (oldR.Status__c == 'Closed' && r.Status__c != 'Closed');
            if (becameClosed && r.Close_Date__c == null) {
                r.Close_Date__c = today;
            }
            if (becameOpen) {
                r.Close_Date__c = null; // Clear Close_Date__c when reopened
            }
        }
    }
}