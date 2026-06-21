public with sharing class QualityHubController {

    private static Id resolveProject(Id projectId) {
        if (projectId != null) return projectId;
        Project__c p = [SELECT Id FROM Project__c ORDER BY LastModifiedDate DESC LIMIT 1];
        return p?.Id;
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getQualityHubData(Id projectId) {
        Id pid = resolveProject(projectId);
        Map<String, Object> result = new Map<String, Object>();

        result.put('itps', [
            SELECT Id, Name, Discipline__c, Status__c, Hold_Witness_Points__c
            FROM Inspection_Test_Plan__c
            WHERE Project__c = :pid
            ORDER BY CreatedDate DESC
            LIMIT 200
        ]);

        result.put('inspections', [
            SELECT Id, Name, Type__c, Status__c, Requested_Date__c, Inspected_Date__c,
                   Area__c, ITP__r.Name, Inspector__r.Name
            FROM Inspection_Request__c
            WHERE Project__c = :pid
            ORDER BY Requested_Date__c DESC
            LIMIT 200
        ]);

        result.put('ncrs', [
            SELECT Id, Name, Status__c, Severity__c, Category__c,
                   Identified_Date__c, Closed_Date__c, RCA_Method__c
            FROM NCR__c
            WHERE Project__c = :pid
            ORDER BY Identified_Date__c DESC
            LIMIT 200
        ]);

        result.put('capas', [
            SELECT Id, Name, Type__c, Status__c, Due_Date__c,
                   NCR__r.Name, Owner__r.Name
            FROM CAPA__c
            WHERE NCR__r.Project__c = :pid
            ORDER BY Due_Date__c ASC
            LIMIT 200
        ]);

        return result;
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getQualityKPIs(Id projectId) {
        Id pid = resolveProject(projectId);
        Map<String, Object> kpis = new Map<String, Object>();

        Integer totalInspections  = [SELECT COUNT() FROM Inspection_Request__c WHERE Project__c = :pid];
        Integer passedInspections = [SELECT COUNT() FROM Inspection_Request__c WHERE Project__c = :pid AND Status__c = 'Passed'];
        Integer failedInspections = [SELECT COUNT() FROM Inspection_Request__c WHERE Project__c = :pid AND Status__c = 'Failed'];
        Integer openNCRs          = [SELECT COUNT() FROM NCR__c WHERE Project__c = :pid AND Status__c != 'Closed'];
        Integer openCAPAs         = [SELECT COUNT() FROM CAPA__c WHERE NCR__r.Project__c = :pid AND Status__c NOT IN ('Verified', 'Closed')];
        Integer expiredCalibrations = [SELECT COUNT() FROM Calibration_Record__c WHERE Status__c = 'Expired'];

        kpis.put('totalInspections', totalInspections);
        kpis.put('passedInspections', passedInspections);
        kpis.put('failedInspections', failedInspections);
        kpis.put('inspectionPassRate', totalInspections > 0 ? (Decimal.valueOf(passedInspections) / totalInspections * 100).setScale(1) : 0);
        kpis.put('openNCRs', openNCRs);
        kpis.put('openCAPAs', openCAPAs);
        kpis.put('expiredCalibrations', expiredCalibrations);

        return kpis;
    }

    @AuraEnabled(cacheable=true)
    public static List<Calibration_Record__c> getCalibrationAlerts() {
        return [
            SELECT Id, Name, Instrument__c, Serial_No__c, Due_Date__c, Status__c
            FROM Calibration_Record__c
            WHERE Status__c IN ('Due', 'Expired')
            ORDER BY Due_Date__c ASC
            LIMIT 50
        ];
    }
}
