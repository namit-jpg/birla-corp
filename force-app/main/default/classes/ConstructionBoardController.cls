public without sharing class ConstructionBoardController {

    public class BoardData {
        @AuraEnabled public List<NCR__c> ncrs;
        @AuraEnabled public List<Work_Front__c> workFronts;
        @AuraEnabled public List<Daily_Progress__c> recentProgress;
    }

    @AuraEnabled(cacheable=true)
    public static Id getDefaultProjectId() {
        Project__c p = [SELECT Id FROM Project__c ORDER BY LastModifiedDate DESC LIMIT 1];
        return p?.Id;
    }

    @AuraEnabled(cacheable=true)
    public static List<Equipment__c> getEquipmentForProject(Id projectId) {
        Id pid = projectId != null ? projectId : getDefaultProjectId();
        return [
            SELECT Id, Name, Type__c, Status__c, Utilization_Hours__c,
                   LastModifiedDate
            FROM Equipment__c
            WHERE Project__c = :pid
            ORDER BY Name
            LIMIT 200
        ];
    }

    public class KanbanContext {
        @AuraEnabled public Id projectId;
        @AuraEnabled public String projectName;
        @AuraEnabled public List<Work_Package__c> workPackages;
    }

    @AuraEnabled(cacheable=true)
    public static KanbanContext getKanbanContext(Id projectId) {
        Id pid = resolveProject(projectId);
        KanbanContext ctx = new KanbanContext();
        ctx.projectId = pid;
        if (pid != null) {
            List<Project__c> projects = [SELECT Name FROM Project__c WHERE Id = :pid LIMIT 1];
            ctx.projectName = projects.isEmpty() ? null : projects[0].Name;
        }
        ctx.workPackages = getWorkPackagesForProject(pid);
        return ctx;
    }

    private static Id resolveProject(Id projectId) {
        return projectId != null ? projectId : getDefaultProjectId();
    }

    private static List<Work_Package__c> getWorkPackagesForProject(Id projectId) {
        if (projectId == null) {
            return new List<Work_Package__c>();
        }
        return [
            SELECT Id, Name, Status__c, Discipline__c, Percent_Complete__c, Budget__c,
                   Planned_Qty__c, Unit__c, Start_Date__c, End_Date__c,
                   WBS_Item__c, WBS_Item__r.Code__c
            FROM Work_Package__c
            WHERE Project__c = :projectId
            ORDER BY Status__c, Name
            LIMIT 500
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<Work_Package__c> getWorkPackagesForKanban(Id projectId) {
        return getWorkPackagesForProject(resolveProject(projectId));
    }

    @AuraEnabled
    public static void updateWorkPackageStatus(Id workPackageId, String newStatus) {
        if (workPackageId == null || String.isBlank(newStatus)) {
            throw new AuraHandledException('Work package and status are required.');
        }
        update new Work_Package__c(Id = workPackageId, Status__c = newStatus);
    }

    @AuraEnabled(cacheable=true)
    public static BoardData getConstructionBoardData(Id projectId) {
        Id pid = projectId != null ? projectId : getDefaultProjectId();
        BoardData data = new BoardData();

        data.ncrs = [
            SELECT Id, Name, Status__c, Severity__c, Category__c,
                   Identified_Date__c, Closed_Date__c, Vendor__c, Vendor__r.Name,
                   Root_Cause__c, Corrective_Action__c
            FROM NCR__c
            WHERE Project__c = :pid
            ORDER BY Identified_Date__c DESC
            LIMIT 200
        ];

        data.workFronts = [
            SELECT Id, Name, Readiness_Status__c, Released_Date__c, Blockers__c,
                   Work_Package__c, Work_Package__r.Name
            FROM Work_Front__c
            WHERE Project__c = :pid
            ORDER BY Name
            LIMIT 100
        ];

        data.recentProgress = [
            SELECT Id, Name, Date__c, Qty_Installed__c, Planned_Quantity__c,
                   Hours_Worked__c, Productivity__c, Safety_Incidents__c, Quality_Issues__c, Weather__c,
                   Work_Package__c, Work_Package__r.Name
            FROM Daily_Progress__c
            WHERE Project__c = :pid
            ORDER BY Date__c DESC
            LIMIT 50
        ];

        return data;
    }
}
