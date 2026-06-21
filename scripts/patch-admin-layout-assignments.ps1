$profilePath = Join-Path $PSScriptRoot "..\force-app\main\default\profiles\Admin.profile-meta.xml"
$objects = @(
    'Permit_to_Work__c','Observation__c','Incident__c','Toolbox_Talk__c','HIRA__c','Safety_Audit__c',
    'Audit_Finding__c','Emergency_Plan__c','OHS_Compliance_Item__c','Equipment__c','NCR__c','Work_Front__c',
    'Daily_Progress__c','Inspection_Test_Plan__c','Inspection_Request__c','CAPA__c','Calibration_Record__c',
    'Completion__c','Commissioning_Procedure__c','Punch_List_Item__c','Handover_Package__c','Training_Record__c','Final_Acceptance__c'
)
$assignments = $objects | ForEach-Object {
@"
    <layoutAssignments>
        <layout>${_}-EPC Detail Layout</layout>
    </layoutAssignments>
"@
}
$xml = Get-Content $profilePath -Raw
if ($xml -notmatch 'Permit_to_Work__c-EPC Detail Layout') {
    $insert = ($assignments -join "`n") + "`n</Profile>"
    $xml = $xml.Replace('</Profile>', $insert)
    Set-Content -Path $profilePath -Value $xml -Encoding UTF8
    Write-Output "Added $($objects.Count) layout assignments to Admin profile"
} else {
    Write-Output "Layout assignments already present"
}
