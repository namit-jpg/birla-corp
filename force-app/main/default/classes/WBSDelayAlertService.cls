/**
 * Escalation routing + delivery for WBS delay alerts.
 *
 * Rules:
 *  - When a WBS item is delayed (actual start crossed planned, or High/Critical
 *    delay likelihood), notify the Custodian of its child item(s).
 *  - When the delay threatens the overall project end date (End_Date past
 *    Baseline_Finish) and the item is Likely_To_Delay_Project, also notify the
 *    Project Manager, ALL critical-path custodians, and the Assignee of the
 *    item's successor(s).
 *
 * Delivery: in-app/mobile Custom Notification (WBS_Delay_Alert) + email.
 * Slack is left as an optional hook (postSlack) gated for a future toggle.
 */
public with sharing class WBSDelayAlertService {

    @AuraEnabled
    public static Integer run(Id projectId) {
        if (projectId == null) return 0;

        Project__c proj = [
            SELECT Id, Name, Project_Manager__c, End_Date__c, Baseline_Finish__c, Planned_Finish_Variance__c
            FROM Project__c WHERE Id = :projectId LIMIT 1
        ];
        Boolean projectDelayed = proj.Planned_Finish_Variance__c != null && proj.Planned_Finish_Variance__c > 0;

        List<WBS_Item__c> items = [
            SELECT Id, Code__c, Name__c, Parent_WBS__c, Custodian__c, Assignee__c,
                   Is_Actual_Start_Crossed__c, Delay_Likelihood__c, Likely_To_Delay_Project__c,
                   Critical_Path__c
            FROM WBS_Item__c WHERE Project__c = :projectId
        ];
        if (items.isEmpty()) return 0;

        Map<Id, WBS_Item__c> byId = new Map<Id, WBS_Item__c>(items);

        // children by parent
        Map<Id, List<WBS_Item__c>> childrenByParent = new Map<Id, List<WBS_Item__c>>();
        Set<Id> criticalCustodians = new Set<Id>();
        for (WBS_Item__c w : items) {
            if (w.Parent_WBS__c != null) {
                if (!childrenByParent.containsKey(w.Parent_WBS__c)) childrenByParent.put(w.Parent_WBS__c, new List<WBS_Item__c>());
                childrenByParent.get(w.Parent_WBS__c).add(w);
            }
            if (w.Critical_Path__c == true && w.Custodian__c != null) criticalCustodians.add(w.Custodian__c);
        }

        // delayed items
        List<WBS_Item__c> delayed = new List<WBS_Item__c>();
        Set<Id> delayedIds = new Set<Id>();
        for (WBS_Item__c w : items) {
            if (w.Is_Actual_Start_Crossed__c == true
                || w.Delay_Likelihood__c == 'High' || w.Delay_Likelihood__c == 'Critical') {
                delayed.add(w);
                delayedIds.add(w.Id);
            }
        }
        if (delayed.isEmpty()) return 0;

        // successor assignees for delayed items (predecessor -> successor)
        Map<Id, Set<Id>> successorAssigneesByPred = new Map<Id, Set<Id>>();
        for (WBS_Dependency__c d : [
            SELECT Predecessor__c, Successor__r.Assignee__c
            FROM WBS_Dependency__c
            WHERE Predecessor__c IN :delayedIds AND Successor__r.Assignee__c != null
        ]) {
            if (!successorAssigneesByPred.containsKey(d.Predecessor__c)) successorAssigneesByPred.put(d.Predecessor__c, new Set<Id>());
            successorAssigneesByPred.get(d.Predecessor__c).add(d.Successor__r.Assignee__c);
        }

        Id notifTypeId = notificationTypeId();
        Integer sent = 0;
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();

        for (WBS_Item__c w : delayed) {
            String label = (w.Code__c != null ? w.Code__c + ' ' : '') + (w.Name__c != null ? w.Name__c : '');
            Set<Id> recipients = new Set<Id>();

            // 1) Custodian(s) of the delayed item's children.
            if (childrenByParent.containsKey(w.Id)) {
                for (WBS_Item__c child : childrenByParent.get(w.Id)) {
                    if (child.Custodian__c != null) recipients.add(child.Custodian__c);
                }
            }
            // Fallback: if the delayed item is itself a leaf, alert its own custodian.
            if (recipients.isEmpty() && w.Custodian__c != null) recipients.add(w.Custodian__c);

            String body = 'WBS item ' + label + ' is delayed (' +
                (w.Is_Actual_Start_Crossed__c == true ? 'actual start crossed planned' : w.Delay_Likelihood__c + ' delay likelihood') + ').';

            // 2) Project-end-date impact escalation.
            if (projectDelayed && w.Likely_To_Delay_Project__c == true) {
                if (proj.Project_Manager__c != null) recipients.add(proj.Project_Manager__c);
                recipients.addAll(criticalCustodians);
                if (successorAssigneesByPred.containsKey(w.Id)) recipients.addAll(successorAssigneesByPred.get(w.Id));
                body += ' This is projected to push the project end date out by ' +
                        proj.Planned_Finish_Variance__c.setScale(0) + ' day(s).';
            }

            if (recipients.isEmpty()) continue;

            if (notifTypeId != null) {
                Messaging.CustomNotification n = new Messaging.CustomNotification();
                n.setNotificationTypeId(notifTypeId);
                n.setTitle('Schedule Delay: ' + label);
                n.setBody(body);
                n.setTargetId(w.Id);
                Set<String> recipientStrs = new Set<String>();
                for (Id rid : recipients) recipientStrs.add(String.valueOf(rid));
                try { n.send(recipientStrs); sent++; } catch (Exception e) { /* swallow per-item */ }
            }
            emails.add(buildEmail(recipients, 'Schedule Delay: ' + label, body, proj.Name));
        }

        List<Messaging.SingleEmailMessage> toSend = new List<Messaging.SingleEmailMessage>();
        for (Messaging.SingleEmailMessage m : emails) if (m != null) toSend.add(m);
        if (!toSend.isEmpty() && !Test.isRunningTest()) Messaging.sendEmail(toSend, false);

        return sent;
    }

    private static Id notificationTypeId() {
        List<CustomNotificationType> t = [
            SELECT Id FROM CustomNotificationType WHERE DeveloperName = 'WBS_Delay_Alert' LIMIT 1
        ];
        return t.isEmpty() ? null : t[0].Id;
    }

    private static Messaging.SingleEmailMessage buildEmail(Set<Id> userIds, String subject, String body, String projectName) {
        List<String> addrs = new List<String>();
        for (User u : [SELECT Email FROM User WHERE Id IN :userIds AND IsActive = true AND Email != null]) {
            addrs.add(u.Email);
        }
        if (addrs.isEmpty()) return null;
        Messaging.SingleEmailMessage m = new Messaging.SingleEmailMessage();
        m.setToAddresses(addrs);
        m.setSubject('[' + projectName + '] ' + subject);
        m.setHtmlBody('<p>' + body.escapeHtml4() + '</p><p>Open Salesforce to review the WBS schedule.</p>');
        m.setSaveAsActivity(false);
        return m;
    }
}
