# SPDX-License-Identifier: GPL-3.0-only
[CmdletBinding()]
param([string]$OutputDirectory,[switch]$Apply)
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
& (Join-Path $root 'tests\Check-PublicFiles.ps1')
$files=@(& git -C $root ls-files)
if($LASTEXITCODE -ne 0 -or $files.Count -lt 15){throw 'Stage and review the public source files before packaging.'}
foreach($name in $files){
    if($name -match '^(runtime|dist|\.git)/' -or [IO.Path]::IsPathRooted($name) -or $name -match '(^|/)\.\.(/|$)'){throw 'Unexpected tracked file.'}
    $file=Get-Item -LiteralPath (Join-Path $root $name)
    if($file.Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'Do not package symbolic links/reparse points.'}
}
if(!$OutputDirectory){$OutputDirectory=Join-Path $root 'dist'}
$zip=Join-Path ([IO.Path]::GetFullPath($OutputDirectory)) 'y9000p-pubg-audio-0.1.0.zip'
if(Test-Path -LiteralPath $zip){throw 'Archive already exists; choose a new output directory, no overwrite.'}
if(!$Apply){[pscustomobject]@{DryRun=$true;Files=$files.Count;Output=$zip};return}
[void][IO.Directory]::CreateDirectory((Split-Path -Parent $zip))
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$stream=[IO.File]::Open($zip,[IO.FileMode]::CreateNew)
$archive=[IO.Compression.ZipArchive]::new($stream,[IO.Compression.ZipArchiveMode]::Create,$false)
try{foreach($name in $files){$null=[IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive,(Join-Path $root $name),('y9000p-pubg-audio/'+$name),[IO.Compression.CompressionLevel]::Optimal)}}finally{$archive.Dispose();$stream.Dispose()}
$hash=Get-FileHash -LiteralPath $zip -Algorithm SHA256
($hash.Hash+'  '+[IO.Path]::GetFileName($zip))|Set-Content -LiteralPath ($zip+'.sha256') -Encoding ASCII
[pscustomobject]@{Archive=$zip;Files=$files.Count;SHA256=$hash.Hash;Published=$false}
