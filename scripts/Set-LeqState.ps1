# SPDX-License-Identifier: GPL-3.0-only
[CmdletBinding()]
param([Parameter(Mandatory)][string]$BackupDirectory,[Parameter(Mandatory)][ValidateSet('On','Off','Toggle')][string]$State,[switch]$Apply)
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot '..\src\Leq.Common.psm1') -Force
Invoke-LeqState @PSBoundParameters
