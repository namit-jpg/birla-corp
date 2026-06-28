/**
 * Receives parsed rows from the wbsTemplateImporter LWC and creates
 * a WBS_Template__c with its WBS_Template_Item__c children.
 *
 * Expected row shape (JSON array):
 *   [{ code, name, duration, budgetPct, controlAccount, discipline }, ...]
 *
 * Hierarchy is derived from the Code column:
 *   "1.2.3" → parent is "1.2", grandparent is "1".
 */
public with sharing class WBSTemplateImportService {

    public class ImportRequest {
        @AuraEnabled public String templateName;
        @AuraEnabled public String industry;
        @AuraEnabled public String projectType;
        @AuraEnabled public String description;
        @AuraEnabled public String rowsJson;
    }

    @AuraEnabled
    public static Id importTemplate(ImportRequest req) {
        if (req == null || String.isBlank(req.templateName)) {
            throw new AuraHandledException('Template name is required.');
        }
        if (String.isBlank(req.rowsJson)) {
            throw new AuraHandledException('No rows provided.');
        }

        List<Object> rawRows = (List<Object>) JSON.deserializeUntyped(req.rowsJson);
        if (rawRows.isEmpty()) {
            throw new AuraHandledException('The uploaded file contains no data rows.');
        }

        // ── 1. Create the template header ───────────────────────────────────
        WBS_Template__c tmpl = new WBS_Template__c(
            Name             = req.templateName,
            Industry__c      = req.industry,
            Project_Type__c  = req.projectType,
            Description__c   = req.description,
            Is_Active__c     = true
        );
        insert tmpl;

        // ── 2. First pass: create all items without parent links ─────────────
        Map<String, WBS_Template_Item__c> byCode = new Map<String, WBS_Template_Item__c>();
        List<WBS_Template_Item__c> toInsert      = new List<WBS_Template_Item__c>();
        Integer seq = 0;

        for (Object rawRow : rawRows) {
            Map<String, Object> row = (Map<String, Object>) rawRow;
            String code = strVal(row, 'code');
            String name = strVal(row, 'name');
            if (String.isBlank(code) || String.isBlank(name)) continue;

            String caRaw = strVal(row, 'controlAccount');
            Boolean isCA = caRaw != null && new Set<String>{'yes','y','true','1','x'}.contains(caRaw.toLowerCase());
            WBS_Template_Item__c item = new WBS_Template_Item__c(
                WBS_Template__c          = tmpl.Id,
                Name                     = name,
                Code__c                  = code,
                Level__c                 = (Decimal) code.split('\\.').size(),
                Sequence__c              = seq++,
                Typical_Duration_Days__c = decVal(row, 'duration'),
                Budget_Percentage__c     = decVal(row, 'budgetPct'),
                Control_Account__c       = isCA,
                Discipline__c            = strVal(row, 'discipline')
            );
            byCode.put(code, item);
            toInsert.add(item);
        }

        if (toInsert.isEmpty()) {
            throw new AuraHandledException('No valid rows found. Ensure Code and Name columns are filled.');
        }
        insert toInsert;

        // ── 3. Second pass: wire up Parent_Template_Item__c ─────────────────
        List<WBS_Template_Item__c> toUpdate = new List<WBS_Template_Item__c>();
        for (WBS_Template_Item__c item : toInsert) {
            String parentCode = parentCodeOf(item.Code__c);
            if (parentCode != null && byCode.containsKey(parentCode)) {
                toUpdate.add(new WBS_Template_Item__c(
                    Id = item.Id,
                    Parent_Template_Item__c = byCode.get(parentCode).Id
                ));
            }
        }
        if (!toUpdate.isEmpty()) update toUpdate;

        return tmpl.Id;
    }

    // ── helpers ────────────────────────────────────────────────────────────────

    private static String parentCodeOf(String code) {
        if (String.isBlank(code)) return null;
        Integer lastDot = code.lastIndexOf('.');
        return lastDot > 0 ? code.substring(0, lastDot) : null;
    }

    private static String strVal(Map<String, Object> row, String key) {
        Object val = row.get(key);
        if (val == null) return null;
        String s = String.valueOf(val).trim();
        return s.length() == 0 ? null : s;
    }

    private static Decimal decVal(Map<String, Object> row, String key) {
        Object val = row.get(key);
        if (val == null) return null;
        try { return Decimal.valueOf(String.valueOf(val).trim()); }
        catch (Exception e) { return null; }
    }
}
