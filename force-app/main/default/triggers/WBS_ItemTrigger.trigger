/**
 * Recalculates the CPM schedule for affected projects whenever WBS items change.
 * Guarded by TriggerHelper.isRunning so CPMEngine's own writes don't recurse.
 */
trigger WBS_ItemTrigger on WBS_Item__c (after insert, after update, after delete, after undelete) {
    if (TriggerHelper.isRunning) return;

    Set<Id> projectIds = new Set<Id>();
    List<WBS_Item__c> scope = Trigger.isDelete ? Trigger.old : Trigger.new;
    for (WBS_Item__c item : scope) {
        if (item.Project__c != null) projectIds.add(item.Project__c);
    }
    for (Id projectId : projectIds) {
        CPMEngine.recalculate(projectId);
    }
}
