# SPDX-License-Identifier: GPL-3.0-only
# No live registry access. All production transaction tests run against in-memory keys.
[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot '..\src\Leq.Common.psm1') -Force
$module=Get-Module 'Leq.Common'
$testRoot=Join-Path (Split-Path -Parent $PSScriptRoot) ('runtime\tests-'+[guid]::NewGuid().ToString('N').Substring(0,8))
[void][IO.Directory]::CreateDirectory($testRoot)
try{
    & $module {
        param($TestRoot)
        $script:Passed=0;$script:WriteCount=0;$script:InjectFailure=$null
        function Check([bool]$Condition,[string]$Message){if(!$Condition){throw "FAIL: $Message"};$script:Passed++}
        function MustFail([scriptblock]$Action,[string]$Message){$blocked=$false;try{& $Action|Out-Null}catch{$blocked=$true};Check $blocked $Message}
        function Add-FakeKey([string]$Path) {
            $k=[pscustomobject]@{Path=$Path;Bag=@{};SDDL='O:SYG:SYD:(A;;KR;;;BU)';Base=$script:FakeBase}
            $k|Add-Member ScriptMethod GetValueNames { [string[]]@($this.Bag.Keys) }
            $k|Add-Member ScriptMethod GetValueKind {param($n);[Microsoft.Win32.RegistryValueKind][Enum]::Parse([Microsoft.Win32.RegistryValueKind],$this.Bag[$n].Kind)}
            $k|Add-Member ScriptMethod GetValue {param($n,$fallback,$options);if($this.Bag.ContainsKey($n)){$this.Bag[$n].Data}else{$fallback}}
            $k|Add-Member ScriptMethod OpenSubKey {param($n,$permission,$rights);$this.Base.Nodes[$this.Path+'\'+$n]}
            $k|Add-Member ScriptMethod GetSubKeyNames {$prefix=$this.Path+'\';[string[]]@($this.Base.Nodes.Keys|Where-Object {$_.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase) -and !$_.Substring($prefix.Length).Contains('\')}|ForEach-Object {$_.Substring($prefix.Length)})}
            $k|Add-Member ScriptMethod GetAccessControl {param($sections);$s=[pscustomobject]@{SDDL=$this.SDDL};$s|Add-Member ScriptMethod GetSecurityDescriptorSddlForm {param($sections);$this.SDDL};$s}
            $k|Add-Member ScriptMethod SetValue {param($n,$data,$kind)
                $script:WriteCount++
                if($script:InjectFailure -eq $script:WriteCount){$script:InjectFailure=$null;throw 'Injected partial transaction failure.'}
                $this.Bag[$n]=[pscustomobject]@{Kind=$kind.ToString();Data=$data}
            }
            $k|Add-Member ScriptMethod DeleteValue {param($n,$required);if(!$this.Bag.ContainsKey($n)){throw 'Missing value.'};$script:WriteCount++;$this.Bag.Remove($n)}
            $k|Add-Member ScriptMethod Dispose {}
            $script:FakeBase.Nodes[$Path]=$k
            $k
        }
        function Put($Key,[string]$Name,[string]$Kind,$Data){$Key.Bag[$Name]=[pscustomobject]@{Kind=$Kind;Data=$Data}}
        function New-Fixture {
            $script:FakeBase=[pscustomobject]@{Nodes=@{};WriteAccessDenied=$false;WriteOpenMasks=[Collections.Generic.List[int]]::new()}
            $script:FakeBase|Add-Member ScriptMethod OpenSubKey {param($path,$check,$rights)
                if($null -ne $rights -and [int]$rights -eq 3){$this.WriteOpenMasks.Add([int]$rights);if($this.WriteAccessDenied){throw 'Access denied.'}}
                $this.Nodes[$path]
            }
            $script:FakeBase|Add-Member ScriptMethod Dispose {}
            $script:Id='{11111111-2222-4333-8444-555555555555}';$script:Paths=Get-LeqPaths $script:Id
            $ep=Add-FakeKey $script:Paths.Endpoint;$script:FakeFx=Add-FakeKey $script:Paths.Fx
            $script:FakeProps=Add-FakeKey ($script:Paths.Endpoint+'\Properties');$script:FakeChild=Add-FakeKey $script:Paths.Child
            Put $ep 'DeviceState' 'DWord' 1
            Put $script:FakeProps '{a45c254e-df1c-4efd-8020-67d146a850e0},2' 'String' 'Headphones'
            Put $script:FakeProps '{b3f8fa53-0004-438e-9003-51a46e139bfc},6' 'String' 'Realtek(R) Audio'
            Put $script:FakeProps '{1da5d803-d492-4edd-8c23-e0c0ffee7f0e},0' 'DWord' 3
            $format=New-Object byte[] 48;$format[0]=65;$format[4]=1;$format[8]=254;$format[9]=255;$format[10]=2;$format[28]=3
            Put $script:FakeProps '{f19f064d-082c-4e27-bc73-6882a1bb8e4c},0' 'Binary' $format
            Put $script:FakeFx ($script:FxId+'5') 'String' '{EACD2258-FCAC-4FF4-B36D-419E924A6D79}'
            Put $script:FakeFx ($script:FxId+'7') 'String' '{EC1CC9CE-FAED-4822-828A-82A81A6F018F}'
            foreach($slot in (Get-LeqExpectedComposite).Keys){Put $script:FakeFx ($script:FxId+$slot) 'MultiString' (Get-LeqExpectedComposite)[$slot]}
            Put $script:FakeChild 'Version' 'String' '2';Put $script:FakeChild 'PreMixChild' 'String' '';Put $script:FakeChild 'PostMixChild' 'String' ''
            $script:WriteCount=0;$script:InjectFailure=$null
        }
        # Replace every real-environment boundary before invoking any transaction.
        function script:Open-LeqBase {if($null -eq $script:FakeBase){throw 'Simulation backend missing.'};$script:FakeBase}
        function script:Assert-LeqAdmin {}
        function script:Assert-LeqMicrosoftComponent($Base){[pscustomobject]@{Signature='Simulated';EapoVersion='1.4.2'}}
        New-Fixture
        Check ((Get-LeqReadiness $script:FakeBase $script:Id).ProfileMatched) 'Matching fixture'
        MustFail {Resolve-LeqEndpointId 'SOFTWARE\Other'} 'Reject path injection'
        Check ((Get-LeqEnableState (Get-LeqEnabledValue $true)) -ceq 'On') 'ON decoding'
        Check ((Get-LeqEnableState (Get-LeqEnabledValue $false)) -ceq 'Off') 'OFF decoding'
        foreach($code in 2..7){Check ((Get-LeqReleaseCode (Get-LeqReleaseValue $code)) -eq $code) "Release $code encoding"}
        $dry=Invoke-LeqInstall -EndpointId $script:Id
        Check ($dry.DryRun -and $script:WriteCount -eq 0 -and $script:FakeBase.WriteOpenMasks.Count -eq 0) 'Dry-run opens no write handles'
        $script:FakeBase.WriteAccessDenied=$true
        MustFail {Invoke-LeqInstall -EndpointId $script:Id -Apply -BackupRoot $TestRoot} 'Denied access stops'
        Check ($script:WriteCount -eq 0) 'Denied access writes nothing'
        New-Fixture;Put $script:FakeProps '{1da5d803-d492-4edd-8c23-e0c0ffee7f0e},0' 'DWord' 1
        Check (!(Get-LeqReadiness $script:FakeBase $script:Id).ProfileMatched) 'Speaker blocked'
        New-Fixture;Put $script:FakeFx ($script:FxId+'14') 'MultiString' @('{00000000-0000-0000-0000-000000000000}')
        Check (!(Get-LeqReadiness $script:FakeBase $script:Id).ProfileMatched) 'Different OEM list blocked'
        New-Fixture;$null=Add-FakeKey ($script:Paths.Fx+'\{B13412EE-07AF-4C57-B08B-E327F8DB085B}')
        Check (!(Get-LeqReadiness $script:FakeBase $script:Id).ProfileMatched) 'Context mismatch blocked'
        New-Fixture;Put $script:FakeFx '{1da5d803-d492-4edd-8c23-e0c0ffee7f0e},5' 'DWord' 1
        Check (!(Get-LeqReadiness $script:FakeBase $script:Id).ProfileMatched) 'SysFx disabled blocked'
        foreach($failAt in 1,2,3){
            New-Fixture;$script:InjectFailure=$failAt
            MustFail {Invoke-LeqInstall -EndpointId $script:Id -Apply -BackupRoot $TestRoot} "Install failure $failAt"
            Check ((Get-LeqReadiness $script:FakeBase $script:Id).Configuration -ceq 'Fresh') "Partial failure $failAt rolled back"
        }
        New-Fixture
        $before=@(Get-LeqProtectedState $script:FakeBase $script:Id (Get-LeqPlan $script:Id))
        $installed=Invoke-LeqInstall -EndpointId $script:Id -Apply -BackupRoot $TestRoot
        Check ($script:WriteCount -eq 3) 'Exactly three install writes'
        Check ((@($script:FakeBase.WriteOpenMasks|Where-Object {$_ -ne 3})).Count -eq 0) 'Write mask only 0x3'
        Check (Test-LeqEqual $before (@(Get-LeqProtectedState $script:FakeBase $script:Id (Get-LeqPlan $script:Id)))) 'OEM and SDDL unchanged'
        $backup=Read-LeqBackup $installed.BackupDirectory
        foreach($mask in 0..7){
            $values=@(for($i=0;$i -lt 3;$i++){if($mask -band (1 -shl $i)){$backup.Manifest.Changes[$i].After}else{$backup.Manifest.Changes[$i].Before}})
            $actions=@(Get-LeqRestoreActions $backup.Manifest $backup.Ownership $values)
            Check ($actions.Count -eq @((0..2)|Where-Object {$mask -band (1 -shl $_)}).Count) "Restore subset $mask"
        }
        foreach($i in 0..2){
            $values=@($backup.Manifest.Changes|ForEach-Object After);$values[$i]=New-LeqValue $true 'DWord' 999
            MustFail {Get-LeqRestoreActions $backup.Manifest $backup.Ownership $values} "Unknown third state $i"
        }
        $tampered=$backup.Manifest|ConvertTo-Json -Depth 40|ConvertFrom-Json;$tampered.Changes[0].Path='SOFTWARE\Other'
        MustFail {Assert-LeqManifest $tampered} 'Backup path substitution blocked'
        $switched=Invoke-LeqState -BackupDirectory $installed.BackupDirectory -State Off -Apply
        Check ($switched.LeqConfiguredState -ceq 'Off' -and $script:WriteCount -eq 4) 'Switch changes only enable'
        $same=Invoke-LeqState -BackupDirectory $installed.BackupDirectory -State Off -Apply
        Check ($same.RegistryValuesChanged -eq 0 -and $script:WriteCount -eq 4) 'Repeated OFF does not toggle'
        Invoke-LeqRestore -BackupDirectory $installed.BackupDirectory -Apply|Out-Null
        Check ((Get-LeqReadiness $script:FakeBase $script:Id).Configuration -ceq 'Fresh') 'Restore after legitimate OFF succeeds'
        $count=$script:WriteCount;Invoke-LeqRestore -BackupDirectory $installed.BackupDirectory -Apply|Out-Null
        Check ($script:WriteCount -eq $count) 'Restore idempotent'
        New-Fixture;$installed=Invoke-LeqInstall -EndpointId $script:Id -Apply -BackupRoot $TestRoot
        Put $script:FakeFx $script:Enable 'DWord' 123;$count=$script:WriteCount
        MustFail {Invoke-LeqRestore -BackupDirectory $installed.BackupDirectory -Apply} 'Restore whole-set conflict gate'
        Check ($script:WriteCount -eq $count) 'Unknown third state causes zero rollback writes'
        New-Fixture;$installed=Invoke-LeqInstall -EndpointId $script:Id -Apply -BackupRoot $TestRoot
        $o=Read-LeqBackup $installed.BackupDirectory;$o.Ownership.Pending='Off';Save-LeqJson (Join-Path $installed.BackupDirectory 'ownership.json') $o.Ownership
        MustFail {Invoke-LeqState -BackupDirectory $installed.BackupDirectory -State Toggle -Apply} 'Pending switch blocks another switch'
        Invoke-LeqRestore -BackupDirectory $installed.BackupDirectory -Apply|Out-Null
        Check ((Get-LeqReadiness $script:FakeBase $script:Id).Configuration -ceq 'Fresh') 'Pending switch recoverable'
        New-Fixture;$null=$script:FakeBase.Nodes.Remove($script:Paths.Child)
        MustFail {Invoke-LeqInstall -EndpointId $script:Id -Apply -BackupRoot $TestRoot} 'Missing child key is never created'
        Check ($script:WriteCount -eq 0) 'Missing key writes nothing'
        New-Fixture;$installed=Invoke-LeqInstall -EndpointId $script:Id -Apply -BackupRoot $TestRoot
        $code=Get-LeqReleaseValue 3;Put $script:FakeFx $script:Release 'Binary' ([Convert]::FromBase64String($code.Data));$count=$script:WriteCount
        MustFail {Invoke-LeqState -BackupDirectory $installed.BackupDirectory -State Off -Apply} 'Untracked release edit blocks switch'
        Check ($script:WriteCount -eq $count) 'Untracked edit writes nothing'
        New-Fixture;$installed=Invoke-LeqInstall -EndpointId $script:Id -Apply -BackupRoot $TestRoot
        $script:InjectFailure=$script:WriteCount+1
        MustFail {Invoke-LeqState -BackupDirectory $installed.BackupDirectory -State Off -Apply} 'Switch failure rolls back'
        Check ((Get-LeqEnableState (Read-LeqValue $script:FakeFx $script:Enable)) -ceq 'On') 'Switch failure preserves previous ON'
        $recovered=Read-LeqBackup $installed.BackupDirectory
        Check ($recovered.Ownership.Current -ceq 'On' -and $null -eq $recovered.Ownership.Pending) 'Switch failure clears pending journal'
        $unicode=Join-Path $TestRoot 'unicode.json';Save-LeqJson $unicode ([pscustomobject]@{Label=([string][char]0x8033)+[char]0x673a})
        $decoded=Get-Content -LiteralPath $unicode -Raw -Encoding UTF8|ConvertFrom-Json
        Check ($decoded.Label -ceq (([string][char]0x8033)+[char]0x673a)) 'UTF-8 backup value roundtrip'
        Write-Output "PASS: $script:Passed checks; all registry transactions used memory keys. No live audio writes."
    } $testRoot
    $root=Split-Path -Parent $PSScriptRoot
    foreach($file in (Get-ChildItem -LiteralPath $root -Recurse -File|Where-Object {$_.Extension -in '.ps1','.psm1'})){
        $tokens=$null;$errors=$null;$ast=[Management.Automation.Language.Parser]::ParseFile($file.FullName,[ref]$tokens,[ref]$errors)
        if(@($errors).Count){throw "Parse error in $($file.Name): $($errors[0].Message)"}
        if($file.DirectoryName -notlike '*\tests'){
            $bad=$ast.FindAll({param($n) $n -is [Management.Automation.Language.InvokeMemberExpressionAst] -and $n.Member.Value -in 'CreateSubKey','DeleteSubKey','DeleteSubKeyTree','SetAccessControl','SetOwner'},$true)
            if(@($bad).Count){throw 'Forbidden registry/ACL operation in production code.'}
        }
    }
    Write-Output 'PASS: Windows PowerShell syntax and forbidden-mutation checks.'
}finally{
    Remove-Module 'Leq.Common' -Force -ErrorAction SilentlyContinue
    # Retain simulation evidence only under gitignored runtime/tests-*.
}
