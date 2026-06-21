/**
 * Backend for the WBS tree-grid builder. Ported from the Glatt org and adapted
 * to the birla-corp WBS_Item__c schema (standard Name; Code__c, Duration__c,
 * BAC__c, Percent_Complete__c, Current_Start/Finish__c, Critical_Path__c,
 * Parent_WBS__c). Dependencies use the WBS_Dependency__c junction only.
 *
 * Authoring helpers (createWBSItem, updateWBSItems, updateWBSItemParent,
 * addDependency) are folded in from the EPC builder so the tree grid can add /
 * reparent / bulk-edit rows without separate controllers.
 */
public with sharing class WBSTreeController {

    @AuraEnabled(cacheable=true)
    public static List<WBSNode> getWBSTree(Id projectId) {
        List<WBS_Item__c> allItems = [
            SELECT Id, Name, Name__c, Code__c, Level__c, Duration__c,
                   BAC__c, Percent_Complete__c, Current_Start__c, Current_Finish__c,
                   Early_Start__c, Early_Finish__c, Float_Days__c, Critical_Path__c,
                   Actual_Start__c, Actual_Finish__c, Control_Account__c,
                   Parent_WBS__c,
                   (SELECT Id FROM Predecessor_Links__r)
            FROM WBS_Item__c
            WHERE Project__c = :projectId
            WITH USER_MODE
            ORDER BY Code__c ASC NULLS LAST
        ];

        Map<Id, WBSNode> nodeMap = new Map<Id, WBSNode>();
        for (WBS_Item__c item : allItems) {
            nodeMap.put(item.Id, new WBSNode(item));
        }

        List<WBSNode> roots = new List<WBSNode>();
        for (WBS_Item__c item : allItems) {
            WBSNode node = nodeMap.get(item.Id);
            if (item.Parent_WBS__c != null && nodeMap.containsKey(item.Parent_WBS__c)) {
                nodeMap.get(item.Parent_WBS__c).children.add(node);
            } else {
                roots.add(node);
            }
        }
        return roots;
    }

    @AuraEnabled(cacheable=true)
    public static List<GanttTask> getWBSFlat(Id projectId) {
        List<WBS_Item__c> items = [
            SELECT Id, Name, Name__c, Code__c, Current_Start__c, Current_Finish__c,
                   Early_Start__c, Early_Finish__c, Actual_Start__c, Actual_Finish__c,
                   Percent_Complete__c, Critical_Path__c
            FROM WBS_Item__c
            WHERE Project__c = :projectId
              AND (Current_Start__c != null OR Early_Start__c != null)
              AND (Current_Finish__c != null OR Early_Finish__c != null)
            WITH USER_MODE
            ORDER BY Code__c ASC NULLS LAST
        ];

        Map<Id, List<String>> predIds = new Map<Id, List<String>>();
        for (WBS_Dependency__c d : [
                SELECT Successor__c, Predecessor__c
                FROM WBS_Dependency__c
                WHERE Successor__r.Project__c = :projectId
                  AND Predecessor__c != null AND Successor__c != null
                WITH USER_MODE
        ]) {
            if (!predIds.containsKey(d.Successor__c)) predIds.put(d.Successor__c, new List<String>());
            predIds.get(d.Successor__c).add(String.valueOf(d.Predecessor__c));
        }

        List<GanttTask> tasks = new List<GanttTask>();
        for (WBS_Item__c item : items) {
            Date s = item.Early_Start__c  != null ? item.Early_Start__c  : item.Current_Start__c;
            Date e = item.Early_Finish__c != null ? item.Early_Finish__c : item.Current_Finish__c;
            if (s == null || e == null) continue;

            String title = item.Name__c != null ? item.Name__c : item.Name;
            GanttTask t = new GanttTask();
            t.id           = item.Id;
            t.name         = (item.Code__c != null ? item.Code__c + ' ' : '') + title;
            t.start        = String.valueOf(s);
            t.endDate      = String.valueOf(e);
            t.progress     = item.Percent_Complete__c != null ? item.Percent_Complete__c : 0;
            t.dependencies = predIds.containsKey(item.Id)
                ? String.join(predIds.get(item.Id), ',') : '';
            t.isCritical   = item.Critical_Path__c;
            t.actualStart  = item.Actual_Start__c  != null ? String.valueOf(item.Actual_Start__c)  : null;
            t.actualFinish = item.Actual_Finish__c != null ? String.valueOf(item.Actual_Finish__c) : null;
            tasks.add(t);
        }
        return tasks;
    }

    @AuraEnabled
    public static void runCPM(Id projectId) {
        CPMEngine.recalculate(projectId);
    }

    @AuraEnabled
    public static void saveProgress(Id itemId, Decimal progressPct, Id projectId) {
        update new WBS_Item__c(Id = itemId, Percent_Complete__c = progressPct);
        CPMEngine.recalculate(projectId);
    }

    @AuraEnabled
    public static void deleteWBSItem(Id itemId) {
        List<WBS_Item__c> children = [
            SELECT Id FROM WBS_Item__c WHERE Parent_WBS__c = :itemId LIMIT 1
        ];
        if (!children.isEmpty()) {
            throw new AuraHandledException('Cannot delete a WBS item that has children. Delete the children first.');
        }
        delete [SELECT Id FROM WBS_Item__c WHERE Id = :itemId WITH USER_MODE LIMIT 1];
    }

    // -- Dependencies (junction) ---------------------------------------
    @AuraEnabled(cacheable=true)
    public static List<DependencyRow> getDependencies(Id wbsItemId) {
        List<DependencyRow> rows = new List<DependencyRow>();
        for (WBS_Dependency__c d : [
                SELECT Id, Predecessor__c, Predecessor__r.Name, Predecessor__r.Code__c,
                       Dependency_Type__c, Lag_Days__c
                FROM WBS_Dependency__c
                WHERE Successor__c = :wbsItemId AND Predecessor__c != null
                WITH USER_MODE
                ORDER BY Predecessor__r.Code__c ASC NULLS LAST
        ]) {
            DependencyRow r = new DependencyRow();
            r.id              = d.Id;
            r.predecessorId   = d.Predecessor__c;
            r.predecessorName = d.Predecessor__r.Name;
            r.predecessorCode = d.Predecessor__r.Code__c;
            r.dependencyType  = d.Dependency_Type__c;
            r.lagDays         = d.Lag_Days__c;
            rows.add(r);
        }
        return rows;
    }

    @AuraEnabled
    public static void addDependency(Id successorId, Id predecessorId, String dependencyType, Decimal lagDays, Id projectId) {
        if (successorId == predecessorId) {
            throw new AuraHandledException('A task cannot depend on itself.');
        }
        insert new WBS_Dependency__c(
            Successor__c = successorId,
            Predecessor__c = predecessorId,
            Dependency_Type__c = String.isBlank(dependencyType) ? 'FS' : dependencyType,
            Lag_Days__c = lagDays
        );
        if (projectId != null) CPMEngine.recalculate(projectId);
    }

    @AuraEnabled
    public static void deleteDependency(Id dependencyId) {
        delete [SELECT Id FROM WBS_Dependency__c WHERE Id = :dependencyId WITH USER_MODE LIMIT 1];
    }

    // -- Authoring (folded in from EPC builder, adapted to standard Name) -
    @AuraEnabled
    public static Id createWBSItem(Id projectId, String wbsData) {
        Map<String, Object> data = (Map<String, Object>) JSON.deserializeUntyped(wbsData);
        WBS_Item__c rec = new WBS_Item__c(Project__c = projectId);
        if (data.get('name') != null)  rec.Name__c = String.valueOf(data.get('name'));
        if (data.get('code') != null)  rec.Code__c = String.valueOf(data.get('code'));
        if (data.get('level') != null) rec.Level__c = Integer.valueOf(String.valueOf(data.get('level')));
        if (data.get('parentId') != null) rec.Parent_WBS__c = String.valueOf(data.get('parentId'));
        if (data.get('controlAccount') != null) rec.Control_Account__c = Boolean.valueOf(String.valueOf(data.get('controlAccount')));
        if (data.get('bac') != null) rec.BAC__c = Decimal.valueOf(String.valueOf(data.get('bac')));
        if (data.get('duration') != null) rec.Duration__c = Decimal.valueOf(String.valueOf(data.get('duration')));
        if (data.get('baselineStart') != null) rec.Baseline_Start__c = Date.valueOf(String.valueOf(data.get('baselineStart')));
        if (data.get('baselineFinish') != null) rec.Baseline_Finish__c = Date.valueOf(String.valueOf(data.get('baselineFinish')));
        insert rec;
        return rec.Id;
    }

    @AuraEnabled
    public static void updateWBSItems(List<WBS_Item__c> wbsItems) {
        if (wbsItems == null || wbsItems.isEmpty()) return;
        List<WBS_Item__c> toUpdate = new List<WBS_Item__c>();
        for (WBS_Item__c item : wbsItems) {
            if (item.Id == null) continue;
            WBS_Item__c clean = new WBS_Item__c(Id = item.Id);
            if (item.Name__c != null) clean.Name__c = item.Name__c;
            if (item.Code__c != null) clean.Code__c = item.Code__c;
            if (item.Level__c != null) clean.Level__c = item.Level__c;
            if (item.BAC__c != null) clean.BAC__c = item.BAC__c;
            if (item.Percent_Complete__c != null) clean.Percent_Complete__c = item.Percent_Complete__c;
            if (item.Baseline_Start__c != null) clean.Baseline_Start__c = item.Baseline_Start__c;
            if (item.Baseline_Finish__c != null) clean.Baseline_Finish__c = item.Baseline_Finish__c;
            if (item.Duration__c != null) clean.Duration__c = item.Duration__c;
            if (item.Custodian__c != null) clean.Custodian__c = item.Custodian__c;
            if (item.Assignee__c != null) clean.Assignee__c = item.Assignee__c;
            toUpdate.add(clean);
        }
        if (!toUpdate.isEmpty()) update toUpdate;
    }

    @AuraEnabled
    public static Boolean updateWBSItemParent(Id wbsItemId, Id parentId) {
        WBS_Item__c item = [SELECT Id, Level__c, Parent_WBS__c FROM WBS_Item__c WHERE Id = :wbsItemId];
        Integer newLevel = 1;
        if (parentId != null) {
            WBS_Item__c parentItem = [SELECT Id, Level__c FROM WBS_Item__c WHERE Id = :parentId];
            newLevel = (parentItem.Level__c != null ? parentItem.Level__c.intValue() : 0) + 1;
        }
        if (newLevel > 7) {
            throw new AuraHandledException('Cannot create more than 7 levels of WBS items.');
        }
        item.Parent_WBS__c = parentId;
        item.Level__c = newLevel;
        update item;
        updateChildLevels(wbsItemId, newLevel + 1);
        return true;
    }

    private static void updateChildLevels(Id parentId, Integer level) {
        if (level > 8) return;
        List<WBS_Item__c> children = [SELECT Id FROM WBS_Item__c WHERE Parent_WBS__c = :parentId];
        if (children.isEmpty()) return;
        for (WBS_Item__c c : children) c.Level__c = level;
        update children;
        for (WBS_Item__c c : children) updateChildLevels(c.Id, level + 1);
    }

    // -- Wrapper DTOs --------------------------------------------------
    public class GanttTask {
        @AuraEnabled public String  id;
        @AuraEnabled public String  name;
        @AuraEnabled public String  start;
        @AuraEnabled public String  endDate;
        @AuraEnabled public Decimal progress;
        @AuraEnabled public String  dependencies;
        @AuraEnabled public Boolean isCritical;
        @AuraEnabled public String  actualStart;
        @AuraEnabled public String  actualFinish;
    }

    public class DependencyRow {
        @AuraEnabled public Id      id;
        @AuraEnabled public Id      predecessorId;
        @AuraEnabled public String  predecessorName;
        @AuraEnabled public String  predecessorCode;
        @AuraEnabled public String  dependencyType;
        @AuraEnabled public Decimal lagDays;
    }

    public class WBSNode {
        @AuraEnabled public Id      id;
        @AuraEnabled public String  name;
        @AuraEnabled public String  wbsCode;
        @AuraEnabled public Decimal level;
        @AuraEnabled public Decimal durationDays;
        @AuraEnabled public Decimal budget;
        @AuraEnabled public Decimal progress;
        @AuraEnabled public Date    startDate;
        @AuraEnabled public Date    endDate;
        @AuraEnabled public Date    earlyStart;
        @AuraEnabled public Date    earlyFinish;
        @AuraEnabled public Date    actualStart;
        @AuraEnabled public Date    actualFinish;
        @AuraEnabled public Decimal floatDays;
        @AuraEnabled public Boolean isCritical;
        @AuraEnabled public Boolean controlAccount;
        @AuraEnabled public Integer predecessorCount;
        @AuraEnabled public List<WBSNode> children = new List<WBSNode>();

        public WBSNode(WBS_Item__c item) {
            this.id             = item.Id;
            this.name           = item.Name__c != null ? item.Name__c : item.Name;
            this.wbsCode        = item.Code__c;
            this.level          = item.Level__c;
            this.durationDays   = item.Duration__c;
            this.budget         = item.BAC__c;
            this.progress       = item.Percent_Complete__c;
            this.startDate      = item.Current_Start__c;
            this.endDate        = item.Current_Finish__c;
            this.earlyStart     = item.Early_Start__c;
            this.earlyFinish    = item.Early_Finish__c;
            this.actualStart    = item.Actual_Start__c;
            this.actualFinish   = item.Actual_Finish__c;
            this.floatDays      = item.Float_Days__c;
            this.isCritical     = item.Critical_Path__c;
            this.controlAccount = item.Control_Account__c;
            this.predecessorCount = item.Predecessor_Links__r != null ? item.Predecessor_Links__r.size() : 0;
        }
    }
}
