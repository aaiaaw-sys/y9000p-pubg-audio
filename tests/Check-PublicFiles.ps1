# SPDX-License-Identifier: GPL-3.0-only
[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$files=@(Get-ChildItem -LiteralPath $root -Recurse -File -Force|Where-Object {
    $relative=$_.FullName.Substring($root.Length+1)
    $relative -notmatch '^(\.git|runtime|dist)[\\/]'
})
if($files.Count -lt 15){throw 'Unexpectedly incomplete project.'}
foreach($file in $files){
    if($file.Extension -in '.dll','.exe','.zip','.reg','.clixml','.log' -or $file.Name -in 'backup.json','ownership.json','backup.sha256'){throw ('Private/binary artifact in public tree: '+$file.Name)}
    $text=[IO.File]::ReadAllText($file.FullName)
    # Patterns are general; no real owner's identifiers are embedded in this checker.
    if($text -match '(?i)[A-Z]:\\Users\\(?!Public(?:\\|$)|<)[^\\\r\n]+\\' -or $text -match 'S-1-5-21-\d+-\d+-\d+-\d+') {throw ('Machine-specific path/SID found: '+$file.Name)}
    if($file.Extension -eq '.md'){
        foreach($link in [regex]::Matches($text,'(?<!!)\[[^\]]+\]\(([^\s\)]+)\)')){
            $target=$link.Groups[1].Value
            if($target -match '^[a-z]+:' -or $target.StartsWith('#')){continue}
            $path=($target -split '#')[0]
            if($path -and !(Test-Path -LiteralPath (Join-Path $file.DirectoryName $path))){throw "Broken relative link in $($file.Name): $path"}
        }
    }
}
Write-Output "PASS: $($files.Count) public files; relative document links and privacy/binary checks."
