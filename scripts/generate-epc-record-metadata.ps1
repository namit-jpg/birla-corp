# Generates EPC record page flexipages, layouts, and permission set field entries
$base = Split-Path -Parent $PSScriptRoot
$flexiDir = Join-Path $base "force-app\main\default\flexipages"
$layoutDir = Join-Path $base "force-app\main\default\layouts"
$permPath = Join-Path $base "force-app\main\default\permissionsets\EPC_Object_Field_Access.permissionset-meta.xml"

New-Item -ItemType Directory -Force -Path $flexiDir, $layoutDir | Out-Null

$objects = @{
    'Permit_to_Work__c' = @('Name','Permit_Type__c','Status__c','Area__c','Valid_From__c','Valid_To__c','Issued_By__c','Work_Description__c','Project__c','WBS_Item__c')
    'Observation__c' = @('Name','Observation_Type__c','Risk_Level__c','Status__c','Observation_Date__c','Observed_By__c','Description__c','Action_Required__c','Project__c')
    'Incident__c' = @('Name','Incident_Type__c','Severity__c','Is_Near_Miss__c','Status__c','Incident_Date__c','Description__c','Investigation__c','CAPA_Notes__c','Project__c')
    'Toolbox_Talk__c' = @('Name','Topic__c','Talk_Date__c','Conducted_By__c','Attendance_Count__c','Notes__c','Project__c')
    'HIRA__c' = @('Name','Activity__c','Hazard__c','Risk_Rating__c','Residual_Risk__c','Control_Measures__c','Status__c','Project__c')
    'Safety_Audit__c' = @('Name','Audit_Date__c','Auditor__c','Score__c','Status__c','Findings__c','Project__c')
    'Audit_Finding__c' = @('Name','Category__c','Severity__c','Finding_Status__c','Description__c','Closed_Date__c','Safety_Audit__c')
    'Emergency_Plan__c' = @('Name','Scenario__c','Plan_Status__c','Drill_Date__c','Contacts__c','Project__c')
    'OHS_Compliance_Item__c' = @('Name','Requirement__c','Compliance_Status__c','Evidence_URL__c','Project__c')
    'Equipment__c' = @('Name','Type__c','Status__c','Utilization_Hours__c','Project__c')
    'NCR__c' = @('Name','Severity__c','Category__c','Status__c','Identified_Date__c','RCA_Method__c','Root_Cause__c','Corrective_Action__c','Responsible_Party__c','Opened_By__c','Closed_Date__c','Vendor__c','Project__c','WBS_Item__c')
    'Work_Front__c' = @('Name','Readiness_Status__c','Released_Date__c','Blockers__c','Project__c','Work_Package__c')
    'Daily_Progress__c' = @('Name','Date__c','Work_Package__c','Qty_Installed__c','Planned_Quantity__c','Hours_Worked__c','Crew_Size__c','Equipment_Hours__c','Productivity__c','Weather__c','Quality_Issues__c','Safety_Incidents__c','Submitted_By__c','Approved_By__c','Project__c','WBS_Item__c')
    'Inspection_Test_Plan__c' = @('Name','Discipline__c','Status__c','Hold_Witness_Points__c','Description__c','Project__c')
    'Inspection_Request__c' = @('Name','Type__c','Area__c','Status__c','Requested_Date__c','Inspected_Date__c','Inspector__c','Result_Notes__c','ITP__c','Lot__c','Work_Package__c','Project__c','WBS_Item__c')
    'CAPA__c' = @('Name','Type__c','Status__c','Due_Date__c','Action__c','Verification__c','Owner__c','NCR__c')
    'Calibration_Record__c' = @('Name','Instrument__c','Serial_No__c','Calibration_Date__c','Due_Date__c','Status__c','Certificate_URL__c')
    'Completion__c' = @('Name','System__c','Stage__c','Completion_Status__c','Target_Date__c','Actual_Date__c','Result__c','Signed_Off_By__c','Project__c','WBS_Item__c')
    'Commissioning_Procedure__c' = @('Name','Proc_System__c','Proc_Status__c','Steps_Complete__c','Steps_Total__c','Procedure_Doc_URL__c','Project__c')
    'Punch_List_Item__c' = @('Name','Category__c','Priority__c','Punch_Status__c','Description__c','Due_Date__c','Assigned_To__c','Project__c','Handover_Package__c','WBS_Item__c','Work_Package__c')
    'Handover_Package__c' = @('Name','Package_Code__c','Package_Status__c','Scope__c','Client_Acceptance_Date__c','OM_Manual_URL__c','Project__c')
    'Training_Record__c' = @('Name','Topic__c','Trainee__c','Training_Date__c','Training_Status__c','Competency_Verified__c','Project__c')
    'Final_Acceptance__c' = @('Name','FAC_Status__c','Accepted_Date__c','Accepted_By__c','Certificate_URL__c','Project__c','Handover_Package__c')
}

function Get-LabelName($api) {
    if ($api -eq 'Name') { return 'Name' }
    return ($api -replace '__c$','') -replace '_',' '
}

function New-FlexiPage($objectApi, $label) {
    $pageName = ($objectApi -replace '__c$','') + '_Record_Page'
    $content = @"
<?xml version="1.0" encoding="UTF-8"?>
<FlexiPage xmlns="http://soap.sforce.com/2006/04/metadata">
    <flexiPageRegions>
        <itemInstances>
            <componentInstance>
                <componentInstanceProperties>
                    <name>collapsed</name>
                    <value>false</value>
                </componentInstanceProperties>
                <componentName>force:highlightsPanel</componentName>
                <identifier>force_highlightsPanel</identifier>
            </componentInstance>
        </itemInstances>
        <name>header</name>
        <type>Region</type>
    </flexiPageRegions>
    <flexiPageRegions>
        <itemInstances>
            <componentInstance>
                <componentName>force:detailPanel</componentName>
                <identifier>force_recordDetail</identifier>
            </componentInstance>
        </itemInstances>
        <name>main</name>
        <type>Region</type>
    </flexiPageRegions>
    <masterLabel>$label Record Page</masterLabel>
    <sobjectType>$objectApi</sobjectType>
    <template>
        <name>flexipage:recordHomeTemplateDesktop</name>
    </template>
    <type>RecordPage</type>
</FlexiPage>
"@
    $path = Join-Path $flexiDir "$pageName.flexipage-meta.xml"
    if (-not (Test-Path $path)) {
        Set-Content -Path $path -Value $content -Encoding UTF8
    }
    return $pageName
}

function New-Layout($objectApi, $fields) {
    $layoutName = "$objectApi-EPC Detail Layout"
    $col1 = @(); $col2 = @()
    for ($i = 0; $i -lt $fields.Count; $i++) {
        $behavior = if ($fields[$i] -eq 'Name') { 'Readonly' } else { 'Edit' }
        $item = @"
            <layoutItems>
                <behavior>$behavior</behavior>
                <field>$($fields[$i])</field>
            </layoutItems>
"@
        if ($i % 2 -eq 0) { $col1 += $item } else { $col2 += $item }
    }
    $content = @"
<?xml version="1.0" encoding="UTF-8"?>
<Layout xmlns="http://soap.sforce.com/2006/04/metadata">
    <layoutSections>
        <customLabel>false</customLabel>
        <detailHeading>false</detailHeading>
        <editHeading>true</editHeading>
        <label>Information</label>
        <layoutColumns>
$($col1 -join "`n")
        </layoutColumns>
        <layoutColumns>
$($col2 -join "`n")
        </layoutColumns>
        <style>TwoColumnsTopToBottom</style>
    </layoutSections>
    <layoutSections>
        <customLabel>false</customLabel>
        <detailHeading>false</detailHeading>
        <editHeading>true</editHeading>
        <label>System Information</label>
        <layoutColumns>
            <layoutItems>
                <behavior>Readonly</behavior>
                <field>CreatedById</field>
            </layoutItems>
        </layoutColumns>
        <layoutColumns>
            <layoutItems>
                <behavior>Readonly</behavior>
                <field>LastModifiedById</field>
            </layoutItems>
        </layoutColumns>
        <style>TwoColumnsTopToBottom</style>
    </layoutSections>
    <showEmailCheckbox>false</showEmailCheckbox>
    <showHighlightsPanel>false</showHighlightsPanel>
    <showInteractionLogPanel>false</showInteractionLogPanel>
    <showRunAssignmentRulesCheckbox>false</showRunAssignmentRulesCheckbox>
    <showSubmitAndAttachButton>false</showSubmitAndAttachButton>
</Layout>
"@
    $fileName = "$layoutName.layout-meta.xml"
    Set-Content -Path (Join-Path $layoutDir $fileName) -Value $content -Encoding UTF8
    return $layoutName
}

$fieldPerms = @()
$objectPerms = @()

foreach ($entry in $objects.GetEnumerator()) {
    $obj = $entry.Key
    $fields = $entry.Value
    $label = (Get-LabelName ($obj -replace '__c$',''))
    $page = New-FlexiPage $obj $label
    $layout = New-Layout $obj $fields
    Write-Output "Created $obj -> $page / $layout"

    $objectPerms += @"
    <objectPermissions>
        <allowCreate>true</allowCreate>
        <allowDelete>true</allowDelete>
        <allowEdit>true</allowEdit>
        <allowRead>true</allowRead>
        <modifyAllRecords>true</modifyAllRecords>
        <object>$obj</object>
        <viewAllRecords>true</viewAllRecords>
    </objectPermissions>
"@

    foreach ($f in $fields) {
        if ($f -eq 'Name') { continue }
        $fieldPerms += @"
    <fieldPermissions>
        <editable>true</editable>
        <field>${obj}.$f</field>
        <readable>true</readable>
    </fieldPermissions>
"@
    }
}

$permXml = @"
<?xml version="1.0" encoding="UTF-8"?>
<PermissionSet xmlns="http://soap.sforce.com/2006/04/metadata">
    <description>Read/write access to all EPC console object fields for detail pages</description>
    <hasActivationRequired>false</hasActivationRequired>
    <label>EPC Object Field Access</label>
$($objectPerms -join "`n")
$($fieldPerms -join "`n")
</PermissionSet>
"@
Set-Content -Path $permPath -Value $permXml -Encoding UTF8
Write-Output "Permission set written to $permPath"
