# SPDX-License-Identifier: GPL-3.0-only
[CmdletBinding()]
param([Parameter(Mandatory)][string]$EndpointId,[ValidateRange(2,7)][int]$ReleaseCode=4,[string]$BackupRoot,[switch]$Apply)
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot '..\src\Leq.Common.psm1') -Force
Invoke-LeqInstall @PSBoundParameters
