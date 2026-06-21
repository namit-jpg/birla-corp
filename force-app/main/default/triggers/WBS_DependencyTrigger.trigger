/**
 * Recalculates the CPM schedule when dependency links are added/changed/removed.
 * Resolves the project via the successor (or predecessor) WBS item.
 */
trigger WBS_DependencyTrigger on WBS_Dependency__c (after insert, after update, after delete, after undelete) {
    if (TriggerHelper.isRunning) return;

    Set<Id> wbsIds = new Set<Id>();
    List<WBS_Dependency__c> scope = Trigger.isDelete ? Trigger.old : Trigger.new;
    for (WBS_Dependency__c d : scope) {
        if (d.Successor__c != null) wbsIds.add(d.Successor__c);
        if (d.Predecessor__c != null) wbsIds.add(d.Predecessor__c);
    }
    if (wbsIds.isEmpty()) return;

    Set<Id> projectIds = new Set<Id>();
    for (WBS_Item__c item : [SELECT Project__c FROM WBS_Item__c WHERE Id IN :wbsIds AND Project__c != null]) {
        projectIds.add(item.Project__c);
    }
    for (Id projectId : projectIds) {
        CPMEngine.recalculate(projectId);
    }
}
