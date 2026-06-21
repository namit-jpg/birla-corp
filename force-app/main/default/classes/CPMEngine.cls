/**
 * Critical Path Method engine, modelled on Microsoft Project (desktop) scheduling.
 * Ported from the Glatt org and adapted to the birla-corp WBS_Item__c schema.
 *
 * Field mapping vs. the original Glatt model:
 *   WBS_Code__c        -> Code__c
 *   Duration_Days__c   -> Duration__c
 *   Parent_WBS_Item__c -> Parent_WBS__c
 *   Budget__c          -> BAC__c
 *   Progress__c        -> Percent_Complete__c
 *   Is_Critical__c     -> Critical_Path__c
 *   Project Overall_Progress__c -> Percent_Complete__c
 * Dependencies come solely from the WBS_Dependency__c junction (the birla
 * Predecessor__c field is free text and is NOT used for scheduling).
 * In addition to the Early and Late dates the engine mirrors the live (early) schedule
 * into Current_Start__c / Current_Finish__c so the existing Gantt / schedule
 * variance components and the Schedule_Variance_Days__c / Is_Delayed__c
 * formulas keep working off the recalculated plan.
 *
 * Conventions (matching MS Project / standard PDM CPM):
 *  - All scheduling math runs in WORKING-DAY ORDINAL space (integers). Ordinal 0
 *    is the project start rolled forward to a working day; weekends are skipped.
 *  - EF = ES + Duration - 1 (start = beginning of day, finish = end of day).
 *  - Early Start = MAX over predecessor constraints; Late Finish = MIN over
 *    successor constraints. Total Slack = LF - EF; a leaf is critical when <= 0.
 *  - Summary (parent) tasks are pure rollups and are never flagged critical.
 */
public with sharing class CPMEngine {

    private class Link {
        Id predId;
        Id succId;
        String type;
        Integer lag;
        Link(Id predId, Id succId, String type, Integer lag) {
            this.predId = predId; this.succId = succId;
            this.type = (type != null ? type : 'FS');
            this.lag = (lag != null ? lag : 0);
        }
    }

    public static void recalculate(Id projectId) {
        if (projectId == null) return;
        Project__c proj = [SELECT Id, Start_Date__c FROM Project__c WHERE Id = :projectId LIMIT 1];
        Date projectStartRaw = proj.Start_Date__c != null ? proj.Start_Date__c : Date.today();
        Date origin = rollForward(projectStartRaw); // ordinal 0 = first working day

        List<WBS_Item__c> items = [
            SELECT Id, Name, Code__c, Duration__c, Parent_WBS__c,
                   BAC__c, Percent_Complete__c, Actual_Start__c, Actual_Finish__c
            FROM WBS_Item__c
            WHERE Project__c = :projectId
            ORDER BY Code__c ASC NULLS LAST
        ];
        if (items.isEmpty()) return;

        Map<Id, WBS_Item__c> itemMap = new Map<Id, WBS_Item__c>(items);

        // -- Which items are summaries (have children)? ----------------
        Set<Id> hasChildren = new Set<Id>();
        Map<Id, List<Id>> childMap = new Map<Id, List<Id>>();
        for (WBS_Item__c it : items) childMap.put(it.Id, new List<Id>());
        for (WBS_Item__c it : items) {
            if (it.Parent_WBS__c != null && itemMap.containsKey(it.Parent_WBS__c)) {
                hasChildren.add(it.Parent_WBS__c);
                childMap.get(it.Parent_WBS__c).add(it.Id);
            }
        }

        // -- Collect dependency links (junction only) ------------------
        List<Link> links = buildLinks(projectId, itemMap);

        Map<Id, List<Link>> predLinks = new Map<Id, List<Link>>();
        Map<Id, List<Link>> succLinks = new Map<Id, List<Link>>();
        for (Id id : itemMap.keySet()) {
            predLinks.put(id, new List<Link>());
            succLinks.put(id, new List<Link>());
        }
        for (Link l : links) {
            predLinks.get(l.succId).add(l);
            succLinks.get(l.predId).add(l);
        }

        // -- Topological order over the dependency graph ---------------
        List<Id> sorted = topoSort(itemMap, links);

        // -- Forward pass (working-day ordinals) -----------------------
        Map<Id, Integer> es = new Map<Id, Integer>();
        Map<Id, Integer> ef = new Map<Id, Integer>();
        for (Id id : sorted) {
            Integer dur = dur(itemMap.get(id));
            Integer start = 0;
            for (Link l : predLinks.get(id)) {
                if (!ef.containsKey(l.predId)) continue;
                Integer pEF = ef.get(l.predId);
                Integer pES = es.get(l.predId);
                Integer cand;
                if (l.type == 'SS') {
                    cand = pES + l.lag;
                } else if (l.type == 'FF') {
                    cand = (pEF + l.lag) - dur + 1;
                } else if (l.type == 'SF') {
                    cand = (pES + l.lag) - dur;
                } else { // FS
                    cand = pEF + l.lag + 1;
                }
                if (cand > start) start = cand;
            }
            es.put(id, start);
            ef.put(id, start + dur - 1);
        }

        // -- Project finish = max Early Finish across leaf tasks --------
        Integer projectEnd = 0;
        for (Id id : ef.keySet()) {
            if (!hasChildren.contains(id) && ef.get(id) > projectEnd) projectEnd = ef.get(id);
        }

        // -- Backward pass ---------------------------------------------
        Map<Id, Integer> ls = new Map<Id, Integer>();
        Map<Id, Integer> lf = new Map<Id, Integer>();
        for (Integer i = sorted.size() - 1; i >= 0; i--) {
            Id id = sorted.get(i);
            Integer dur = dur(itemMap.get(id));
            Integer late = projectEnd;
            for (Link l : succLinks.get(id)) {
                if (!ls.containsKey(l.succId)) continue;
                Integer sLS = ls.get(l.succId);
                Integer sLF = lf.get(l.succId);
                Integer cand;
                if (l.type == 'SS') {
                    cand = (sLS - l.lag) + dur - 1;
                } else if (l.type == 'FF') {
                    cand = sLF - l.lag;
                } else if (l.type == 'SF') {
                    cand = (sLF - l.lag) + dur;
                } else { // FS
                    cand = sLS - l.lag - 1;
                }
                if (cand < late) late = cand;
            }
            lf.put(id, late);
            ls.put(id, late - dur + 1);
        }

        // -- Summary rollup of ordinals (bottom-up, multi-pass) ---------
        for (Integer pass = 0; pass < 20; pass++) {
            Boolean changed = false;
            for (WBS_Item__c it : items) {
                List<Id> kids = childMap.get(it.Id);
                if (kids == null || kids.isEmpty()) continue;
                Integer minES = null, maxEF = null, minLS = null, maxLF = null;
                for (Id k : kids) {
                    minES = (minES == null || es.get(k) < minES) ? es.get(k) : minES;
                    maxEF = (maxEF == null || ef.get(k) > maxEF) ? ef.get(k) : maxEF;
                    minLS = (minLS == null || ls.get(k) < minLS) ? ls.get(k) : minLS;
                    maxLF = (maxLF == null || lf.get(k) > maxLF) ? lf.get(k) : maxLF;
                }
                if (es.get(it.Id) != minES || ef.get(it.Id) != maxEF
                        || ls.get(it.Id) != minLS || lf.get(it.Id) != maxLF) {
                    es.put(it.Id, minES); ef.put(it.Id, maxEF);
                    ls.put(it.Id, minLS); lf.put(it.Id, maxLF);
                    changed = true;
                }
            }
            if (!changed) break;
        }

        // -- Write schedule + float + critical flag ---------------------
        for (WBS_Item__c it : items) {
            Date earlyStartDt  = dateForOrdinal(origin, es.get(it.Id));
            Date earlyFinishDt = dateForOrdinal(origin, ef.get(it.Id));
            it.Early_Start__c  = earlyStartDt;
            it.Early_Finish__c = earlyFinishDt;
            it.Late_Start__c   = dateForOrdinal(origin, ls.get(it.Id));
            it.Late_Finish__c  = dateForOrdinal(origin, lf.get(it.Id));
            // Mirror the live (early) schedule into Current_* so existing
            // Gantt / variance components and formulas track the recalculated plan.
            it.Current_Start__c  = earlyStartDt;
            it.Current_Finish__c = earlyFinishDt;
            Integer slack      = lf.get(it.Id) - ef.get(it.Id);
            it.Float_Days__c   = slack;
            it.Critical_Path__c = !hasChildren.contains(it.Id) && slack <= 0;
        }

        // -- Auto actual dates on leaves (from progress) ----------------
        Date today = Date.today();
        for (WBS_Item__c it : items) {
            if (hasChildren.contains(it.Id)) continue;
            Decimal prog = it.Percent_Complete__c != null ? it.Percent_Complete__c : 0;
            if (prog > 0 && it.Actual_Start__c == null) it.Actual_Start__c = today;
            if (prog >= 100) {
                if (it.Actual_Finish__c == null) it.Actual_Finish__c = today;
            } else if (it.Actual_Finish__c != null) {
                it.Actual_Finish__c = null;
            }
        }

        // -- Budget roll-up (sum children -> parent, leaf -> root) ------
        rollupBudget(items, itemMap, childMap);

        // -- Progress roll-up (budget-weighted, leaf -> root) -----------
        rollupProgress(items, itemMap, childMap);

        // -- Actual-date roll-up to summaries (bottom-up) ---------------
        rollupActuals(items, childMap);

        // -- Persist ---------------------------------------------------
        TriggerHelper.isRunning = true;
        update items;
        TriggerHelper.isRunning = false;

        // -- Project overall progress (budget-weighted over roots) ------
        Set<Id> allIds = itemMap.keySet();
        Decimal totalBudget = 0, weightedProg = 0;
        for (WBS_Item__c it : items) {
            if (it.Parent_WBS__c == null || !allIds.contains(it.Parent_WBS__c)) {
                Decimal b = it.BAC__c != null ? it.BAC__c : 0;
                Decimal p = it.Percent_Complete__c != null ? it.Percent_Complete__c : 0;
                totalBudget += b;
                weightedProg += b * p;
            }
        }
        // Percent_Complete__c on Project__c is a formula roll-up — not writable.
    }

    // -- Build dependency links from the junction ----------------------
    private static List<Link> buildLinks(Id projectId, Map<Id, WBS_Item__c> itemMap) {
        List<Link> links = new List<Link>();
        for (WBS_Dependency__c d : [
                SELECT Successor__c, Predecessor__c, Dependency_Type__c, Lag_Days__c
                FROM WBS_Dependency__c
                WHERE Successor__r.Project__c = :projectId
                  AND Predecessor__c != null AND Successor__c != null
        ]) {
            if (itemMap.containsKey(d.Successor__c) && itemMap.containsKey(d.Predecessor__c)
                    && d.Successor__c != d.Predecessor__c) {
                links.add(new Link(d.Predecessor__c, d.Successor__c, d.Dependency_Type__c,
                                   d.Lag_Days__c != null ? (Integer) d.Lag_Days__c : 0));
            }
        }
        return links;
    }

    // -- Topological sort (Kahn) over predecessor -> successor edges ----
    private static List<Id> topoSort(Map<Id, WBS_Item__c> itemMap, List<Link> links) {
        Map<Id, Integer> inDeg = new Map<Id, Integer>();
        Map<Id, List<Id>> adj  = new Map<Id, List<Id>>();
        for (Id id : itemMap.keySet()) { inDeg.put(id, 0); adj.put(id, new List<Id>()); }
        for (Link l : links) {
            adj.get(l.predId).add(l.succId);
            inDeg.put(l.succId, inDeg.get(l.succId) + 1);
        }

        List<Id> queue = new List<Id>();
        List<Id> result = new List<Id>();
        for (Id id : inDeg.keySet()) if (inDeg.get(id) == 0) queue.add(id);

        Integer idx = 0;
        while (idx < queue.size()) {
            Id curr = queue.get(idx++);
            result.add(curr);
            for (Id next : adj.get(curr)) {
                Integer deg = inDeg.get(next) - 1;
                inDeg.put(next, deg);
                if (deg == 0) queue.add(next);
            }
        }
        // Any items left out are in a cycle - append so they still get scheduled.
        Set<Id> seen = new Set<Id>(result);
        for (Id id : itemMap.keySet()) if (!seen.contains(id)) result.add(id);
        return result;
    }

    // -- Budget roll-up (sum of children, multi-pass until stable) -----
    private static void rollupBudget(List<WBS_Item__c> items, Map<Id, WBS_Item__c> itemMap, Map<Id, List<Id>> childMap) {
        for (Integer pass = 0; pass < 20; pass++) {
            Boolean changed = false;
            for (WBS_Item__c item : items) {
                List<Id> kids = childMap.get(item.Id);
                if (kids == null || kids.isEmpty()) continue;
                Decimal total = 0;
                for (Id kid : kids) {
                    total += itemMap.get(kid).BAC__c != null ? itemMap.get(kid).BAC__c : 0;
                }
                if (item.BAC__c != total) { item.BAC__c = total; changed = true; }
            }
            if (!changed) break;
        }
    }

    // -- Progress roll-up (budget-weighted, multi-pass until stable) ----
    private static void rollupProgress(List<WBS_Item__c> items, Map<Id, WBS_Item__c> itemMap, Map<Id, List<Id>> childMap) {
        for (Integer pass = 0; pass < 20; pass++) {
            Boolean changed = false;
            for (WBS_Item__c item : items) {
                List<Id> kids = childMap.get(item.Id);
                if (kids == null || kids.isEmpty()) continue;
                Decimal totalB = 0, weighted = 0;
                for (Id kid : kids) {
                    Decimal b = itemMap.get(kid).BAC__c != null ? itemMap.get(kid).BAC__c : 0;
                    Decimal p = itemMap.get(kid).Percent_Complete__c != null ? itemMap.get(kid).Percent_Complete__c : 0;
                    totalB   += b;
                    weighted += b * p;
                }
                Decimal newP = totalB > 0
                    ? (weighted / totalB).setScale(2)
                    : avgProgress(kids, itemMap);
                if (item.Percent_Complete__c != newP) { item.Percent_Complete__c = newP; changed = true; }
            }
            if (!changed) break;
        }
    }

    // -- Actual-date roll-up to summaries (bottom-up, multi-pass) -------
    private static void rollupActuals(List<WBS_Item__c> items, Map<Id, List<Id>> childMap) {
        Map<Id, WBS_Item__c> byId = new Map<Id, WBS_Item__c>(items);
        for (Integer pass = 0; pass < 20; pass++) {
            Boolean changed = false;
            for (WBS_Item__c item : items) {
                List<Id> kids = childMap.get(item.Id);
                if (kids == null || kids.isEmpty()) continue;
                Date minStart = null, maxFinish = null;
                Boolean allFinished = true;
                for (Id kid : kids) {
                    WBS_Item__c c = byId.get(kid);
                    if (c.Actual_Start__c != null && (minStart == null || c.Actual_Start__c < minStart)) {
                        minStart = c.Actual_Start__c;
                    }
                    if (c.Actual_Finish__c == null) allFinished = false;
                    else if (maxFinish == null || c.Actual_Finish__c > maxFinish) maxFinish = c.Actual_Finish__c;
                }
                Date newFinish = allFinished ? maxFinish : null;
                if (item.Actual_Start__c != minStart || item.Actual_Finish__c != newFinish) {
                    item.Actual_Start__c  = minStart;
                    item.Actual_Finish__c = newFinish;
                    changed = true;
                }
            }
            if (!changed) break;
        }
    }

    private static Decimal avgProgress(List<Id> kids, Map<Id, WBS_Item__c> itemMap) {
        Decimal s = 0;
        for (Id k : kids) s += itemMap.get(k).Percent_Complete__c != null ? itemMap.get(k).Percent_Complete__c : 0;
        return kids.isEmpty() ? 0 : (s / kids.size()).setScale(2);
    }

    // -- Working-day helpers (Standard calendar: Mon-Fri) --------------
    private static final Date MONDAY_REF = Date.newInstance(2020, 1, 6);

    private static Boolean isWeekend(Date d) {
        Integer dow = Math.mod(MONDAY_REF.daysBetween(d), 7);
        if (dow < 0) dow += 7;
        return dow >= 5;
    }

    private static Date rollForward(Date d) {
        while (isWeekend(d)) d = d.addDays(1);
        return d;
    }

    private static Date dateForOrdinal(Date origin, Integer ord) {
        if (ord == null) return null;
        Date d = origin;
        Integer step = ord >= 0 ? 1 : -1;
        Integer remaining = Math.abs(ord);
        while (remaining > 0) {
            d = d.addDays(step);
            if (!isWeekend(d)) remaining--;
        }
        return d;
    }

    private static Integer dur(WBS_Item__c item) {
        return item.Duration__c != null && item.Duration__c > 0
            ? (Integer) item.Duration__c : 1;
    }
}
