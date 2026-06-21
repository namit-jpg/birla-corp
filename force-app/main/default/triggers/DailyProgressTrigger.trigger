trigger DailyProgressTrigger on Daily_Progress__c (after insert, after update, after delete, after undelete) {
    DailyProgressTriggerHandler.handle(Trigger.new, Trigger.old, Trigger.operationType);
}