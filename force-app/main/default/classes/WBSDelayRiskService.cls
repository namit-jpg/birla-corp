/**
 * Rule-based delay-risk scoring for WBS leaf items.
 * Reads CPM outputs and progress vs. elapsed time off the baseline, then writes
 * Delay_Risk_Score__c / Delay_Likelihood__c / Likely_To_Delay_Project__c and a
 * plain-language Project_Delay_Reason__c narrative including impacted successors.
 */
public with sharing class WBSDelayRiskService {

    @AuraEnabled
    public static void evaluate(Id projectId) {
        if (projectId == null) return;
        Date today = Date.today();

        // Identify summary (parent) items — only leaves get scored.
        Set<Id> hasChildren = new Set<Id>();
        for (AggregateResult ar : [
            SELECT Parent_WBS__c pid FROM WBS_Item__c
            WHERE Project__c = :projectId AND Parent_WBS__c != null
            GROUP BY Parent_WBS__c
        ]) {
            hasChildren.add((Id) ar.get('pid'));
        }

        List<WBS_Item__c> items = [
            SELECT Id, Code__c, Name__c, Percent_Complete__c,
                   Baseline_Start__c, Baseline_Finish__c,
                   Float_Days__c, Critical_Path__c,
                   (SELECT Successor__r.Code__c, Successor__r.Name__c
                    FROM Successor_Links__r
                    ORDER BY Successor__r.Code__c)
            FROM WBS_Item__c
            WHERE Project__c = :projectId
        ];

        List<WBS_Item__c> updates = new List<WBS_Item__c>();
        for (WBS_Item__c w : items) {
            if (hasChildren.contains(w.Id)) {
                updates.add(new WBS_Item__c(
                    Id = w.Id,
                    Delay_Risk_Score__c = 0,
                    Delay_Likelihood__c = 'Low',
                    Likely_To_Delay_Project__c = false,
                    Project_Delay_Reason__c = null
                ));
                continue;
            }

            Decimal pct     = w.Percent_Complete__c != null ? w.Percent_Complete__c : 0;
            Decimal elapsed = elapsedPct(w.Baseline_Start__c, w.Baseline_Finish__c, today);
            Decimal behind  = elapsed - pct;
            Decimal floatDays = w.Float_Days__c;

            Decimal score = 0;
            if (behind > 0)                                         score += behind * 0.7;
            if (floatDays != null && floatDays <= 10)               score += (10 - Math.max(floatDays, -20)) * 2;
            if (w.Critical_Path__c == true && behind > 0)           score += 20;
            if (pct == 0 && w.Baseline_Start__c != null && today > w.Baseline_Start__c) score += 25;
            if (score < 0)   score = 0;
            if (score > 100) score = 100;

            String band = score >= 75 ? 'Critical' : score >= 50 ? 'High' : score >= 25 ? 'Medium' : 'Low';
            Boolean likelyToDelay =
                ((floatDays != null && floatDays <= 0) || w.Critical_Path__c == true) && behind > 0;

            updates.add(new WBS_Item__c(
                Id = w.Id,
                Delay_Risk_Score__c          = score.setScale(0),
                Delay_Likelihood__c          = band,
                Likely_To_Delay_Project__c   = likelyToDelay,
                Project_Delay_Reason__c      = buildNarrative(
                    pct, elapsed, behind, floatDays,
                    w.Critical_Path__c == true, band,
                    w.Baseline_Start__c, w.Baseline_Finish__c,
                    w.Successor_Links__r
                )
            ));
        }

        if (!updates.isEmpty()) {
            TriggerHelper.isRunning = true;
            update updates;
            TriggerHelper.isRunning = false;
        }
    }

    // ── helpers ────────────────────────────────────────────────────────────────

    private static Decimal elapsedPct(Date startD, Date finishD, Date today) {
        if (startD == null || finishD == null) return 0;
        if (today <= startD) return 0;
        if (today >= finishD) return 100;
        Integer total = startD.daysBetween(finishD);
        if (total <= 0) return 100;
        return ((Decimal) startD.daysBetween(today) / total * 100).setScale(2);
    }

    private static String buildNarrative(
            Decimal pct, Decimal elapsed, Decimal behind,
            Decimal floatDays, Boolean critical, String band,
            Date startD, Date finishD,
            List<WBS_Dependency__c> successorLinks) {

        List<String> parts = new List<String>();

        // 1. Overall risk headline — plain language
        String headline;
        if      (band == 'Critical') headline = 'This activity is critically delayed and requires immediate escalation.';
        else if (band == 'High')     headline = 'This activity is significantly behind and needs urgent attention.';
        else if (band == 'Medium')   headline = 'This activity is falling behind and should be reviewed.';
        else                         headline = 'This activity is progressing as planned.';
        parts.add(headline);

        // 2. Progress vs. time consumed
        if (elapsed > 0) {
            parts.add(
                pct.setScale(0) + '% of the work is complete, but ' +
                elapsed.setScale(0) + '% of the planned duration has already passed.'
            );
        }

        // 3. How far behind in actual days (more meaningful than percentages)
        if (behind > 0 && startD != null && finishD != null) {
            Integer duration = startD.daysBetween(finishD);
            if (duration > 0) {
                Integer daysBehind = ((behind / 100) * duration).intValue();
                if (daysBehind > 0) {
                    parts.add(
                        'Based on the baseline schedule, the activity is running approximately ' +
                        daysBehind + ' day(s) behind.'
                    );
                }
            }
        }

        // 4. Not started yet but past the planned start date
        if (pct == 0 && startD != null && Date.today() > startD) {
            parts.add('Work has not yet started, even though the planned start date has passed.');
        }

        // 5. Impact on project completion — no technical jargon
        if (critical) {
            parts.add(
                'This activity directly controls the project completion date — ' +
                'any further delay will push the overall project end date out.'
            );
        } else if (floatDays != null) {
            if (floatDays <= 0) {
                parts.add(
                    'The activity has used up all available time buffer and is now ' +
                    'affecting the project completion date.'
                );
            } else if (floatDays <= 5) {
                parts.add(
                    'Only ' + floatDays.setScale(0) + ' day(s) of spare time remain before ' +
                    'a delay here starts pushing the project end date.'
                );
            } else if (floatDays <= 15) {
                parts.add(
                    'There are ' + floatDays.setScale(0) + ' days of spare time remaining, ' +
                    'but this activity needs attention soon to avoid impacting the project.'
                );
            }
        }

        // 6. Downstream (successor) activities that are blocked or at risk
        if (successorLinks != null && !successorLinks.isEmpty()) {
            List<String> blockedLabels = new List<String>();
            for (WBS_Dependency__c dep : successorLinks) {
                if (dep.Successor__r != null) {
                    String lbl = '';
                    if (dep.Successor__r.Code__c != null) lbl += dep.Successor__r.Code__c;
                    if (dep.Successor__r.Name__c  != null) lbl += (lbl.length() > 0 ? ' – ' : '') + dep.Successor__r.Name__c;
                    if (lbl.length() > 0) blockedLabels.add(lbl);
                }
            }
            if (!blockedLabels.isEmpty()) {
                parts.add(
                    'The following ' + (blockedLabels.size() == 1 ? 'activity is' : 'activities are') +
                    ' waiting on this to complete before they can proceed: ' +
                    String.join(blockedLabels, ', ') + '.'
                );
            }
        }

        return String.join(parts, ' ');
    }
}
