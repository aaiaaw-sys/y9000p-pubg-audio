# SPDX-License-Identifier: GPL-3.0-only
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:Render = 'SOFTWARE\Microsoft\Windows\CurrentVersion\MMDevices\Audio\Render'
$script:FxId = '{d04e05a6-594b-4fb6-a80d-01af5eed7d1d},'
$script:Enable = '{fc52a749-4be9-4510-896e-966ba6525980},3'
$script:Release = '{9c00eeed-edce-4cd8-ae08-cb05e8ef57a0},3'
$script:Child = '{62dc1a93-ae24-464c-a43e-452f824c4250}'

function Resolve-LeqEndpointId([string]$EndpointId) {
    if ($EndpointId -notmatch '^\{?[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\}?$') { throw 'Supply only the endpoint GUID from Get-AudioStatus; registry paths are not accepted.' }
    ([guid]$EndpointId).ToString('B').ToLowerInvariant()
}
function Get-LeqPaths([string]$EndpointId) {
    $id = Resolve-LeqEndpointId $EndpointId
    [pscustomobject]@{ Id=$id; Endpoint="$script:Render\$id"; Fx="$script:Render\$id\FxProperties"; Child="SOFTWARE\EqualizerAPO\Child APOs\$id" }
}
function Open-LeqBase {
    if ($env:OS -ne 'Windows_NT' -or ![Environment]::Is64BitProcess) { throw 'Use 64-bit Windows PowerShell 5.1 on Windows.' }
    [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine,[Microsoft.Win32.RegistryView]::Registry64)
}
function New-LeqValue([bool]$Exists, $Kind, $Data) { [pscustomobject]@{ Exists=$Exists; Kind=$Kind; Data=$Data } }
function Read-LeqValue($Key,[string]$Name) {
    if ($null -eq $Key -or $Key.GetValueNames() -notcontains $Name) { return New-LeqValue $false $null $null }
    $kind = $Key.GetValueKind($Name).ToString()
    $data = $Key.GetValue($Name,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
    if ($kind -eq 'Binary') { $data = [Convert]::ToBase64String([byte[]]$data) }
    if ($kind -eq 'MultiString') { $data = @([string[]]$data) }
    New-LeqValue $true $kind $data
}
function Test-LeqEqual($A,$B) { ($A|ConvertTo-Json -Depth 30 -Compress) -ceq ($B|ConvertTo-Json -Depth 30 -Compress) }
function Get-LeqEnabledValue([bool]$Enabled) {
    $b = [byte[]](11,0,0,0,1,0,0,0,0,0,0,0)
    if ($Enabled) { $b[8]=255; $b[9]=255 }
    New-LeqValue $true 'Binary' ([Convert]::ToBase64String($b))
}
function Get-LeqReleaseValue([ValidateRange(2,7)][int]$Code) { New-LeqValue $true 'Binary' ([Convert]::ToBase64String([byte[]](3,0,0,0,1,0,0,0,$Code,0,0,0))) }
function Get-LeqEnableState($Value) {
    if (Test-LeqEqual $Value (Get-LeqEnabledValue $true)) { return 'On' }
    if (Test-LeqEqual $Value (Get-LeqEnabledValue $false)) { return 'Off' }
    if (!$Value.Exists) { return 'Missing' }
    'Unknown'
}
function Get-LeqReleaseCode($Value) {
    foreach ($i in 2..7) { if (Test-LeqEqual $Value (Get-LeqReleaseValue $i)) { return $i } }
    $null
}
function Get-LeqPlan([string]$EndpointId,[ValidateRange(2,7)][int]$ReleaseCode=4) {
    $p = Get-LeqPaths $EndpointId
    @(
        [pscustomobject]@{Path=$p.Fx;Name=$script:Release;After=(Get-LeqReleaseValue $ReleaseCode)},
        [pscustomobject]@{Path=$p.Fx;Name=$script:Enable;After=(Get-LeqEnabledValue $true)},
        [pscustomobject]@{Path=$p.Child;Name='PreMixChild';After=(New-LeqValue $true 'String' $script:Child)}
    )
}
function Get-LeqExpectedComposite {
    @{
        13=@('{670173E3-78CF-11E5-A837-0800200C9A66}');
        14=@('{670173E4-78CF-11E5-A837-0800200C9A66}','{A296D363-EE83-4AF9-9BE7-729C1296150A}','{001897D5-ADD1-4C31-90FD-34B06B8E7EE4}','{670173E5-78CF-11E5-A837-0800200C9A66}');
        15=@('{A29EB043-6CE2-4EE2-B38C-F58719E0D88F}');
        19=@('{670173E3-78CF-11E5-A837-0800200C9A66}');
        20=@('{670173E4-78CF-11E5-A837-0800200C9A66}','{670173E5-78CF-11E5-A837-0800200C9A66}')
    }
}
function Get-LeqReadiness($Base,[string]$EndpointId) {
    $p=Get-LeqPaths $EndpointId; $keys=@{}; $issues=[Collections.Generic.List[string]]::new()
    try {
        foreach ($name in 'Endpoint','Fx','Child') { $keys[$name]=$Base.OpenSubKey($p.$name,$false) }
        $keys.Properties=$Base.OpenSubKey($p.Endpoint+'\Properties',$false)
        $missing=@($keys.GetEnumerator()|Where-Object {$null -eq $_.Value}|ForEach-Object {$_.Key})
        if ($missing.Count) { throw ('Required existing key(s) missing or unreadable: '+($missing -join ', ')+'. No key will be created.') }
        $fx=$keys.Fx; $c=$keys.Child; $props=$keys.Properties
        $friendly=Read-LeqValue $props '{a45c254e-df1c-4efd-8020-67d146a850e0},2'
        $adapter=Read-LeqValue $props '{b3f8fa53-0004-438e-9003-51a46e139bfc},6'
        $form=Read-LeqValue $props '{1da5d803-d492-4edd-8c23-e0c0ffee7f0e},0'
        $state=Read-LeqValue $keys.Endpoint 'DeviceState'
        if (!$state.Exists -or $state.Kind -ne 'DWord' -or $state.Data -ne 1) { $issues.Add('Endpoint is not active.') }
        if (!$adapter.Exists -or [string]$adapter.Data -notmatch 'Realtek') { $issues.Add('Only the Realtek render profile is supported.') }
        if (!$form.Exists -or $form.Kind -ne 'DWord' -or $form.Data -notin 3,5) { $issues.Add('Endpoint form factor must be Headphones or Headset; speakers/HDMI/Bluetooth are not supported.') }
        $bindings=@{5='{EACD2258-FCAC-4FF4-B36D-419E924A6D79}';7='{EC1CC9CE-FAED-4822-828A-82A81A6F018F}'}
        foreach ($slot in $bindings.Keys) { $v=Read-LeqValue $fx ($script:FxId+$slot); if (!$v.Exists -or $v.Kind -ne 'String' -or $v.Data -ine $bindings[$slot]) { $issues.Add("E-APO F,$slot binding is missing or different. Configure E-APO separately; this tool will not repair it.") } }
        foreach ($slot in 1,2,6) { if ((Read-LeqValue $fx ($script:FxId+$slot)).Exists) { $issues.Add("Unexpected single APO F,$slot.") } }
        $disable=Read-LeqValue $fx '{1da5d803-d492-4edd-8c23-e0c0ffee7f0e},5'
        if ($disable.Exists -and ($disable.Kind -ne 'DWord' -or $disable.Data -ne 0)) { $issues.Add('System effects disabled/unknown. This tool will not change Disable_SysFx.') }
        $composite=Get-LeqExpectedComposite
        foreach ($slot in $composite.Keys) {
            $v=Read-LeqValue $fx ($script:FxId+$slot)
            $list=@($v.Data|ForEach-Object {([string]$_).ToUpperInvariant()})
            if (!$v.Exists -or $v.Kind -ne 'MultiString' -or !(Test-LeqEqual $list $composite[$slot])) { $issues.Add("OEM F,$slot differs from the tested profile; do not copy another device's list.") }
        }
        $context=$fx.OpenSubKey('{B13412EE-07AF-4C57-B08B-E327F8DB085B}',$false)
        if ($context) { $context.Dispose(); $issues.Add('Microsoft context already exists; this legacy-root profile does not combine stores.') }
        foreach ($fmtid in '{fc52a749-4be9-4510-896e-966ba6525980}','{9c00eeed-edce-4cd8-ae08-cb05e8ef57a0}') { if ((Read-LeqValue $fx ($fmtid+',1599')).Exists) { $issues.Add('Unexpected multi-channel LEQ parameters exist.') } }
        $post=Read-LeqValue $c 'PostMixChild'; $version=Read-LeqValue $c 'Version'
        if (!(Test-LeqEqual $post (New-LeqValue $true 'String' ''))) { $issues.Add('PostMixChild is not an empty REG_SZ.') }
        if (!(Test-LeqEqual $version (New-LeqValue $true 'String' '2'))) { $issues.Add('E-APO child configuration version must be 2.') }
        $format=Read-LeqValue $props '{f19f064d-082c-4e27-bc73-6882a1bb8e4c},0'; $mask=$null
        if ($format.Exists -and $format.Kind -eq 'Binary') {
            $b=[Convert]::FromBase64String($format.Data)
            if ($b.Length -ge 48 -and [BitConverter]::ToUInt32($b,0) -eq 65 -and [BitConverter]::ToUInt32($b,4) -eq 1 -and [BitConverter]::ToUInt16($b,8) -eq 0xfffe -and [BitConverter]::ToUInt16($b,10) -eq 2) { $mask=[BitConverter]::ToUInt32($b,28) }
        }
        if ($mask -ne 3) { $issues.Add('Expected the tested extensible stereo format with channel mask 3.') }
        $pre=Read-LeqValue $c 'PreMixChild'; $enable=Read-LeqValue $fx $script:Enable; $release=Read-LeqValue $fx $script:Release
        $enableState=Get-LeqEnableState $enable; $releaseCode=Get-LeqReleaseCode $release
        $fresh=!( $enable.Exists -or $release.Exists ) -and (Test-LeqEqual $pre (New-LeqValue $true 'String' ''))
        $configured=(Test-LeqEqual $pre (New-LeqValue $true 'String' $script:Child)) -and $enableState -in 'On','Off' -and $null -ne $releaseCode
        if (!$fresh -and !$configured) { $issues.Add('Partial or unknown child/LEQ configuration; do not overwrite it.') }
        [pscustomobject]@{EndpointId=$p.Id;Name=$friendly.Data;Adapter=$adapter.Data;Active=($state.Exists -and $state.Data -eq 1);FormFactor=$form.Data;Profile='lenovo-nahimic-composite-stereo-v1';ProfileMatched=($issues.Count -eq 0);Configuration=if($fresh){'Fresh'}elseif($configured){'Configured'}else{'Unknown'};LeqConfiguredState=$enableState;ReleaseCode=$releaseCode;ProcessingVerified=$false;Issues=@($issues.ToArray())}
    } finally { foreach ($key in $keys.Values) { if ($key) {$key.Dispose()} } }
}
function Get-LeqDevices {
    $base=Open-LeqBase; $root=$null
    try {
        $root=$base.OpenSubKey($script:Render,$false); if (!$root) { throw 'Render registry is not readable.' }
        foreach ($id in $root.GetSubKeyNames()) {
            try { Get-LeqReadiness $base $id } catch {
                $reason=$_.Exception.Message;$props=$null
                try{
                    $props=$base.OpenSubKey("$script:Render\$id\Properties",$false)
                    $friendly=Read-LeqValue $props '{a45c254e-df1c-4efd-8020-67d146a850e0},2'
                    $adapter=Read-LeqValue $props '{b3f8fa53-0004-438e-9003-51a46e139bfc},6'
                    [pscustomobject]@{EndpointId=$id;Name=$friendly.Data;Adapter=$adapter.Data;ProfileMatched=$false;Issues=@($reason)}
                }finally{if($props){$props.Dispose()}}
            }
        }
    } finally { if($root){$root.Dispose()};$base.Dispose() }
}
function Assert-LeqMicrosoftComponent($Base) {
    $eapoPaths=@(foreach($clsid in '{EACD2258-FCAC-4FF4-B36D-419E924A6D79}','{EC1CC9CE-FAED-4822-828A-82A81A6F018F}'){
        $reg=$Base.OpenSubKey("SOFTWARE\Classes\CLSID\$clsid\InProcServer32",$false)
        if(!$reg){throw 'E-APO COM registration missing.'}
        try{$value=[Environment]::ExpandEnvironmentVariables([string]$reg.GetValue(''))}finally{$reg.Dispose()}
        if([IO.Path]::GetFileName($value) -ine 'EqualizerAPO.dll' -or !(Test-Path -LiteralPath $value -PathType Leaf)){throw 'Unexpected E-APO DLL path.'}
        $version=[Diagnostics.FileVersionInfo]::GetVersionInfo($value).ProductVersion
        if($version -notmatch '^1\.4\.2(?:\.|$)'){throw "E-APO $version is not the tested 1.4.2; stop and report compatibility separately."}
        $value
    })
    if($eapoPaths[0] -ine $eapoPaths[1]){throw 'E-APO PRE and POST use different libraries.'}
    $key=$Base.OpenSubKey("SOFTWARE\Classes\CLSID\$script:Child\InProcServer32",$false)
    if (!$key) { throw 'Microsoft WM LFX COM registration missing; no repair attempted.' }
    try { $dll=[Environment]::ExpandEnvironmentVariables([string]$key.GetValue('')); $thread=$key.GetValue('ThreadingModel') } finally {$key.Dispose()}
    if ($dll -ine (Join-Path $env:SystemRoot 'System32\WMALFXGFXDSP.dll') -or $thread -ine 'Both') { throw 'Unexpected Microsoft COM registration.' }
    $sig=Get-AuthenticodeSignature -LiteralPath $dll
    if ($sig.Status -ne 'Valid' -or $null -eq $sig.SignerCertificate -or $sig.SignerCertificate.Subject -notmatch 'Microsoft Windows') { throw 'Microsoft DLL signature could not be verified.' }
    [pscustomobject]@{DLL=$dll;SHA256=(Get-FileHash -LiteralPath $dll -Algorithm SHA256).Hash;Signature='Valid';EapoVersion='1.4.2';EapoDLL=$eapoPaths[0]}
}
function Read-LeqTree($Base,[string]$Path) {
    $key=$Base.OpenSubKey($Path,[Microsoft.Win32.RegistryKeyPermissionCheck]::ReadSubTree,[Security.AccessControl.RegistryRights]::ReadKey)
    if (!$key) { throw "Existing key unreadable: $Path" }
    try {
        $sections=[Security.AccessControl.AccessControlSections]::Access -bor [Security.AccessControl.AccessControlSections]::Owner -bor [Security.AccessControl.AccessControlSections]::Group
        $sec=$key.GetAccessControl($sections)
        $values=@(foreach($name in ($key.GetValueNames()|Sort-Object)){[pscustomobject]@{Name=$name;Value=(Read-LeqValue $key $name)}})
        [pscustomobject]@{Path=$Path;SDDL=$sec.GetSecurityDescriptorSddlForm($sections);Values=$values}
        foreach($child in ($key.GetSubKeyNames()|Sort-Object)){Read-LeqTree $Base ($Path+'\'+$child)}
    } finally {$key.Dispose()}
}
function Get-LeqProtectedState($Base,[string]$EndpointId,$Exclude) {
    $p=Get-LeqPaths $EndpointId
    foreach($node in (@(Read-LeqTree $Base $p.Endpoint)+@(Read-LeqTree $Base $p.Child))){
        $values=@($node.Values|Where-Object {$name=$_.Name;$path=$node.Path;@($Exclude|Where-Object {$_.Path -ieq $path -and $_.Name -ieq $name}).Count -eq 0})
        [pscustomobject]@{Path=$node.Path;SDDL=$node.SDDL;Values=$values}
    }
}
function Open-LeqHandles($Base,$Plan) {
    $handles=@{}; $rights=[Security.AccessControl.RegistryRights]::QueryValues -bor [Security.AccessControl.RegistryRights]::SetValue
    try {
        foreach($path in @($Plan.Path|Select-Object -Unique)) {
            $key=$Base.OpenSubKey($path,[Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree,$rights)
            if(!$key){throw 'Minimal write access denied or target missing. No key/ACL fallback.'}; $handles[$path]=$key
        }; $handles
    } catch { foreach($key in $handles.Values){$key.Dispose()}; throw }
}
function Write-LeqValue($Key,[string]$Name,$Value) {
    if(!$Value.Exists){$Key.DeleteValue($Name,$true);return}
    if($Value.Kind -ceq 'Binary'){$data=[Convert]::FromBase64String([string]$Value.Data)}
    elseif($Value.Kind -ceq 'String'){$data=[string]$Value.Data}else{throw 'Unexpected write type.'}
    $kind=[Microsoft.Win32.RegistryValueKind][Enum]::Parse([Microsoft.Win32.RegistryValueKind],$Value.Kind)
    $Key.SetValue($Name,$data,$kind)
}
function Save-LeqJson([string]$Path,$Value) {
    $tmp=$Path+'.'+[guid]::NewGuid().ToString('N')+'.tmp'
    try {
        [IO.File]::WriteAllText($tmp,($Value|ConvertTo-Json -Depth 40),[Text.UTF8Encoding]::new($false))
        if([IO.File]::Exists($Path)){[IO.File]::Replace($tmp,$Path,[NullString]::Value)}else{[IO.File]::Move($tmp,$Path)}
    } finally { if([IO.File]::Exists($tmp)){[IO.File]::Delete($tmp)} }
}
function Assert-LeqAdmin {
    $principal=[Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
    if(!$principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){throw 'Apply requires an already elevated administrator PowerShell.'}
}
function Enter-LeqLock([string]$EndpointId) {
    $mutex=[Threading.Mutex]::new($false,('Local\Y9000PPubgAudio-'+(Resolve-LeqEndpointId $EndpointId)))
    try{if(!$mutex.WaitOne(0)){throw 'Another LEQ operation is running for this endpoint.'};$mutex}catch{$mutex.Dispose();throw}
}
function Read-LeqCurrent($Base,$Plan) {
    foreach($c in $Plan){$key=$Base.OpenSubKey($c.Path,$false);if(!$key){throw 'Target key missing.'};try{Read-LeqValue $key $c.Name}finally{$key.Dispose()}}
}
function Assert-LeqManifest($Manifest) {
    if($Manifest.Schema -ne 1 -or $Manifest.Profile -cne 'lenovo-nahimic-composite-stereo-v1'){throw 'Unsupported backup schema/profile.'}
    $plan=@(Get-LeqPlan $Manifest.EndpointId $Manifest.ReleaseCode)
    if(@($Manifest.Changes).Count -ne 3){throw 'Backup must contain exactly the three whitelisted values.'}
    for($i=0;$i -lt 3;$i++){
        $c=$Manifest.Changes[$i];$p=$plan[$i]
        $before=if($i -eq 2){New-LeqValue $true 'String' ''}else{New-LeqValue $false $null $null}
        if($c.Path -cne $p.Path -or $c.Name -cne $p.Name -or !(Test-LeqEqual $c.After $p.After) -or !(Test-LeqEqual $c.Before $before)){throw 'Backup contains an unexpected path, type, before value or payload.'}
    }
}
function Read-LeqBackup([string]$BackupDirectory) {
    $dir=(Get-Item -LiteralPath $BackupDirectory -ErrorAction Stop).FullName
    $path=Join-Path $dir 'backup.json';$hash=(Get-Content -LiteralPath (Join-Path $dir 'backup.sha256') -Raw).Trim()
    if($hash -notmatch '^[0-9A-Fa-f]{64}$' -or (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ine $hash){throw 'Backup integrity check failed.'}
    $manifest=Get-Content -LiteralPath $path -Raw -Encoding UTF8|ConvertFrom-Json; Assert-LeqManifest $manifest
    $ownership=Get-Content -LiteralPath (Join-Path $dir 'ownership.json') -Raw -Encoding UTF8|ConvertFrom-Json
    if($ownership.Schema -ne 1 -or $ownership.EndpointId -cne $manifest.EndpointId -or $ownership.Current -cnotin 'On','Off' -or ($null -ne $ownership.Pending -and $ownership.Pending -cnotin 'On','Off')){throw 'Invalid ownership journal.'}
    [pscustomobject]@{Directory=$dir;Manifest=$manifest;Ownership=$ownership}
}
function Get-LeqRestoreActions($Manifest,$Ownership,$Current) {
    Assert-LeqManifest $Manifest
    if(@($Current).Count -ne 3){throw 'Three current values required.'}
    for($i=0;$i -lt 3;$i++){
        $c=$Manifest.Changes[$i];$allowed=@($c.Before)
        if($i -eq 1){
            if($Ownership.Current -cnotin 'On','Off' -or ($null -ne $Ownership.Pending -and $Ownership.Pending -cnotin 'On','Off')){throw 'Invalid ownership state.'}
            $allowed+=Get-LeqEnabledValue ($Ownership.Current -ceq 'On')
            if($null -ne $Ownership.Pending){$allowed+=Get-LeqEnabledValue ($Ownership.Pending -ceq 'On')}
        }else{$allowed+=$c.After}
        if(@($allowed|Where-Object {Test-LeqEqual $_ $Current[$i]}).Count -eq 0){throw "Unknown third state at $($c.Name); no rollback writes permitted."}
    }
    for($i=2;$i -ge 0;$i--){if(!(Test-LeqEqual $Current[$i] $Manifest.Changes[$i].Before)){$Manifest.Changes[$i]}}
}
function Restore-LeqWithHandles($Manifest,$Ownership,$Handles) {
    $now=@(foreach($c in $Manifest.Changes){Read-LeqValue $Handles[$c.Path] $c.Name})
    $actions=@(Get-LeqRestoreActions $Manifest $Ownership $now)
    foreach($c in $actions){
        # Recheck the complete set before each mutation, not just the next value.
        $now=@(foreach($op in $Manifest.Changes){Read-LeqValue $Handles[$op.Path] $op.Name})
        $null=@(Get-LeqRestoreActions $Manifest $Ownership $now)
        $v=Read-LeqValue $Handles[$c.Path] $c.Name
        if(Test-LeqEqual $v $c.Before){continue}
        Write-LeqValue $Handles[$c.Path] $c.Name $c.Before
        if(!(Test-LeqEqual (Read-LeqValue $Handles[$c.Path] $c.Name) $c.Before)){throw 'Rollback readback failed.'}
    }
}
function Invoke-LeqInstall {
    param([Parameter(Mandatory)][string]$EndpointId,[ValidateRange(2,7)][int]$ReleaseCode=4,[string]$BackupRoot,[switch]$Apply)
    $p=Get-LeqPaths $EndpointId;$base=$null;$handles=$null;$mutex=$null;$manifest=$null;$dir=$null;$started=$false
    try{
        $base=Open-LeqBase;$status=Get-LeqReadiness $base $p.Id
        if(!$status.ProfileMatched){throw ($status.Issues -join ' ')}
        if($status.Configuration -ne 'Fresh'){throw 'Already/partly configured. Use the original installation backup; no adoption or reinstall is performed.'}
        $component=Assert-LeqMicrosoftComponent $base
        $plan=@(Get-LeqPlan $p.Id $ReleaseCode);$values=@(Read-LeqCurrent $base $plan)
        $changes=@(for($i=0;$i -lt 3;$i++){[pscustomobject]@{Path=$plan[$i].Path;Name=$plan[$i].Name;Before=$values[$i];After=$plan[$i].After}})
        $protected=@(Get-LeqProtectedState $base $p.Id $plan)
        $manifest=[pscustomobject]@{Schema=1;Profile=$status.Profile;EndpointId=$p.Id;ReleaseCode=$ReleaseCode;Timestamp=(Get-Date -Format o);Component=$component;Changes=$changes;ProtectedState=$protected}
        Assert-LeqManifest $manifest
        if(!$Apply){return [pscustomobject]@{DryRun=$true;Changes=$changes;RegistryWrites=0}}
        Assert-LeqAdmin;$mutex=Enter-LeqLock $p.Id;$handles=Open-LeqHandles $base $plan
        if(!(Test-LeqEqual (@(Read-LeqCurrent $base $plan)) $values) -or !(Test-LeqEqual (@(Get-LeqProtectedState $base $p.Id $plan)) $protected)){throw 'State changed during preflight.'}
        if(!$BackupRoot){$BackupRoot=Join-Path (Split-Path -Parent $PSScriptRoot) 'runtime'}
        $dir=Join-Path ([IO.Path]::GetFullPath($BackupRoot)) ('installation-'+(Get-Date -Format 'yyyyMMdd-HHmmss')+'-'+[guid]::NewGuid().ToString('N'))
        [void][IO.Directory]::CreateDirectory($dir)
        Save-LeqJson (Join-Path $dir 'backup.json') $manifest
        (Get-FileHash -LiteralPath (Join-Path $dir 'backup.json') -Algorithm SHA256).Hash|Set-Content -LiteralPath (Join-Path $dir 'backup.sha256') -Encoding ASCII
        $ownership=[pscustomobject]@{Schema=1;EndpointId=$p.Id;Current='On';Pending=$null}
        Save-LeqJson (Join-Path $dir 'ownership.json') $ownership
        $null=Read-LeqBackup $dir
        Write-Host "BackupDirectory: $dir"
        foreach($c in $changes){
            if(!(Test-LeqEqual (Read-LeqValue $handles[$c.Path] $c.Name) $c.Before)){throw 'Value changed before write.'}
            ((Get-Date -Format o)+' ATTEMPT '+$c.Name)|Add-Content -LiteralPath (Join-Path $dir 'operations.log') -Encoding UTF8
            $started=$true;Write-LeqValue $handles[$c.Path] $c.Name $c.After
            if(!(Test-LeqEqual (Read-LeqValue $handles[$c.Path] $c.Name) $c.After)){throw 'Immediate readback mismatch.'}
            ('VERIFIED '+$c.Name)|Add-Content -LiteralPath (Join-Path $dir 'operations.log') -Encoding UTF8
        }
        if(!(Test-LeqEqual (@(Get-LeqProtectedState $base $p.Id $plan)) $protected)){throw 'Unrelated endpoint/child value or SDDL changed during install.'}
        [pscustomobject]@{Configured=$true;BackupDirectory=$dir;RegistryValuesChanged=3;ProcessingVerified=$false;Next='Restart Windows manually and verify sound, LEQ effect and OEM functions.'}
    }catch{
        $reason=$_.Exception.Message
        if($started -and $manifest -and $handles){
            try{Restore-LeqWithHandles $manifest ([pscustomobject]@{Current='On';Pending=$null}) $handles;Write-Warning 'Only this operation''s values were restored.'}
            catch{throw "Install error: $reason; guarded rollback refused/failed: $($_.Exception.Message). Backup: $dir. Stop; do not change ACL."}
        };throw $reason
    }finally{if($handles){foreach($k in $handles.Values){$k.Dispose()}};if($base){$base.Dispose()};if($mutex){$mutex.ReleaseMutex();$mutex.Dispose()}}
}
function Invoke-LeqRestore {
    param([Parameter(Mandatory)][string]$BackupDirectory,[switch]$Apply)
    $backup=Read-LeqBackup $BackupDirectory;$m=$backup.Manifest;$base=$null;$handles=$null;$mutex=$null
    try{
        $base=Open-LeqBase;$current=@(Read-LeqCurrent $base $m.Changes)
        $actions=@(Get-LeqRestoreActions $m $backup.Ownership $current)
        if(!$Apply){return [pscustomobject]@{DryRun=$true;Restore=$actions;RegistryWrites=0}}
        Assert-LeqAdmin;$mutex=Enter-LeqLock $m.EndpointId;$backup=Read-LeqBackup $backup.Directory
        $handles=Open-LeqHandles $base $m.Changes
        $protected=@(Get-LeqProtectedState $base $m.EndpointId $m.Changes)
        Restore-LeqWithHandles $m $backup.Ownership $handles
        if(!(Test-LeqEqual (@(Get-LeqProtectedState $base $m.EndpointId $m.Changes)) $protected)){Write-Warning 'Unrelated state changed concurrently; it was not restored.'}
        ((Get-Date -Format o)+' RESTORE VERIFIED')|Add-Content -LiteralPath (Join-Path $backup.Directory 'operations.log') -Encoding UTF8
        [pscustomobject]@{Restored=$true;EndpointId=$m.EndpointId;Next='Restart Windows manually.'}
    }finally{if($handles){foreach($k in $handles.Values){$k.Dispose()}};if($base){$base.Dispose()};if($mutex){$mutex.ReleaseMutex();$mutex.Dispose()}}
}
function Invoke-LeqState {
    param([Parameter(Mandatory)][string]$BackupDirectory,[ValidateSet('On','Off','Toggle')][string]$State,[switch]$Apply)
    $b=Read-LeqBackup $BackupDirectory;$m=$b.Manifest;$base=$null;$handles=$null;$mutex=$null;$started=$false;$before=$null;$owner=$null;$c=$m.Changes[1]
    try{
        $base=Open-LeqBase;$status=Get-LeqReadiness $base $m.EndpointId
        if(!$status.ProfileMatched -or $status.Configuration -ne 'Configured'){throw 'Current configuration no longer matches the supported installed profile.'}
        $null=Assert-LeqMicrosoftComponent $base
        if($null -ne $b.Ownership.Pending){throw 'An interrupted switch is pending; use guarded Restore-MicrosoftLeq, not another switch.'}
        $now=@(Read-LeqCurrent $base $m.Changes)
        if(!(Test-LeqEqual $now[0] $m.Changes[0].After) -or !(Test-LeqEqual $now[2] $m.Changes[2].After) -or !(Test-LeqEqual $now[1] (Get-LeqEnabledValue ($b.Ownership.Current -ceq 'On')))){throw 'Configuration differs from the recorded owned state.'}
        $next=if($State -eq 'Toggle'){if($b.Ownership.Current -ceq 'On'){'Off'}else{'On'}}else{$State.Substring(0,1).ToUpperInvariant()+$State.Substring(1).ToLowerInvariant()}
        if(!$Apply){return [pscustomobject]@{DryRun=$true;From=$b.Ownership.Current;To=$next;RegistryWrites=0}}
        Assert-LeqAdmin;$mutex=Enter-LeqLock $m.EndpointId
        $locked=Read-LeqBackup $b.Directory
        if(!(Test-LeqEqual $locked.Ownership $b.Ownership)){throw 'Ownership journal changed; retry after inspecting status.'}
        $handles=Open-LeqHandles $base @($c)
        if(!(Test-LeqEqual (@(Read-LeqCurrent $base $m.Changes)) $now)){throw 'Configuration changed during switch preflight.'}
        if($next -ceq $b.Ownership.Current){return [pscustomobject]@{State=$next;RegistryValuesChanged=0}}
        $protected=@(Get-LeqProtectedState $base $m.EndpointId @($c));$before=$now[1]
        $owner=$b.Ownership;$owner.Pending=$next
        Save-LeqJson (Join-Path $b.Directory 'ownership.json') $owner
        $after=Get-LeqEnabledValue ($next -ceq 'On');$started=$true
        Write-LeqValue $handles[$c.Path] $c.Name $after
        if(!(Test-LeqEqual (Read-LeqValue $handles[$c.Path] $c.Name) $after)){throw 'Switch readback mismatch.'}
        if(!(Test-LeqEqual (@(Get-LeqProtectedState $base $m.EndpointId @($c))) $protected)){throw 'Unrelated state changed during switch.'}
        $owner.Current=$next;$owner.Pending=$null
        Save-LeqJson (Join-Path $b.Directory 'ownership.json') $owner
        ((Get-Date -Format o)+' STATE '+$next)|Add-Content -LiteralPath (Join-Path $b.Directory 'operations.log') -Encoding UTF8
        [pscustomobject]@{LeqConfiguredState=$next;RegistryValuesChanged=1;ProcessingVerified=$false;Next='Reopen the playback application; restart Windows manually if needed. No service was restarted.'}
    }catch{
        $reason=$_.Exception.Message
        if($started -and $handles -and $before){
            $live=Read-LeqValue $handles[$c.Path] $c.Name
            if(!(Test-LeqEqual $live $before) -and !(Test-LeqEqual $live (Get-LeqEnabledValue ($next -ceq 'On')))){throw "Switch failed: $reason; unknown third value, no overwrite. Stop and inspect $($b.Directory)."}
            if(!(Test-LeqEqual $live $before)){Write-LeqValue $handles[$c.Path] $c.Name $before}
            if(!(Test-LeqEqual (Read-LeqValue $handles[$c.Path] $c.Name) $before)){throw 'Switch rollback readback failed.'}
            $owner.Current=Get-LeqEnableState $before;$owner.Pending=$null;Save-LeqJson (Join-Path $b.Directory 'ownership.json') $owner
        };throw $reason
    }finally{if($handles){foreach($k in $handles.Values){$k.Dispose()}};if($base){$base.Dispose()};if($mutex){$mutex.ReleaseMutex();$mutex.Dispose()}}
}
Export-ModuleMember -Function Get-LeqDevices,Get-LeqReadiness,Open-LeqBase,Invoke-LeqInstall,Invoke-LeqRestore,Invoke-LeqState
