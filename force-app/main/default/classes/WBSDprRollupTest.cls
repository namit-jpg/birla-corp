/**
 * Verifies DPR -> WBS leaf progress -> CPMEngine rollup (parents/project) and
 * actual-date capture, for DPRs logged directly against a WBS item.
 */
@isTest
private class WBSDprRollupTest {

    @isTest
    static void testDirectWbsDprRollupAndActualDates() {
        Project__c p = new Project__c(Start_Date__c = Date.newInstance(2026, 1, 5));
        insert p;
        WBS_Item__c parent = new WBS_Item__c(Project__c = p.Id, Name__c = 'Phase', Code__c = '1', Level__c = 1);
        insert parent;
        WBS_Item__c leaf = new WBS_Item__c(Project__c = p.Id, Name__c = 'Pour', Code__c = '1.1', Level__c = 2,
            Parent_WBS__c = parent.Id, Duration__c = 4, BAC__c = 500, Planned_Quantity__c = 100);
        WBS_Item__c leaf2 = new WBS_Item__c(Project__c = p.Id, Name__c = 'Cure', Code__c = '1.2', Level__c = 2,
            Parent_WBS__c = parent.Id, Duration__c = 4, BAC__c = 500, Planned_Quantity__c = 100);
        insert new List<WBS_Item__c>{ leaf, leaf2 };

        Test.startTest();
        // DPR directly on the WBS leaf, 100% via Percent_Complete_Day.
        insert new Daily_Progress__c(
            Project__c = p.Id, WBS_Item__c = leaf.Id,
            Date__c = Date.today(), Percent_Complete_Day__c = 100, Qty_Installed__c = 100
        );
        Test.stopTest();

        WBS_Item__c rl = [SELECT Percent_Complete__c, EV__c, Actual_Start__c, Actual_Finish__c
                          FROM WBS_Item__c WHERE Id = :leaf.Id];
        System.assertEquals(100, rl.Percent_Complete__c, 'leaf progress set from DPR');
        System.assertEquals(500, rl.EV__c, 'EV = BAC * 100%');
        System.assertEquals(Date.today(), rl.Actual_Start__c, 'actual start stamped by CPM');
        System.assertEquals(Date.today(), rl.Actual_Finish__c, 'actual finish stamped at 100%');

        // Parent rolled up (budget-weighted: 100% on half the budget => 50%).
        WBS_Item__c rp = [SELECT Percent_Complete__c FROM WBS_Item__c WHERE Id = :parent.Id];
        System.assertEquals(50, rp.Percent_Complete__c, 'parent budget-weighted rollup');

        Project__c rpr = [SELECT Percent_Complete__c FROM Project__c WHERE Id = :p.Id];
        System.assertEquals(50, rpr.Percent_Complete__c, 'project overall progress rolled up');
    }
}
