public with sharing class HandoverController {

    private static Id resolveProject(Id projectId) {
        if (projectId != null) return projectId;
        List<Project__c> projs = [SELECT Id FROM Project__c ORDER BY LastModifiedDate DESC LIMIT 1];
        return projs.isEmpty() ? null : projs[0].Id;
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getHandoverData(Id projectId) {
        projectId = resolveProject(projectId);
        Map<String, Object> result = new Map<String, Object>();

        result.put('packages', [
            SELECT Id, Name, Package_Code__c, Package_Status__c, Scope__c,
                   OM_Manual_URL__c, Client_Acceptance_Date__c
            FROM Handover_Package__c
            WHERE Project__c = :projectId
            ORDER BY Name ASC
            LIMIT 200
        ]);

        result.put('punchItems', [
            SELECT Id, Name, Description__c, Category__c, Priority__c,
                   Punch_Status__c, Assigned_To__c, Due_Date__c,
                   Handover_Package__c, WBS_Item__c, Work_Package__c
            FROM Punch_List_Item__c
            WHERE Project__c = :projectId
            ORDER BY Category__c ASC, Due_Date__c ASC NULLS LAST
            LIMIT 500
        ]);

        result.put('completions', [
            SELECT Id, Name, System__c, Stage__c, Completion_Status__c,
                   Target_Date__c, Actual_Date__c, Signed_Off_By__c, WBS_Item__c
            FROM Completion__c
            WHERE Project__c = :projectId
            ORDER BY Stage__c ASC, System__c ASC
            LIMIT 200
        ]);

        result.put('trainingRecords', [
            SELECT Id, Name, Topic__c, Trainee__c, Training_Date__c,
                   Training_Status__c, Competency_Verified__c
            FROM Training_Record__c
            WHERE Project__c = :projectId
            ORDER BY Training_Date__c DESC
            LIMIT 100
        ]);

        return result;
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getHandoverKPIs(Id projectId) {
        projectId = resolveProject(projectId);
        Map<String, Object> kpis = new Map<String, Object>();

        kpis.put('openCatA', [
            SELECT COUNT() FROM Punch_List_Item__c
            WHERE Project__c = :projectId AND Category__c = 'A' AND Punch_Status__c != 'Closed'
        ]);
        kpis.put('openCatB', [
            SELECT COUNT() FROM Punch_List_Item__c
            WHERE Project__c = :projectId AND Category__c = 'B' AND Punch_Status__c != 'Closed'
        ]);
        kpis.put('totalPunch', [
            SELECT COUNT() FROM Punch_List_Item__c
            WHERE Project__c = :projectId
        ]);
        kpis.put('closedPunch', [
            SELECT COUNT() FROM Punch_List_Item__c
            WHERE Project__c = :projectId AND Punch_Status__c = 'Closed'
        ]);
        kpis.put('completionsSignedOff', [
            SELECT COUNT() FROM Completion__c
            WHERE Project__c = :projectId AND Completion_Status__c = 'Signed Off'
        ]);
        kpis.put('packagesReadyOrAccepted', [
            SELECT COUNT() FROM Handover_Package__c
            WHERE Project__c = :projectId
              AND (Package_Status__c = 'Ready for Client' OR Package_Status__c = 'Accepted')
        ]);

        return kpis;
    }

    @AuraEnabled(cacheable=true)
    public static List<Commissioning_Procedure__c> getCommissioningProcedures(Id projectId) {
        projectId = resolveProject(projectId);
        return [
            SELECT Id, Name, Proc_System__c, Proc_Status__c, Steps_Total__c,
                   Steps_Complete__c, Procedure_Doc_URL__c
            FROM Commissioning_Procedure__c
            WHERE Project__c = :projectId
            ORDER BY Proc_System__c ASC
            LIMIT 100
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<Final_Acceptance__c> getFinalAcceptances(Id projectId) {
        projectId = resolveProject(projectId);
        return [
            SELECT Id, Name, FAC_Status__c, Accepted_By__c, Accepted_Date__c,
                   Certificate_URL__c, Handover_Package__c
            FROM Final_Acceptance__c
            WHERE Project__c = :projectId
            ORDER BY Name ASC
            LIMIT 50
        ];
    }
}