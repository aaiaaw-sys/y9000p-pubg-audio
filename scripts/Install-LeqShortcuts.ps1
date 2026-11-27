# SPDX-License-Identifier: GPL-3.0-only
[CmdletBinding()]
param([Parameter(Mandatory)][string]$BackupDirectory,[switch]$Apply)
$ErrorActionPreference='Stop'
$backup=(Get-Item -LiteralPath $BackupDirectory -ErrorAction Stop).FullName
Import-Module (Join-Path $PSScriptRoot '..\src\Leq.Common.psm1') -Force
# Read-only validation also refuses an unknown third value before offering shortcuts.
$null=Invoke-LeqRestore -BackupDirectory $backup
$desktop=[Environment]::GetFolderPath('Desktop')
$items=@('Y9000P LEQ Toggle.lnk','Y9000P Audio Status.lnk')
foreach($item in $items){if(Test-Path -LiteralPath (Join-Path $desktop $item)){throw 'A project shortcut already exists. Remove it explicitly before reinstalling.'}}
if(!$Apply){Write-Output 'DRY RUN: create two desktop shortcuts. Toggle requests UAC on each use. No scheduled task or audio setting changes.';return}
$manifest=Get-Content -LiteralPath (Join-Path $backup 'backup.json') -Raw -Encoding UTF8|ConvertFrom-Json
$exe=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$shell=New-Object -ComObject WScript.Shell
for($i=0;$i -lt 2;$i++){
    $link=$shell.CreateShortcut((Join-Path $desktop $items[$i]));$link.TargetPath=$exe
    if($i -eq 0){$link.Arguments='-NoProfile -WindowStyle Hidden -File "'+(Join-Path $PSScriptRoot 'Invoke-LeqToggle.ps1')+'" -BackupDirectory "'+$backup+'"'}
    else{$link.Arguments='-NoProfile -NoExit -File "'+(Join-Path $PSScriptRoot 'Get-AudioStatus.ps1')+'" -EndpointId "'+$manifest.EndpointId+'"'}
    $link.WorkingDirectory=Split-Path -Parent $PSScriptRoot;$link.Description='Y9000P PUBG Audio - Microsoft LEQ';$link.Save()
}
Write-Output 'Created two shortcuts; keep this repository and its private backup at the same paths. Remove the two .lnk files to uninstall shortcuts only.'
