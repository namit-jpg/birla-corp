/**
 * Controller for epcProcurementConsole LWC.
 * Returns status-count maps and PO list for the procurement board.
 */
public with sharing class ProcurementConsoleCtrl {

    @AuraEnabled(cacheable=true)
    public static Map<String, Integer> getMRStatusCounts() {
        Map<String, Integer> counts = new Map<String, Integer>{
            'Draft' => 0, 'Submitted' => 0, 'Approved' => 0,
            'RFQ Issued' => 0, 'Rejected' => 0
        };
        for (AggregateResult ar : [
            SELECT Status__c status, COUNT(Id) cnt
            FROM Material_Requisition__c
            GROUP BY Status__c
        ]) {
            String s = (String) ar.get('status');
            if (counts.containsKey(s)) {
                counts.put(s, (Integer) ar.get('cnt'));
            }
        }
        return counts;
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Integer> getRFQStatusCounts() {
        Map<String, Integer> counts = new Map<String, Integer>{
            'Draft' => 0, 'Issued' => 0, 'Received' => 0,
            'Evaluated' => 0, 'Awarded' => 0, 'Cancelled' => 0
        };
        for (AggregateResult ar : [
            SELECT Status__c status, COUNT(Id) cnt
            FROM RFQ__c
            GROUP BY Status__c
        ]) {
            String s = (String) ar.get('status');
            if (counts.containsKey(s)) {
                counts.put(s, (Integer) ar.get('cnt'));
            }
        }
        return counts;
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Integer> getPOStatusCounts() {
        Map<String, Integer> counts = new Map<String, Integer>{
            'Draft' => 0, 'Issued' => 0,
            'Partially Received' => 0, 'Closed' => 0
        };
        for (AggregateResult ar : [
            SELECT Status__c status, COUNT(Id) cnt
            FROM Purchase_Order__c
            GROUP BY Status__c
        ]) {
            String s = (String) ar.get('status');
            if (counts.containsKey(s)) {
                counts.put(s, (Integer) ar.get('cnt'));
            }
        }
        return counts;
    }

    @AuraEnabled(cacheable=true)
    public static List<Purchase_Order__c> getPurchaseOrders(Boolean criticalOnly) {
        String q = 'SELECT Id, Name, Status__c, Approval_Stage__c, Total_Value__c, ' +
                   'Is_Critical__c, Expected_Delivery__c, Order_Date__c, ' +
                   'Project__r.Name, Vendor__r.Name ' +
                   'FROM Purchase_Order__c';
        if (criticalOnly == true) {
            q += ' WHERE Is_Critical__c = true';
        }
        q += ' ORDER BY CreatedDate DESC LIMIT 200';
        return Database.query(q);
    }
}