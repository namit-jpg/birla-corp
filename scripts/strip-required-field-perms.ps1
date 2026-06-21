$root = Join-Path $PSScriptRoot ".."
$permPath = Join-Path $root "force-app\main\default\permissionsets\EPC_Object_Field_Access.permissionset-meta.xml"
$required = @{}
Get-ChildItem (Join-Path $root "force-app\main\default\objects") -Recurse -Filter "*.field-meta.xml" | ForEach-Object {
    $xml = [xml](Get-Content $_.FullName)
    $ns = $xml.CustomField.NamespaceURI
    $requiredNode = $xml.SelectSingleNode('//sf:required', @{ sf = $ns })
    if ($requiredNode -and $requiredNode.InnerText -eq 'true') {
        $obj = $_.Directory.Parent.Name
        $field = $xml.CustomField.fullName
        $required["$obj.$field"] = $true
    }
}
$perm = Get-Content $permPath -Raw
$pattern = '(?s)\s*<fieldPermissions>\s*<editable>.*?</editable>\s*<field>([^<]+)</field>\s*<readable>.*?</readable>\s*</fieldPermissions>'
$removed = 0
$perm = [regex]::Replace($perm, $pattern, {
    param($m)
    if ($required.ContainsKey($m.Groups[1].Value)) {
        $script:removed++
        return ''
    }
    return $m.Value
})
Set-Content -Path $permPath -Value $perm.TrimEnd() + "`n" -Encoding UTF8
Write-Output "Removed $removed required field permission entries"
