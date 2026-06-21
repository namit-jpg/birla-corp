/**
 * Covers WBSDelayRiskService, WBSDelayAlertService and WBSDelayMonitorSchedulable.
 */
@isTest
private class WBSDelayEngineTest {

    private static Id me() { return UserInfo.getUserId(); }

    private static Project__c buildDelayedProject() {
        // Project already behind: End_Date is past Baseline_Finish (variance > 0).
        Project__c p = new Project__c(
            Start_Date__c = Date.today().addDays(-20),
            Baseline_Finish__c = Date.today().addDays(-5),
            End_Date__c = Date.today().addDays(5),
            Project_Manager__c = me()
        );
        insert p;

        WBS_Item__c parent = new WBS_Item__c(Project__c = p.Id, Name__c = 'Phase', Code__c = '1', Level__c = 1,
            Custodian__c = me());
        insert parent;
        // Leaf is past its baseline start with 0% progress -> actual start crossed.
        WBS_Item__c leaf = new WBS_Item__c(Project__c = p.Id, Name__c = 'Foundation', Code__c = '1.1', Level__c = 2,
            Parent_WBS__c = parent.Id, Duration__c = 6, BAC__c = 500, Percent_Complete__c = 0,
            Baseline_Start__c = Date.today().addDays(-10), Baseline_Finish__c = Date.today().addDays(-2),
            Custodian__c = me(), Assignee__c = me());
        insert leaf;
        return p;
    }

    @isTest
    static void testRiskAndAlerts() {
        Project__c p = buildDelayedProject();

        Test.startTest();
        CPMEngine.recalculate(p.Id);
        WBSDelayRiskService.evaluate(p.Id);
        Integer sent = WBSDelayAlertService.run(p.Id);
        Test.stopTest();

        WBS_Item__c leaf = [
            SELECT Delay_Likelihood__c, Delay_Risk_Score__c, Likely_To_Delay_Project__c,
                   Is_Actual_Start_Crossed__c, Project_Delay_Reason__c
            FROM WBS_Item__c WHERE Code__c = '1.1' AND Project__c = :p.Id LIMIT 1
        ];
        System.assertEquals(true, leaf.Is_Actual_Start_Crossed__c, 'actual start crossed planned');
        System.assert(leaf.Delay_Risk_Score__c >= 50, 'leaf scored as elevated risk: ' + leaf.Delay_Risk_Score__c);
        System.assert(leaf.Delay_Likelihood__c == 'High' || leaf.Delay_Likelihood__c == 'Critical',
            'leaf high/critical: ' + leaf.Delay_Likelihood__c);
        System.assertEquals(true, leaf.Likely_To_Delay_Project__c, 'flagged as likely to delay project');
        System.assertNotEquals(null, leaf.Project_Delay_Reason__c, 'delay reason narrative written');
        System.assert(sent >= 1, 'at least one custom notification sent');
    }

    @isTest
    static void testSchedulableBatch() {
        buildDelayedProject();
        Test.startTest();
        Database.executeBatch(new WBSDelayMonitorSchedulable(), 1);
        Test.stopTest();
        // Batch completing without exception is the assertion; risk fields should be set.
        Integer scored = [SELECT COUNT() FROM WBS_Item__c WHERE Delay_Likelihood__c != null];
        System.assert(scored >= 1, 'monitor scored items');
    }

    @isTest
    static void testScheduleEntryPoint() {
        Test.startTest();
        String jobId = System.schedule('WBS Monitor Test', '0 0 6 * * ?', new WBSDelayMonitorSchedulable());
        Test.stopTest();
        System.assertNotEquals(null, jobId, 'scheduled');
    }
}
