# SPDX-License-Identifier: GPL-3.0-only
[CmdletBinding()]
param([string]$EndpointId,[switch]$Json)
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot '..\src\Leq.Common.psm1') -Force
if($EndpointId){$base=Open-LeqBase;try{$result=Get-LeqReadiness $base $EndpointId}finally{$base.Dispose()}}
else{$result=@(Get-LeqDevices)}
if($Json){$result|ConvertTo-Json -Depth 12}else{$result|Format-List}
