# SPDX-License-Identifier: GPL-3.0-only
[CmdletBinding()]
param([Parameter(Mandatory)][string]$BackupDirectory)
# Explicit shortcut action: normal UAC prompt every time. No stored elevated task.
$ErrorActionPreference='Stop'
function Show-Result([string]$Message,[int]$Icon){$shell=New-Object -ComObject WScript.Shell;$null=$shell.Popup($Message,15,'Microsoft LEQ',$Icon)}
try{
    $principal=[Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
    if(!$principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){
        # EncodedCommand contains only an escaped literal invocation, no user-provided executable.
        $scriptLiteral=$PSCommandPath.Replace("'","''");$backupLiteral=$BackupDirectory.Replace("'","''")
        $command="& '$scriptLiteral' -BackupDirectory '$backupLiteral'"
        $encoded=[Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command))
        $exe=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
        $proc=Start-Process -FilePath $exe -ArgumentList @('-NoProfile','-EncodedCommand',$encoded) -Verb RunAs -WindowStyle Hidden -Wait -PassThru
        if($proc.ExitCode -ne 0){throw 'Elevated toggle failed or was cancelled.'};exit 0
    }
    Import-Module (Join-Path $PSScriptRoot '..\src\Leq.Common.psm1') -Force
    $result=Invoke-LeqState -BackupDirectory $BackupDirectory -State Toggle -Apply
    Show-Result ("LEQ configuration: "+$result.LeqConfiguredState+"`nReopen playback if needed. No audio service was restarted.") 64
}catch{Show-Result $_.Exception.Message 16;exit 1}
