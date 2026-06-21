public with sharing class EPCRFIService {
    
    @AuraEnabled(cacheable=true)
    public static List<RFI__c> getRFIs(Id projectId) {
        try {
            return [
                SELECT Id, Name, Subject__c, Status__c, Priority__c, Submitted_Date__c,
                       CreatedDate, LastModifiedDate, Answer_Rich__c, Due_Date__c,Drawing__c, 
                       Assigned_To__c, Answered_On__c, Assigned_To__r.Name
                FROM RFI__c 
                WHERE Project__c = :projectId 
                WITH SECURITY_ENFORCED
                ORDER BY CreatedDate DESC
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving RFIs: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static RFI__c createRFI(RFI__c rfi) {
        try {
            insert rfi;
            return rfi;
        } catch (Exception e) {
            throw new AuraHandledException('Error creating RFI: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static RFI__c updateRFI(RFI__c rfi) {
        try {
            update rfi;
            return rfi;
        } catch (Exception e) {
            throw new AuraHandledException('Error updating RFI: ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<User> getActiveUsers() {
        return [SELECT Id, Name FROM User WITH SECURITY_ENFORCED ORDER BY Name];
    }

    @AuraEnabled
    public static void updateBulkRfiDetails(List<Id> rfiIds, String newStatus, String newPriority, Id assignedToId) {
        try {
            List<RFI__c> rfisToUpdate = [SELECT Id, Status__c, Priority__c, Assigned_To__c 
                                        FROM RFI__c 
                                        WHERE Id IN :rfiIds];

            for (RFI__c rfi : rfisToUpdate) {
                if (String.isNotBlank(newStatus)) {
                    rfi.Status__c = newStatus;
                }

                if (String.isNotBlank(newPriority) && newPriority != 'All Priorities') {
                    rfi.Priority__c = newPriority;
                }

                if (assignedToId != null) {
                    rfi.Assigned_To__c = assignedToId;
                }
            }

            if (!rfisToUpdate.isEmpty()) {
                update rfisToUpdate;
            }
        } catch (Exception ex) {
            throw new AuraHandledException('Error updating RFIs: ' + ex.getMessage());
        }
    }

    @AuraEnabled
    public static String exportRFIs(List<Id> rfiIds) {
        try {
            List<RFI__c> rfis = [
                SELECT Name, Subject__c, Status__c, Priority__c, Due_Date__c, Assigned_To__r.Name
                FROM RFI__c
                WHERE Id IN :rfiIds
            ];

            if (rfis.isEmpty()) {
                throw new AuraHandledException('No RFIs found to export.');
            }

            String csv = 'RFI Number,Subject,Status,Priority,Due Date,Assigned To\n';

            for (RFI__c rfi : rfis) {
                String dueDate = rfi.Due_Date__c != null ? String.valueOf(rfi.Due_Date__c) : '';
                String assignedTo = rfi.Assigned_To__r != null ? rfi.Assigned_To__r.Name : '';

                csv += String.join(new List<String>{
                    '"' + rfi.Name + '"',
                    '"' + (rfi.Subject__c != null ? rfi.Subject__c.escapeCsv() : '') + '"',
                    '"' + (rfi.Status__c != null ? rfi.Status__c.escapeCsv() : '') + '"',
                    '"' + (rfi.Priority__c != null ? rfi.Priority__c.escapeCsv() : '') + '"',
                    '"' + dueDate + '"',
                    '"' + assignedTo.escapeCsv() + '"'
                }, ',') + '\n';
            }

            return csv;

        } catch (Exception e) {
            System.debug('Export RFIs Error: ' + e.getMessage() + '\n' + e.getStackTraceString());
            throw new AuraHandledException('Export failed: ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
public static List<RFI_Template__mdt> getRFITemplates() {
    return [
        SELECT Id, MasterLabel, DeveloperName, Category__c, 
               Subject_Template__c, Question_Template__c, 
               Priority__c, SLA_Hours__c, Discipline__c, 
               Work_Type__c, Is_Active__c, Sort_Order__c, 
               Instructions__c, Auto_Assign_To__c
        FROM RFI_Template__mdt
        WHERE Is_Active__c = true
        ORDER BY Category__c, Sort_Order__c NULLS LAST, MasterLabel
    ];
}
    

    @AuraEnabled
    public static Id createRfiFromTemplate(String templateDeveloperName, Id projectId) {
        RFI_Template__mdt tmpl = [
            SELECT Subject_Template__c, Question_Template__c, SLA_Hours__c, 
                   Auto_Assign_To__c, Priority__c
            FROM RFI_Template__mdt
            WHERE DeveloperName = :templateDeveloperName
            LIMIT 1
        ];

        // Replace placeholders (expand as needed)
        String subject = tmpl.Subject_Template__c;
        String question = tmpl.Question_Template__c;

        // Create new RFI record
        RFI__c rfi = new RFI__c(
            Project__c = projectId,
            Subject__c = subject,
            Question_Rich__c = question,
            Status__c = 'Open',
            Priority__c = tmpl.Priority__c
        );

        // Apply SLA Hours → Due Date
        if (tmpl.SLA_Hours__c != null && tmpl.SLA_Hours__c > 0) {
            Integer hours = (Integer)tmpl.SLA_Hours__c;
            Integer days = (Integer)Math.ceil((Decimal)hours / 24);
            rfi.Due_Date__c = Date.today().addDays(days);
        }

        // Auto-assign user if provided (assuming Auto_Assign_To__c contains User ID as text)
        if (String.isNotBlank(tmpl.Auto_Assign_To__c)) {
            try {
                rfi.Assigned_To__c = (Id)tmpl.Auto_Assign_To__c;
            } catch(Exception e) {
                System.debug('Invalid User ID in Auto_Assign_To__c: ' + e.getMessage());
            }
        }

        insert rfi;
        return rfi.Id;
    }
  @AuraEnabled(cacheable=true)
public static SLAMetrics getSLAMetrics(Id projectId, Date startDate, Date endDate, 
                                     Boolean includeDetails, Boolean includeTrends) {
    SLAMetrics metrics = new SLAMetrics();
    DateTime startDateTime = DateTime.newInstance(startDate, Time.newInstance(0, 0, 0, 0));
    DateTime endDateTime = DateTime.newInstance(endDate.addDays(1), Time.newInstance(0, 0, 0, 0));
    
    try {
        // Get all RFIs for the project with available fields
        List<RFI__c> rfis = [
            SELECT Id, Name, Status__c, CreatedDate, LastModifiedDate,
                   Due_Date__c, Assigned_To__c, Assigned_To__r.Name, Assigned_To__r.Id,
                   Priority__c, Subject__c, Description__c, Project__c
            FROM RFI__c 
            WHERE Project__c = :projectId
            AND CreatedDate >= :startDateTime
            AND CreatedDate < :endDateTime
            WITH SECURITY_ENFORCED
            ORDER BY CreatedDate DESC
        ];
        
        // Calculate basic metrics
        metrics = calculateSlaMetrics(rfis);
        
        // Include detailed data if requested
        if (includeDetails) {
            metrics.teamPerformance = getTeamPerformance(rfis);
            metrics.exceptions = getSLAExceptions(rfis);
        }
        
        // Include trend data if requested
        if (includeTrends) {
            metrics.trendData = getTrendData(projectId, startDate, endDate);
        }
        
        return metrics;
        
    } catch (Exception e) {
        throw new AuraHandledException('Error generating SLA report: ' + e.getMessage());
    }
}
private static SLAMetrics calculateSlaMetrics(List<RFI__c> rfis) {
    SLAMetrics metrics = new SLAMetrics();
    Integer totalRfis = rfis.size();
    Integer compliantRfis = 0;
    Decimal totalResponseTime = 0;
    Integer respondedRfis = 0;
    
    // Track status counts
    Map<String, Integer> statusCounts = new Map<String, Integer>();
    // Track overdue RFIs
    List<RFI__c> overdueRfis = new List<RFI__c>();
    
    for (RFI__c rfi : rfis) {
        // For SLA compliance, we'll consider an RFI as responded if it's in a closed/responded status
        Boolean isResponded = (rfi.Status__c == 'Closed' || rfi.Status__c == 'Responded');
        
        if (isResponded) {
            // Calculate response time in hours
            Decimal responseHours = (rfi.LastModifiedDate.getTime() - rfi.CreatedDate.getTime()) / (1000 * 60 * 60);
            totalResponseTime += responseHours;
            respondedRfis++;
            
            // Check if response was within SLA (using default 24 hours if no priority)
            Decimal slaHours = getSLAHours(rfi.Priority__c);
            if (responseHours <= slaHours) {
                compliantRfis++;
            }
        }
        
        // Check if RFI is overdue
        if (rfi.Due_Date__c != null && 
            rfi.Due_Date__c < Date.today() && 
            rfi.Status__c != 'Closed' && 
            rfi.Status__c != 'Responded') {
            overdueRfis.add(rfi);
        }
        
        // Count by status
        if (!statusCounts.containsKey(rfi.Status__c)) {
            statusCounts.put(rfi.Status__c, 0);
        }
        statusCounts.put(rfi.Status__c, statusCounts.get(rfi.Status__c) + 1);
    }
    
    // Calculate metrics
    metrics.totalRfis = totalRfis;
    metrics.compliantRfis = compliantRfis;
    metrics.complianceRate = totalRfis > 0 ? (compliantRfis * 100.0) / totalRfis : 0;
    metrics.avgResponseTime = respondedRfis > 0 ? totalResponseTime / respondedRfis : 0;
    metrics.overdueRfis = overdueRfis.size();
    
    // Add status distribution
    metrics.statusDistribution = new List<StatusCount>();
    for (String status : statusCounts.keySet()) {
        StatusCount sc = new StatusCount();
        sc.status = status;
        sc.count = statusCounts.get(status);
        metrics.statusDistribution.add(sc);
    }
    
    // Add overdue RFI details
    metrics.overdueRfiDetails = new List<RFIDetail>();
    for (RFI__c rfi : overdueRfis) {
        RFIDetail detail = new RFIDetail();
        detail.id = rfi.Id;
        detail.rfiNumber = rfi.Name;
        detail.subject = rfi.Subject__c;
        detail.dueDate = rfi.Due_Date__c;
        detail.daysOverdue = rfi.Due_Date__c.daysBetween(Date.today());
        detail.assignedTo = rfi.Assigned_To__r?.Name;
        metrics.overdueRfiDetails.add(detail);
    }
    
    return metrics;
}
    private static List<TeamPerformance> getTeamPerformance(List<RFI__c> rfis) {
    Map<Id, TeamPerformance> teamMap = new Map<Id, TeamPerformance>();
    
    // Initialize team members
    for (RFI__c rfi : rfis) {
        if (rfi.Assigned_To__c != null && !teamMap.containsKey(rfi.Assigned_To__c)) {
            TeamPerformance tp = new TeamPerformance();
            tp.userId = rfi.Assigned_To__c;
            tp.userName = rfi.Assigned_To__r?.Name;
            tp.totalRfis = 0;
            tp.compliantRfis = 0;
            tp.avgResponseTime = 0;
            teamMap.put(rfi.Assigned_To__c, tp);
        }
    }
    
    // Calculate metrics for each team member
    for (RFI__c rfi : rfis) {
        if (rfi.Assigned_To__c != null) {
            TeamPerformance member = teamMap.get(rfi.Assigned_To__c);
            member.totalRfis++;
            
            // Check if RFI is within SLA
            if (isWithinSLA(rfi)) {
                member.compliantRfis++;
            }
            
            // Calculate response time
            if (rfi.Status__c == 'Closed' || rfi.Status__c == 'Responded') {
                Decimal responseHours = (rfi.LastModifiedDate.getTime() - rfi.CreatedDate.getTime()) / (1000 * 60 * 60);
                member.avgResponseTime = (member.avgResponseTime * (member.compliantRfis - 1) + responseHours) / member.compliantRfis;
            }
        }
    }
    
    // Calculate compliance rate for each team member
    for (TeamPerformance member : teamMap.values()) {
        member.complianceRate = member.totalRfis > 0 ? 
            (member.compliantRfis * 100.0) / member.totalRfis : 0;
    }
    
    return teamMap.values();
}

private static List<ExceptionDetail> getSLAExceptions(List<RFI__c> rfis) {
    List<ExceptionDetail> exceptions = new List<ExceptionDetail>();
    DateTime now = DateTime.now();
    
    for (RFI__c rfi : rfis) {
        if (!isWithinSLA(rfi) && rfi.Status__c != 'Draft' && rfi.Status__c != 'Cancelled') {
            Decimal slaHours = getSLAHours(rfi.Priority__c);
            DateTime dueDate = rfi.CreatedDate.addHours((Integer)slaHours);
            Long daysOverdue = (now.getTime() - dueDate.getTime()) / (1000 * 60 * 60 * 24);
            
            ExceptionDetail ex = new ExceptionDetail();
            ex.rfiNumber = rfi.Name;
            ex.subject = rfi.Subject__c;
            ex.assignedTo = rfi.Assigned_To__r?.Name;
            ex.daysOverdue = Integer.valueOf(daysOverdue);
            ex.reason = 'SLA Breach: Exceeded ' + slaHours + ' hour response time';
            ex.dueDate = dueDate.format('yyyy-MM-dd');
            exceptions.add(ex);
        }
    }
    
    return exceptions;
}

private static TrendData getTrendData(Id projectId, Date startDate, Date endDate) {
    TrendData trendData = new TrendData();
    trendData.weeks = new List<String>();
    trendData.complianceRates = new List<Decimal>();
    trendData.responseTimes = new List<Decimal>();
    
    // Group by week
    Date currentDate = startDate;
    while (currentDate <= endDate) {
        Date weekEnd = currentDate.addDays(6);
        if (weekEnd > endDate) {
            weekEnd = endDate;
        }
        
        // Query for this week's data
        List<RFI__c> weeklyRfis = [
            SELECT Id, Status__c, CreatedDate, LastModifiedDate, Priority__c
            FROM RFI__c 
            WHERE Project__c = :projectId
            AND CreatedDate >= :DateTime.newInstance(currentDate, Time.newInstance(0, 0, 0, 0))
            AND CreatedDate < :DateTime.newInstance(weekEnd.addDays(1), Time.newInstance(0, 0, 0, 0))
            WITH SECURITY_ENFORCED
        ];
        
        // Calculate weekly metrics
        SLAMetrics weeklyMetrics = calculateSlaMetrics(weeklyRfis);
        
        // Add to trend data
        trendData.weeks.add(currentDate.format() + ' to ' + weekEnd.format());
        trendData.complianceRates.add(weeklyMetrics.complianceRate);
        trendData.responseTimes.add(weeklyMetrics.avgResponseTime);
        
        currentDate = weekEnd.addDays(1);
    }
    
    return trendData;
}

private static Boolean isWithinSLA(RFI__c rfi) {
    if (rfi.Status__c == 'Draft' || rfi.Status__c == 'Cancelled') {
        return true;
    }
    
    Decimal slaHours = getSLAHours(rfi.Priority__c);
    DateTime dueDate = rfi.CreatedDate.addHours((Integer)slaHours);
    
    // If we have a response date, use that, otherwise use current time
    DateTime responseDate = (rfi.Status__c == 'Closed' || rfi.Status__c == 'Responded') ? 
        rfi.LastModifiedDate : DateTime.now();
        
    return responseDate <= dueDate;
}

public class SLAMetrics {
    @AuraEnabled public Integer totalRfis;
    @AuraEnabled public Integer compliantRfis;
    @AuraEnabled public Decimal complianceRate;
    @AuraEnabled public Decimal avgResponseTime;
    @AuraEnabled public Integer overdueRfis;
    @AuraEnabled public List<StatusCount> statusDistribution;
    @AuraEnabled public List<RFIDetail> overdueRfiDetails;
    @AuraEnabled public List<TeamPerformance> teamPerformance;
    @AuraEnabled public List<ExceptionDetail> exceptions;
    @AuraEnabled public TrendData trendData;
}

public class TeamPerformance {
    @AuraEnabled public String userId;
    @AuraEnabled public String userName;
    @AuraEnabled public Integer totalRfis;
    @AuraEnabled public Integer compliantRfis;
    @AuraEnabled public Decimal complianceRate;
    @AuraEnabled public Decimal avgResponseTime;
}

public class ExceptionDetail {
    @AuraEnabled public String rfiNumber;
    @AuraEnabled public String subject;
    @AuraEnabled public String assignedTo;
    @AuraEnabled public Integer daysOverdue;
    @AuraEnabled public String reason;
    @AuraEnabled public String dueDate;
}

public class TrendData {
    @AuraEnabled public List<String> weeks;
    @AuraEnabled public List<Decimal> complianceRates;
    @AuraEnabled public List<Decimal> responseTimes;
}

public class StatusCount {
    @AuraEnabled public String status;
    @AuraEnabled public Integer count;
}

public class RFIDetail {
    @AuraEnabled public Id id;
    @AuraEnabled public String rfiNumber; 
    @AuraEnabled public String subject;
    @AuraEnabled public Date dueDate;
    @AuraEnabled public Integer daysOverdue;
    @AuraEnabled public String assignedTo;
}

// Keep existing getSLAHours method
private static Decimal getSLAHours(String priority) {
    if (priority == 'High') return 8;
    if (priority == 'Medium') return 24;
    if (priority == 'Low') return 48;
    return 24; // Default
}
}