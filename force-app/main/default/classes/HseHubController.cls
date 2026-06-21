public with sharing class HseHubController {

    private static Id resolveProject(Id projectId) {
        if (projectId != null) return projectId;
        Project__c p = [SELECT Id FROM Project__c ORDER BY LastModifiedDate DESC LIMIT 1];
        return p?.Id;
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getHseHubData(Id projectId) {
        Id pid = resolveProject(projectId);
        Map<String, Object> result = new Map<String, Object>();

        result.put('permits', [
            SELECT Id, Name, Permit_Type__c, Status__c, Valid_From__c, Valid_To__c, Area__c, Issued_By__c
            FROM Permit_to_Work__c
            WHERE Project__c = :pid
            ORDER BY Valid_From__c DESC
            LIMIT 200
        ]);

        result.put('observations', [
            SELECT Id, Name, Observation_Type__c, Risk_Level__c, Status__c, Observation_Date__c, Observed_By__c
            FROM Observation__c
            WHERE Project__c = :pid
            ORDER BY Observation_Date__c DESC
            LIMIT 200
        ]);

        result.put('incidents', [
            SELECT Id, Name, Incident_Type__c, Severity__c, Is_Near_Miss__c, Status__c, Incident_Date__c
            FROM Incident__c
            WHERE Project__c = :pid
            ORDER BY Incident_Date__c DESC
            LIMIT 200
        ]);

        result.put('toolboxTalks', [
            SELECT Id, Name, Topic__c, Talk_Date__c, Conducted_By__c, Attendance_Count__c
            FROM Toolbox_Talk__c
            WHERE Project__c = :pid
            ORDER BY Talk_Date__c DESC
            LIMIT 100
        ]);

        result.put('hiras', [
            SELECT Id, Name, Activity__c, Hazard__c, Risk_Rating__c, Residual_Risk__c, Status__c
            FROM HIRA__c
            WHERE Project__c = :pid
            ORDER BY LastModifiedDate DESC
            LIMIT 200
        ]);

        result.put('safetyAudits', [
            SELECT Id, Name, Audit_Date__c, Auditor__c, Score__c, Status__c, Findings__c
            FROM Safety_Audit__c
            WHERE Project__c = :pid
            ORDER BY Audit_Date__c DESC
            LIMIT 200
        ]);

        result.put('auditFindings', [
            SELECT Id, Name, Category__c, Severity__c, Finding_Status__c, Closed_Date__c,
                   Safety_Audit__c, Safety_Audit__r.Name
            FROM Audit_Finding__c
            WHERE Safety_Audit__r.Project__c = :pid
            ORDER BY Closed_Date__c DESC NULLS FIRST
            LIMIT 200
        ]);

        result.put('emergencyPlans', [
            SELECT Id, Name, Scenario__c, Plan_Status__c, Drill_Date__c, Contacts__c
            FROM Emergency_Plan__c
            WHERE Project__c = :pid
            ORDER BY Drill_Date__c DESC NULLS FIRST
            LIMIT 100
        ]);

        result.put('ohsCompliance', [
            SELECT Id, Name, Requirement__c, Compliance_Status__c, Evidence_URL__c
            FROM OHS_Compliance_Item__c
            WHERE Project__c = :pid
            ORDER BY Name
            LIMIT 200
        ]);

        return result;
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getHseKPIs(Id projectId) {
        Id pid = resolveProject(projectId);
        Map<String, Object> kpis = new Map<String, Object>();

        kpis.put('activePermits', [
            SELECT COUNT() FROM Permit_to_Work__c
            WHERE Project__c = :pid AND Status__c = 'Active'
        ]);
        kpis.put('openHighObservations', [
            SELECT COUNT() FROM Observation__c
            WHERE Project__c = :pid AND Risk_Level__c = 'High' AND Status__c = 'Open'
        ]);
        kpis.put('openIncidents', [
            SELECT COUNT() FROM Incident__c
            WHERE Project__c = :pid AND Status__c != 'Closed'
        ]);
        kpis.put('nearMisses', [
            SELECT COUNT() FROM Incident__c
            WHERE Project__c = :pid AND Is_Near_Miss__c = true
        ]);
        List<AggregateResult> tbtAgg = [
            SELECT SUM(Attendance_Count__c) totalAtt FROM Toolbox_Talk__c
            WHERE Project__c = :pid
        ];
        Decimal tbtAttendees = tbtAgg.isEmpty() || tbtAgg[0].get('totalAtt') == null
            ? 0 : (Decimal) tbtAgg[0].get('totalAtt');
        kpis.put('totalTbtAttendees', tbtAttendees);

        return kpis;
    }

    @AuraEnabled
    public static void closePermit(Id permitId) {
        if (permitId == null) throw new AuraHandledException('Permit Id required.');
        update new Permit_to_Work__c(Id = permitId, Status__c = 'Closed');
    }

    @AuraEnabled(cacheable=true)
    public static List<Permit_to_Work__c> getExpiringPermits(Id projectId) {
        Id pid = resolveProject(projectId);
        DateTime nowPlus48 = System.now().addHours(48);
        return [
            SELECT Id, Name, Permit_Type__c, Valid_To__c, Area__c, Status__c
            FROM Permit_to_Work__c
            WHERE Project__c = :pid
              AND Status__c = 'Active'
              AND Valid_To__c <= :nowPlus48
            ORDER BY Valid_To__c ASC
            LIMIT 50
        ];
    }
}
