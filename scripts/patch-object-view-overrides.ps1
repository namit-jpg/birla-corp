$objectsDir = Join-Path $PSScriptRoot "..\force-app\main\default\objects"
Get-ChildItem $objectsDir -Directory | ForEach-Object {
    $api = $_.Name
    $pageName = ($api -replace '__c$','') + '_Record_Page'
    $file = Join-Path $_.FullName "$api.object-meta.xml"
    if (-not (Test-Path $file)) { return }
    $xml = Get-Content $file -Raw
    $old = @'
    <actionOverrides>
        <actionName>View</actionName>
        <type>Default</type>
    </actionOverrides>
    <actionOverrides>
        <actionName>View</actionName>
        <formFactor>Large</formFactor>
        <type>Default</type>
    </actionOverrides>
    <actionOverrides>
        <actionName>View</actionName>
        <formFactor>Small</formFactor>
        <type>Default</type>
    </actionOverrides>
'@
    $new = @"
    <actionOverrides>
        <actionName>View</actionName>
        <content>$pageName</content>
        <formFactor>Large</formFactor>
        <skipRecordTypeSelect>false</skipRecordTypeSelect>
        <type>Flexipage</type>
    </actionOverrides>
    <actionOverrides>
        <actionName>View</actionName>
        <content>$pageName</content>
        <formFactor>Small</formFactor>
        <skipRecordTypeSelect>false</skipRecordTypeSelect>
        <type>Flexipage</type>
    </actionOverrides>
"@
    if ($xml -match [regex]::Escape($old.Trim())) {
        $xml = $xml.Replace($old, $new)
        Set-Content -Path $file -Value $xml -Encoding UTF8 -NoNewline
        Write-Output "Patched View override: $api -> $pageName"
    } else {
        Write-Output "SKIP (View block not found): $api"
    }
}
