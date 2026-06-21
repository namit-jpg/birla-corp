public without sharing class DailyProgressTriggerHandler {

    public static void handle(
        List<Daily_Progress__c> newList,
        List<Daily_Progress__c> oldList,
        System.TriggerOperation op
    ) {
        Set<Id> wpIds = new Set<Id>();
        // WBS items that DPRs are logged against directly (no Work Package).
        Set<Id> directWbsIds = new Set<Id>();

        List<Daily_Progress__c> scope = (op == System.TriggerOperation.AFTER_DELETE) ? oldList : newList;
        for (Daily_Progress__c dp : scope) {
            if (dp.Work_Package__c != null) wpIds.add(dp.Work_Package__c);
            else if (dp.WBS_Item__c != null) directWbsIds.add(dp.WBS_Item__c);
        }
        if (op == System.TriggerOperation.AFTER_UPDATE) {
            for (Daily_Progress__c dp : oldList) {
                if (dp.Work_Package__c != null) wpIds.add(dp.Work_Package__c);
                else if (dp.WBS_Item__c != null) directWbsIds.add(dp.WBS_Item__c);
            }
        }

        if (!wpIds.isEmpty()) rollupToWorkPackages(wpIds);
        if (!directWbsIds.isEmpty()) rollupDirectWbs(directWbsIds);
    }

    /**
     * DPRs logged directly against a WBS leaf (no Work Package). Progress is the
     * latest Percent_Complete_Day if provided, otherwise cumulative
     * Qty_Installed / WBS Planned_Quantity. Updating the WBS item fires
     * WBS_ItemTrigger -> CPMEngine for hierarchy/project rollup + actual dates.
     */
    private static void rollupDirectWbs(Set<Id> wbsIds) {
        Map<Id, Decimal> qtyByWbs = new Map<Id, Decimal>();
        Map<Id, Decimal> latestPctByWbs = new Map<Id, Decimal>();
        for (AggregateResult ar : [
            SELECT WBS_Item__c wid, SUM(Qty_Installed__c) qty, MAX(Percent_Complete_Day__c) pct
            FROM Daily_Progress__c
            WHERE WBS_Item__c IN :wbsIds AND Work_Package__c = null
            GROUP BY WBS_Item__c
        ]) {
            Id wid = (Id) ar.get('wid');
            qtyByWbs.put(wid, (Decimal) ar.get('qty'));
            if (ar.get('pct') != null) latestPctByWbs.put(wid, (Decimal) ar.get('pct'));
        }

        List<WBS_Item__c> updates = new List<WBS_Item__c>();
        for (WBS_Item__c w : [
            SELECT Id, Planned_Quantity__c, BAC__c FROM WBS_Item__c WHERE Id IN :wbsIds
        ]) {
            Decimal pct;
            if (latestPctByWbs.containsKey(w.Id)) {
                pct = latestPctByWbs.get(w.Id);
            } else if (w.Planned_Quantity__c != null && w.Planned_Quantity__c > 0) {
                Decimal installed = qtyByWbs.containsKey(w.Id) ? qtyByWbs.get(w.Id) : 0;
                pct = (installed / w.Planned_Quantity__c * 100).setScale(2);
            } else {
                continue;
            }
            if (pct > 100) pct = 100;
            Decimal ev = (w.BAC__c != null) ? (w.BAC__c * pct / 100).setScale(2) : 0;
            updates.add(new WBS_Item__c(Id = w.Id, Percent_Complete__c = pct, EV__c = ev));
        }
        if (!updates.isEmpty()) update updates;
    }

    private static void rollupToWorkPackages(Set<Id> wpIds) {
        // Sum qty installed per work package across all daily progress records
        Map<Id, Decimal> qtyByWp = new Map<Id, Decimal>();
        for (Id wid : wpIds) qtyByWp.put(wid, 0);

        for (AggregateResult ar : [
            SELECT Work_Package__c wpId, SUM(Qty_Installed__c) total
            FROM Daily_Progress__c
            WHERE Work_Package__c IN :wpIds
            GROUP BY Work_Package__c
        ]) {
            qtyByWp.put((Id) ar.get('wpId'), (Decimal) ar.get('total'));
        }

        // Fetch work packages to compute percent complete and EV
        List<Work_Package__c> wpsToUpdate = new List<Work_Package__c>();
        Set<Id> wbsIdsToRollup = new Set<Id>();

        for (Work_Package__c wp : [
            SELECT Id, Planned_Qty__c, Budget__c, WBS_Item__c
            FROM Work_Package__c
            WHERE Id IN :wpIds
        ]) {
            Decimal totalInstalled = qtyByWp.get(wp.Id);
            Decimal pct = 0;
            if (wp.Planned_Qty__c != null && wp.Planned_Qty__c > 0) {
                pct = (totalInstalled / wp.Planned_Qty__c * 100).setScale(2);
                if (pct > 100) pct = 100;
            }
            // EV = BAC * %complete / 100
            Decimal ev = (wp.Budget__c != null) ? (wp.Budget__c * pct / 100).setScale(2) : 0;

            wpsToUpdate.add(new Work_Package__c(
                Id = wp.Id,
                Percent_Complete__c = pct,
                Actual_Cost__c = ev
            ));

            if (wp.WBS_Item__c != null) wbsIdsToRollup.add(wp.WBS_Item__c);
        }

        if (!wpsToUpdate.isEmpty()) {
            update wpsToUpdate;
        }

        if (!wbsIdsToRollup.isEmpty()) {
            rollupToWBS(wbsIdsToRollup);
        }
    }

    private static void rollupToWBS(Set<Id> wbsIds) {
        // Aggregate EV from work packages on these WBS items
        Map<Id, Decimal> evByWbs = new Map<Id, Decimal>();
        Map<Id, Decimal> pctByWbs = new Map<Id, Decimal>();
        Map<Id, Decimal> bacByWbs = new Map<Id, Decimal>();

        for (AggregateResult ar : [
            SELECT WBS_Item__c wbsId,
                   SUM(Actual_Cost__c) totalEV,
                   SUM(Budget__c) totalBAC
            FROM Work_Package__c
            WHERE WBS_Item__c IN :wbsIds
            GROUP BY WBS_Item__c
        ]) {
            Id wid = (Id) ar.get('wbsId');
            Decimal totalEV  = (Decimal) ar.get('totalEV');
            Decimal totalBAC = (Decimal) ar.get('totalBAC');
            evByWbs.put(wid, totalEV != null ? totalEV : 0);
            bacByWbs.put(wid, totalBAC != null ? totalBAC : 0);
        }

        List<WBS_Item__c> wbsToUpdate = new List<WBS_Item__c>();
        for (Id wid : wbsIds) {
            Decimal ev  = evByWbs.containsKey(wid) ? evByWbs.get(wid) : 0;
            Decimal bac = bacByWbs.containsKey(wid) ? bacByWbs.get(wid) : 0;
            Decimal pct = (bac > 0) ? (ev / bac * 100).setScale(2) : 0;
            if (pct > 100) pct = 100;

            wbsToUpdate.add(new WBS_Item__c(
                Id = wid,
                EV__c = ev,
                Percent_Complete__c = pct
            ));
        }

        if (!wbsToUpdate.isEmpty()) {
            update wbsToUpdate;
        }
    }
}