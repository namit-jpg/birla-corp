/**
 * Daily WBS delay monitor. For every project it recomputes the CPM schedule,
 * scores delay risk, and fires escalation alerts. Runs as a Batchable (one
 * project per scope) so each project gets its own governor budget; schedule it
 * via the Schedulable entry point.
 *
 *   System.schedule('WBS Delay Monitor', '0 0 6 * * ?', new WBSDelayMonitorSchedulable());
 */
public with sharing class WBSDelayMonitorSchedulable
        implements Schedulable, Database.Batchable<SObject> {

    public void execute(SchedulableContext sc) {
        Database.executeBatch(this, 1);
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id FROM Project__c
            WHERE Id IN (SELECT Project__c FROM WBS_Item__c)
        ]);
    }

    public void execute(Database.BatchableContext bc, List<Project__c> scope) {
        for (Project__c p : scope) {
            try {
                CPMEngine.recalculate(p.Id);
                WBSDelayRiskService.evaluate(p.Id);
                WBSDelayAlertService.run(p.Id);
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'WBS monitor failed for ' + p.Id + ': ' + e.getMessage());
            }
        }
    }

    public void finish(Database.BatchableContext bc) {}
}
