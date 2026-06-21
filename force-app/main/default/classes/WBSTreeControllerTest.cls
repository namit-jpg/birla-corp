/**
 * Covers CPMEngine, WBSTreeController and the WBS triggers.
 */
@isTest
private class WBSTreeControllerTest {

    private static Project__c makeProject() {
        Project__c p = new Project__c(Start_Date__c = Date.newInstance(2026, 1, 5)); // Monday
        insert p;
        return p;
    }

    @isTest
    static void testCpmScheduleAndCriticalPath() {
        Project__c p = makeProject();

        WBS_Item__c parent = new WBS_Item__c(Project__c = p.Id, Name__c = 'Phase 1', Code__c = '1', Level__c = 1);
        insert parent;

        WBS_Item__c a = new WBS_Item__c(Project__c = p.Id, Name__c = 'Task A', Code__c = '1.1', Level__c = 2,
            Parent_WBS__c = parent.Id, Duration__c = 5, BAC__c = 100);
        WBS_Item__c b = new WBS_Item__c(Project__c = p.Id, Name__c = 'Task B', Code__c = '1.2', Level__c = 2,
            Parent_WBS__c = parent.Id, Duration__c = 3, BAC__c = 100);
        insert new List<WBS_Item__c>{ a, b };

        // B depends on A (Finish-to-Start)
        insert new WBS_Dependency__c(Predecessor__c = a.Id, Successor__c = b.Id, Dependency_Type__c = 'FS', Lag_Days__c = 0);

        Test.startTest();
        CPMEngine.recalculate(p.Id);
        Test.stopTest();

        Map<Id, WBS_Item__c> m = new Map<Id, WBS_Item__c>([
            SELECT Id, Early_Start__c, Early_Finish__c, Late_Finish__c, Float_Days__c,
                   Critical_Path__c, Current_Start__c, Current_Finish__c
            FROM WBS_Item__c WHERE Project__c = :p.Id
        ]);

        WBS_Item__c ra = m.get(a.Id);
        WBS_Item__c rb = m.get(b.Id);

        System.assertEquals(Date.newInstance(2026, 1, 5), ra.Early_Start__c, 'A starts at project origin');
        System.assertEquals(ra.Early_Start__c, ra.Current_Start__c, 'Current mirrors Early');
        // A finishes after 5 working days: Mon-Fri => Jan 9
        System.assertEquals(Date.newInstance(2026, 1, 9), ra.Early_Finish__c, 'A early finish');
        // B starts the next working day (Jan 12, Monday) and runs 3 days => Jan 14
        System.assertEquals(Date.newInstance(2026, 1, 12), rb.Early_Start__c, 'B starts after A (FS)');
        System.assertEquals(Date.newInstance(2026, 1, 14), rb.Early_Finish__c, 'B early finish');
        System.assertEquals(true, ra.Critical_Path__c, 'A is critical');
        System.assertEquals(true, rb.Critical_Path__c, 'B is critical');
        System.assertEquals(0, ra.Float_Days__c, 'A has zero float');
    }

    @isTest
    static void testProgressAndActualRollup() {
        Project__c p = makeProject();
        WBS_Item__c parent = new WBS_Item__c(Project__c = p.Id, Name__c = 'P', Code__c = '1', Level__c = 1);
        insert parent;
        WBS_Item__c a = new WBS_Item__c(Project__c = p.Id, Name__c = 'A', Code__c = '1.1', Level__c = 2,
            Parent_WBS__c = parent.Id, Duration__c = 4, BAC__c = 100, Percent_Complete__c = 100);
        WBS_Item__c b = new WBS_Item__c(Project__c = p.Id, Name__c = 'B', Code__c = '1.2', Level__c = 2,
            Parent_WBS__c = parent.Id, Duration__c = 4, BAC__c = 100, Percent_Complete__c = 50);
        insert new List<WBS_Item__c>{ a, b };

        Test.startTest();
        CPMEngine.recalculate(p.Id);
        Test.stopTest();

        WBS_Item__c rp = [SELECT Percent_Complete__c, Actual_Start__c, Actual_Finish__c FROM WBS_Item__c WHERE Id = :parent.Id];
        System.assertEquals(75, rp.Percent_Complete__c, 'Budget-weighted parent progress = (100+50)/2');
        System.assertNotEquals(null, rp.Actual_Start__c, 'Parent actual start rolled up from started child');
        System.assertEquals(null, rp.Actual_Finish__c, 'Parent not finished (B < 100%)');

        Project__c rpr = [SELECT Percent_Complete__c FROM Project__c WHERE Id = :p.Id];
        System.assertEquals(75, rpr.Percent_Complete__c, 'Project overall progress');

        WBS_Item__c ra = [SELECT Actual_Finish__c FROM WBS_Item__c WHERE Id = :a.Id];
        System.assertEquals(Date.today(), ra.Actual_Finish__c, '100% leaf gets actual finish stamped');
    }

    @isTest
    static void testControllerCrudAndQueries() {
        Project__c p = makeProject();

        Test.startTest();
        Id rootId = WBSTreeController.createWBSItem(p.Id, JSON.serialize(new Map<String, Object>{
            'name' => 'Root', 'code' => '1', 'level' => 1, 'bac' => 1000, 'duration' => 2
        }));
        Id childId = WBSTreeController.createWBSItem(p.Id, JSON.serialize(new Map<String, Object>{
            'name' => 'Child', 'code' => '1.1', 'level' => 2, 'parentId' => rootId, 'bac' => 500, 'duration' => 3
        }));
        Id child2Id = WBSTreeController.createWBSItem(p.Id, JSON.serialize(new Map<String, Object>{
            'name' => 'Child2', 'code' => '1.2', 'level' => 2, 'parentId' => rootId, 'bac' => 500, 'duration' => 2
        }));

        WBSTreeController.addDependency(child2Id, childId, 'FS', 1, p.Id);
        WBSTreeController.updateWBSItems(new List<WBS_Item__c>{
            new WBS_Item__c(Id = childId, Name__c = 'Child Renamed', Duration__c = 4)
        });
        WBSTreeController.updateWBSItemParent(child2Id, rootId);
        WBSTreeController.saveProgress(childId, 25, p.Id);
        Test.stopTest();

        List<WBSTreeController.WBSNode> tree = WBSTreeController.getWBSTree(p.Id);
        System.assertEquals(1, tree.size(), 'one root');
        System.assertEquals(2, tree[0].children.size(), 'two children');

        List<WBSTreeController.GanttTask> flat = WBSTreeController.getWBSFlat(p.Id);
        System.assert(flat.size() >= 1, 'gantt tasks produced');

        List<WBSTreeController.DependencyRow> deps = WBSTreeController.getDependencies(child2Id);
        System.assertEquals(1, deps.size(), 'one dependency');
        WBSTreeController.deleteDependency(deps[0].id);
        System.assertEquals(0, WBSTreeController.getDependencies(child2Id).size(), 'dependency removed');

        WBSTreeController.deleteWBSItem(child2Id);
        System.assertEquals(1, WBSTreeController.getWBSTree(p.Id)[0].children.size(), 'child removed');
    }

    @isTest
    static void testDeleteParentWithChildrenBlocked() {
        Project__c p = makeProject();
        WBS_Item__c parent = new WBS_Item__c(Project__c = p.Id, Name__c = 'P', Code__c = '1', Level__c = 1);
        insert parent;
        insert new WBS_Item__c(Project__c = p.Id, Name__c = 'C', Code__c = '1.1', Level__c = 2,
            Parent_WBS__c = parent.Id, Duration__c = 1, BAC__c = 10);
        Boolean blocked = false;
        try {
            WBSTreeController.deleteWBSItem(parent.Id);
        } catch (Exception e) {
            blocked = true;
        }
        System.assertEquals(true, blocked, 'deleting a parent with children should be blocked');
    }
}
