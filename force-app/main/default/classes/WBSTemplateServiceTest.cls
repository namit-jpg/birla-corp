@isTest
private class WBSTemplateServiceTest {

    private static Project__c makeProjectWithWbs() {
        Project__c p = new Project__c(Start_Date__c = Date.newInstance(2026, 1, 5), Total_Budget__c = 1000);
        insert p;
        WBS_Item__c parent = new WBS_Item__c(Project__c = p.Id, Name__c = 'Phase', Code__c = '1', Level__c = 1);
        insert parent;
        WBS_Item__c a = new WBS_Item__c(Project__c = p.Id, Name__c = 'A', Code__c = '1.1', Level__c = 2,
            Parent_WBS__c = parent.Id, Duration__c = 5, BAC__c = 600);
        WBS_Item__c b = new WBS_Item__c(Project__c = p.Id, Name__c = 'B', Code__c = '1.2', Level__c = 2,
            Parent_WBS__c = parent.Id, Duration__c = 3, BAC__c = 400);
        insert new List<WBS_Item__c>{ a, b };
        insert new WBS_Dependency__c(Predecessor__c = a.Id, Successor__c = b.Id, Dependency_Type__c = 'FS', Lag_Days__c = 0);
        return p;
    }

    @isTest
    static void testSaveAndInstantiate() {
        Project__c source = makeProjectWithWbs();

        Test.startTest();
        Id templateId = WBSTemplateService.saveAsTemplate(source.Id, 'Standard EPC');
        Project__c target = new Project__c(Start_Date__c = Date.newInstance(2026, 3, 2), Total_Budget__c = 2000);
        insert target;
        WBSTemplateService.instantiate(templateId, target.Id, Date.newInstance(2026, 3, 2));
        Test.stopTest();

        // Template captured 3 items.
        Integer tiCount = [SELECT COUNT() FROM WBS_Template_Item__c WHERE WBS_Template__c = :templateId];
        System.assertEquals(3, tiCount, 'template snapshot has 3 items');

        // getTemplates returns it.
        System.assert(WBSTemplateService.getTemplates().size() >= 1, 'template listed');

        // Target project now has 3 WBS items.
        List<WBS_Item__c> items = [
            SELECT Id, Code__c, Level__c, Parent_WBS__c, BAC__c, Baseline_Start__c, Current_Start__c, Critical_Path__c
            FROM WBS_Item__c WHERE Project__c = :target.Id ORDER BY Code__c
        ];
        System.assertEquals(3, items.size(), 'instantiated 3 items');

        // Budget scaled to the target budget (A was 60% of 1000 -> 60% of 2000 = 1200).
        WBS_Item__c a = null;
        for (WBS_Item__c w : items) if (w.Code__c == '1.1') a = w;
        System.assertEquals(1200, a.BAC__c, 'budget scaled to target total budget');

        // Dependency recreated -> CPM ran -> baseline frozen from schedule.
        Integer depCount = [SELECT COUNT() FROM WBS_Dependency__c WHERE Successor__r.Project__c = :target.Id];
        System.assertEquals(1, depCount, 'dependency recreated');
        System.assertNotEquals(null, a.Baseline_Start__c, 'baseline frozen from CPM schedule');
    }

    @isTest
    static void testInstantiateValidation() {
        Boolean threw = false;
        try {
            WBSTemplateService.instantiate(null, null, null);
        } catch (Exception e) {
            threw = true;
        }
        System.assertEquals(true, threw, 'null args rejected');
    }
}
