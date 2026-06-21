/**
 * WBS_Item__c Trigger
 *
 * Routes trigger events to WBSRollupHandler. All business logic lives in the handler.
 */
trigger WBSItemTrigger on WBS_Item__c (
    after insert,
    after update
) {
    if (Trigger.isAfter) {
        if (Trigger.isInsert) {
            WBSRollupHandler.afterInsert(Trigger.new);
        } else if (Trigger.isUpdate) {
            WBSRollupHandler.afterUpdate(Trigger.new, Trigger.oldMap);
        }
    }
}