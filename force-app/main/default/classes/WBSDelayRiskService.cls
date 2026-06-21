/**
 * Rule-based delay-risk scoring for WBS leaf items. Reads CPM outputs
 * (Float_Days__c, Critical_Path__c) and progress vs. elapsed time off the
 * baseline, and writes Delay_Risk_Score__c / Delay_Likelihood__c /
 * Likely_To_Delay_Project__c plus a short rule narrative into AI_Insight__c.
 * No AI/LLM is used.
 */
public with sharing class WBSDelayRiskService {

    @AuraEnabled
    public static void evaluate(Id projectId) {
        if (projectId == null) return;
        Date today = Date.today();

        // Identify summaries so we only score leaves.
        Set<Id> hasChildren = new Set<Id>();
        for (AggregateResult ar : [
            SELECT Parent_WBS__c pid FROM WBS_Item__c
            WHERE Project__c = :projectId AND Parent_WBS__c != null
            GROUP BY Parent_WBS__c
        ]) {
            hasChildren.add((Id) ar.get('pid'));
        }

        List<WBS_Item__c> items = [
            SELECT Id, Code__c, Name__c, Percent_Complete__c, Baseline_Start__c, Baseline_Finish__c,
                   Float_Days__c, Critical_Path__c
            FROM WBS_Item__c
            WHERE Project__c = :projectId
        ];

        List<WBS_Item__c> updates = new List<WBS_Item__c>();
        for (WBS_Item__c w : items) {
            if (hasChildren.contains(w.Id)) {
                // Summaries: clear leaf-level risk fields.
                updates.add(new WBS_Item__c(Id = w.Id, Delay_Risk_Score__c = 0,
                    Delay_Likelihood__c = 'Low', Likely_To_Delay_Project__c = false));
                continue;
            }

            Decimal pct = w.Percent_Complete__c != null ? w.Percent_Complete__c : 0;
            Decimal elapsed = elapsedPct(w.Baseline_Start__c, w.Baseline_Finish__c, today);
            Decimal behind = elapsed - pct;                 // positive => behind schedule
            Decimal floatDays = w.Float_Days__c;            // may be null

            Decimal score = 0;
            if (behind > 0) score += behind * 0.7;
            if (floatDays != null && floatDays <= 10) score += (10 - Math.max(floatDays, -20)) * 2;
            if (w.Critical_Path__c == true && behind > 0) score += 20;
            // Not started but past planned start.
            if (pct == 0 && w.Baseline_Start__c != null && today > w.Baseline_Start__c) score += 25;
            if (score < 0) score = 0;
            if (score > 100) score = 100;

            String band = score >= 75 ? 'Critical' : score >= 50 ? 'High' : score >= 25 ? 'Medium' : 'Low';
            Boolean likelyToDelayProject =
                ((floatDays != null && floatDays <= 0) || w.Critical_Path__c == true) && behind > 0;

            updates.add(new WBS_Item__c(
                Id = w.Id,
                Delay_Risk_Score__c = score.setScale(0),
                Delay_Likelihood__c = band,
                Likely_To_Delay_Project__c = likelyToDelayProject,
                AI_Insight__c = buildNarrative(pct, elapsed, behind, floatDays, w.Critical_Path__c == true, band)
            ));
        }

        if (!updates.isEmpty()) {
            TriggerHelper.isRunning = true;   // pure analytics write; don't re-run CPM
            update updates;
            TriggerHelper.isRunning = false;
        }
    }

    private static Decimal elapsedPct(Date startD, Date finishD, Date today) {
        if (startD == null || finishD == null) return 0;
        if (today <= startD) return 0;
        if (today >= finishD) return 100;
        Integer total = startD.daysBetween(finishD);
        if (total <= 0) return 100;
        Integer done = startD.daysBetween(today);
        return ((Decimal) done / total * 100).setScale(2);
    }

    private static String buildNarrative(Decimal pct, Decimal elapsed, Decimal behind,
                                         Decimal floatDays, Boolean critical, String band) {
        List<String> parts = new List<String>();
        parts.add(band + ' delay risk.');
        parts.add('Progress ' + pct.setScale(0) + '% vs ' + elapsed.setScale(0) + '% of schedule elapsed.');
        if (behind > 0) parts.add('Running ~' + behind.setScale(0) + ' points behind plan.');
        if (floatDays != null) parts.add('Total float ' + floatDays.setScale(0) + ' day(s).');
        if (critical) parts.add('On the critical path.');
        return String.join(parts, ' ');
    }
}
