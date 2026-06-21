public with sharing class EPCChangeOrderService {
    @AuraEnabled(cacheable=true)
    public static List<Change_Order__c> getChangeOrders(Id projectId) {
        if (projectId == null) {
            return new List<Change_Order__c>();
        }
        return [
            SELECT Id, Name, Status__c, Approval_Status__c, Approved_By__c, Approved_On__c,
                   Project__c, Type_of_Change__c, Reason__c, Description__c, Number__c,
                   Estimated_Additional_Cost__c, Impact_Cost__c, Value__c, Impact_Days__c,
                   Revised_End_Date__c, Variance_Days__c, CurrencyIsoCode,
                   OwnerId, Owner.Name,
                   CreatedById, CreatedBy.Name,
                   LastModifiedById, LastModifiedBy.Name,
                   Approved_By__r.Name
            FROM Change_Order__c
            WHERE Project__c = :projectId
            WITH SECURITY_ENFORCED
            ORDER BY CreatedDate DESC
        ];
    }

    /**
     * Inline update for Change Orders from LWC datatable.
     * Supports updating Revised_End_Date__c (Date) and Estimated_Additional_Cost__c (Currency).
     * Accepts a generic list of records with Id and changed fields.
     */
    @AuraEnabled
    public static void updateChangeOrders(List<Change_Order__c> changeOrders) {
        if (changeOrders == null || changeOrders.isEmpty()) return;

        // Only allow updating specific fields for safety
        // Construct sanitized records to avoid mass field changes
        Map<Id, Change_Order__c> inputById = new Map<Id, Change_Order__c>(changeOrders);
        List<Change_Order__c> toUpdate = new List<Change_Order__c>();

        for (Id coId : inputById.keySet()) {
            Change_Order__c inRec = inputById.get(coId);
            Change_Order__c rec = new Change_Order__c(Id = coId);

            // Copy over allowed fields if present in the incoming SObject
            if (inRec.getPopulatedFieldsAsMap().containsKey('Revised_End_Date__c')) {
                rec.Revised_End_Date__c = inRec.Revised_End_Date__c;
            }
            if (inRec.getPopulatedFieldsAsMap().containsKey('Estimated_Additional_Cost__c')) {
                rec.Estimated_Additional_Cost__c = inRec.Estimated_Additional_Cost__c;
            }
            toUpdate.add(rec);
        }

        if (!toUpdate.isEmpty()) {
            update toUpdate;
        }
    }

    /**
     * Mass approve Change Orders.
     * Logic: Set Approval_Status__c = 'Approved', Approved_By__c = current user, Approved_On__c = today (Date.today()).
     * Also set Status__c = 'Approved'.
     */
    @AuraEnabled
    public static void approveChangeOrders(List<Id> changeOrderIds) {
        if (changeOrderIds == null || changeOrderIds.isEmpty()) {
            return;
        }
        List<Change_Order__c> updates = new List<Change_Order__c>();
        Date today = Date.today();
        Id userId = UserInfo.getUserId();

        for (Id coId : changeOrderIds) {
            updates.add(new Change_Order__c(
                Id = coId,
                Approval_Status__c = 'Approved',
                Status__c = 'Approved',
                Approved_By__c = userId,
                Approved_On__c = today
            ));
        }
        if (!updates.isEmpty()) {
            update updates;
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<Project__c> getProjects() {
        return [
            SELECT Id, Name
            FROM Project__c
            WITH SECURITY_ENFORCED
            ORDER BY Name ASC
            LIMIT 2000
        ];
    }

    /**
     * Create flow from epcChangeCostRoom LWC (project + financial / description fields).
     */
    @AuraEnabled
    public static Id createChangeOrder(Map<String, Object> payload) {
        if (payload == null || payload.get('projectId') == null) {
            throw new AuraHandledException('projectId is required');
        }
        Change_Order__c co = new Change_Order__c();
        co.Project__c = (Id) payload.get('projectId');
        Decimal impact = toDecimal(payload.get('impactCost'));
        if (impact != null) {
            co.Impact_Cost__c = impact;
        }
        if (payload.get('description') != null) {
            co.Description__c = String.valueOf(payload.get('description'));
        }
        Decimal val = toDecimal(payload.get('value'));
        if (val != null) {
            co.Value__c = val;
        }
        insert co;
        return co.Id;
    }

    private static Decimal toDecimal(Object raw) {
        if (raw == null) {
            return null;
        }
        String s = String.valueOf(raw).trim();
        if (String.isBlank(s)) {
            return null;
        }
        return Decimal.valueOf(s);
    }
}