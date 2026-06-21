/**
 * WBS template instantiation and snapshotting.
 *  - getTemplates(): active templates for the builder picker.
 *  - instantiate(): clone a template tree onto a Project (items + dependencies),
 *    then run CPM and freeze the baseline from the computed schedule.
 *  - saveAsTemplate(): snapshot a Project's live WBS tree + dependencies into a
 *    new reusable template.
 */
public with sharing class WBSTemplateService {

    public class TemplateOption {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
    }

    @AuraEnabled(cacheable=true)
    public static List<TemplateOption> getTemplates() {
        List<TemplateOption> opts = new List<TemplateOption>();
        for (WBS_Template__c t : [
                SELECT Id, Name FROM WBS_Template__c WHERE Is_Active__c = true
                WITH USER_MODE ORDER BY Name ASC
        ]) {
            TemplateOption o = new TemplateOption();
            o.id = t.Id; o.name = t.Name;
            opts.add(o);
        }
        return opts;
    }

    @AuraEnabled
    public static void instantiate(Id templateId, Id projectId, Date anchorStart) {
        if (templateId == null || projectId == null) {
            throw new AuraHandledException('Template and Project are required.');
        }
        Project__c proj = [SELECT Id, Total_Budget__c FROM Project__c WHERE Id = :projectId LIMIT 1];
        Decimal projectBudget = proj.Total_Budget__c;

        List<WBS_Template_Item__c> tItems = [
            SELECT Id, Name, Code__c, Level__c, Parent_Template_Item__c,
                   Typical_Duration_Days__c, Budget_Percentage__c, Control_Account__c,
                   Predecessor_Code__c, Dependency_Type__c, Lag_Days__c
            FROM WBS_Template_Item__c
            WHERE WBS_Template__c = :templateId
            WITH USER_MODE
            ORDER BY Level__c ASC NULLS FIRST, Sequence__c ASC NULLS LAST, Code__c ASC NULLS LAST
        ];
        if (tItems.isEmpty()) {
            throw new AuraHandledException('The selected template has no items.');
        }

        // 1) Create one WBS item per template item (parents handled afterwards).
        Map<Id, WBS_Item__c> newByTemplateItemId = new Map<Id, WBS_Item__c>();
        List<WBS_Item__c> toInsert = new List<WBS_Item__c>();
        for (WBS_Template_Item__c ti : tItems) {
            WBS_Item__c w = new WBS_Item__c(
                Project__c = projectId,
                Name__c = ti.Name,
                Code__c = ti.Code__c,
                Level__c = ti.Level__c,
                Duration__c = ti.Typical_Duration_Days__c,
                Control_Account__c = ti.Control_Account__c == true
            );
            if (projectBudget != null && ti.Budget_Percentage__c != null) {
                w.BAC__c = (projectBudget * ti.Budget_Percentage__c / 100).setScale(2);
            }
            newByTemplateItemId.put(ti.Id, w);
            toInsert.add(w);
        }
        // Suppress CPM recalcs during the bulk build; we run it once at the end.
        TriggerHelper.isRunning = true;
        insert toInsert;
        TriggerHelper.isRunning = false;

        // 2) Wire parents + build code -> new WBS Id map.
        Map<String, Id> idByCode = new Map<String, Id>();
        List<WBS_Item__c> parentUpdates = new List<WBS_Item__c>();
        for (WBS_Template_Item__c ti : tItems) {
            WBS_Item__c w = newByTemplateItemId.get(ti.Id);
            if (ti.Code__c != null) idByCode.put(ti.Code__c, w.Id);
            if (ti.Parent_Template_Item__c != null && newByTemplateItemId.containsKey(ti.Parent_Template_Item__c)) {
                parentUpdates.add(new WBS_Item__c(Id = w.Id,
                    Parent_WBS__c = newByTemplateItemId.get(ti.Parent_Template_Item__c).Id));
            }
        }
        if (!parentUpdates.isEmpty()) {
            TriggerHelper.isRunning = true;
            update parentUpdates;
            TriggerHelper.isRunning = false;
        }

        // 3) Recreate dependencies from Predecessor_Code__c.
        List<WBS_Dependency__c> deps = new List<WBS_Dependency__c>();
        for (WBS_Template_Item__c ti : tItems) {
            if (String.isBlank(ti.Predecessor_Code__c)) continue;
            Id successorId = newByTemplateItemId.get(ti.Id).Id;
            for (String code : ti.Predecessor_Code__c.split(',')) {
                String c = code.trim();
                if (String.isBlank(c) || !idByCode.containsKey(c)) continue;
                deps.add(new WBS_Dependency__c(
                    Successor__c = successorId,
                    Predecessor__c = idByCode.get(c),
                    Dependency_Type__c = String.isBlank(ti.Dependency_Type__c) ? 'FS' : ti.Dependency_Type__c,
                    Lag_Days__c = ti.Lag_Days__c
                ));
            }
        }
        if (!deps.isEmpty()) {
            TriggerHelper.isRunning = true;
            insert deps;
            TriggerHelper.isRunning = false;
        }

        // 4) Set project start (if provided) and compute the schedule.
        if (anchorStart != null) {
            update new Project__c(Id = projectId, Start_Date__c = anchorStart);
        }
        CPMEngine.recalculate(projectId);

        // 5) Freeze the baseline from the freshly computed schedule.
        List<WBS_Item__c> freeze = new List<WBS_Item__c>();
        for (WBS_Item__c w : [
                SELECT Id, Current_Start__c, Current_Finish__c
                FROM WBS_Item__c WHERE Project__c = :projectId
        ]) {
            freeze.add(new WBS_Item__c(Id = w.Id,
                Baseline_Start__c = w.Current_Start__c,
                Baseline_Finish__c = w.Current_Finish__c));
        }
        if (!freeze.isEmpty()) {
            TriggerHelper.isRunning = true;
            update freeze;
            TriggerHelper.isRunning = false;
        }
    }

    @AuraEnabled
    public static Id saveAsTemplate(Id projectId, String templateName) {
        if (projectId == null || String.isBlank(templateName)) {
            throw new AuraHandledException('Project and template name are required.');
        }
        WBS_Template__c tmpl = new WBS_Template__c(Name = templateName, Is_Active__c = true);
        insert tmpl;

        List<WBS_Item__c> items = [
            SELECT Id, Name__c, Name, Code__c, Level__c, Parent_WBS__c,
                   Duration__c, BAC__c, Control_Account__c
            FROM WBS_Item__c WHERE Project__c = :projectId
            WITH USER_MODE
            ORDER BY Level__c ASC NULLS FIRST, Code__c ASC NULLS LAST
        ];
        if (items.isEmpty()) {
            throw new AuraHandledException('This project has no WBS items to snapshot.');
        }

        // Percentages are based on LEAF budgets only (summary BAC is a rollup of children).
        Set<Id> hasChildren = new Set<Id>();
        for (WBS_Item__c w : items) if (w.Parent_WBS__c != null) hasChildren.add(w.Parent_WBS__c);
        Decimal totalLeafBac = 0;
        for (WBS_Item__c w : items) {
            if (!hasChildren.contains(w.Id)) totalLeafBac += (w.BAC__c != null ? w.BAC__c : 0);
        }

        // 1) Create template items.
        Map<Id, WBS_Template_Item__c> tiByWbsId = new Map<Id, WBS_Template_Item__c>();
        List<WBS_Template_Item__c> toInsert = new List<WBS_Template_Item__c>();
        for (WBS_Item__c w : items) {
            Boolean isLeaf = !hasChildren.contains(w.Id);
            WBS_Template_Item__c ti = new WBS_Template_Item__c(
                WBS_Template__c = tmpl.Id,
                Name = (w.Name__c != null ? w.Name__c : w.Name),
                Code__c = w.Code__c,
                Level__c = w.Level__c,
                Typical_Duration_Days__c = w.Duration__c,
                Control_Account__c = w.Control_Account__c == true,
                Budget_Percentage__c = (isLeaf && totalLeafBac > 0 && w.BAC__c != null)
                    ? (w.BAC__c * 100 / totalLeafBac).setScale(2) : null
            );
            tiByWbsId.put(w.Id, ti);
            toInsert.add(ti);
        }
        insert toInsert;

        // 2) Wire parent template items (merged with dep updates below, keyed by Id).
        Map<Id, WBS_Template_Item__c> updateById = new Map<Id, WBS_Template_Item__c>();
        for (WBS_Item__c w : items) {
            if (w.Parent_WBS__c != null && tiByWbsId.containsKey(w.Parent_WBS__c)) {
                Id tiId = tiByWbsId.get(w.Id).Id;
                updateById.put(tiId, new WBS_Template_Item__c(Id = tiId,
                    Parent_Template_Item__c = tiByWbsId.get(w.Parent_WBS__c).Id));
            }
        }

        // 3) Capture dependencies onto the successor template item (code list + type/lag).
        Map<Id, String> codeByWbsId = new Map<Id, String>();
        for (WBS_Item__c w : items) codeByWbsId.put(w.Id, w.Code__c);
        Map<Id, List<String>> predCodesBySucc = new Map<Id, List<String>>();
        Map<Id, WBS_Dependency__c> firstDepBySucc = new Map<Id, WBS_Dependency__c>();
        for (WBS_Dependency__c d : [
                SELECT Successor__c, Predecessor__c, Dependency_Type__c, Lag_Days__c
                FROM WBS_Dependency__c
                WHERE Successor__r.Project__c = :projectId
                  AND Predecessor__c != null AND Successor__c != null
                WITH USER_MODE
        ]) {
            if (!predCodesBySucc.containsKey(d.Successor__c)) {
                predCodesBySucc.put(d.Successor__c, new List<String>());
                firstDepBySucc.put(d.Successor__c, d);
            }
            String pc = codeByWbsId.get(d.Predecessor__c);
            if (pc != null) predCodesBySucc.get(d.Successor__c).add(pc);
        }
        for (Id succId : predCodesBySucc.keySet()) {
            if (!tiByWbsId.containsKey(succId)) continue;
            Id tiId = tiByWbsId.get(succId).Id;
            WBS_Dependency__c first = firstDepBySucc.get(succId);
            WBS_Template_Item__c upd = updateById.containsKey(tiId)
                ? updateById.get(tiId) : new WBS_Template_Item__c(Id = tiId);
            upd.Predecessor_Code__c = String.join(predCodesBySucc.get(succId), ',');
            upd.Dependency_Type__c = first.Dependency_Type__c;
            upd.Lag_Days__c = first.Lag_Days__c;
            updateById.put(tiId, upd);
        }
        if (!updateById.isEmpty()) update updateById.values();

        return tmpl.Id;
    }
}
