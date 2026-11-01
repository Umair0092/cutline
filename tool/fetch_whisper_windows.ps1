# Downloads whisper.cpp's command-line tool for Windows (MIT licence) into
# third_party\whisper\windows\: whisper-cli.exe and the DLLs it needs, from
# the official release build that matches tool/build_whisper_macos.sh.
$ErrorActionPreference = 'Stop'

$Url = 'https://github.com/ggml-org/whisper.cpp/releases/download/b5454/whisper-bin-x64.zip'
$Sha256 = '6ba69e3482d7826214f90a6a9c84ca07782aec1e1d0c6a7c30c994fd5d816ccb'

$Root = Split-Path -Parent $PSScriptRoot
$Cache = Join-Path $Root 'third_party\.cache'
$Out = Join-Path $Root 'third_party\whisper\windows'
New-Item -ItemType Directory -Force -Path $Cache, $Out | Out-Null

$Zip = Join-Path $Cache 'whisper-bin-x64-b5454.zip'
if (-not (Test-Path $Zip)) {
  Invoke-WebRequest -Uri $Url -OutFile "$Zip.tmp"
  Move-Item "$Zip.tmp" $Zip
}
$Actual = (Get-FileHash -Algorithm SHA256 $Zip).Hash.ToLower()
if ($Actual -ne $Sha256) {
  Remove-Item $Zip
  throw "sha256 mismatch for $Zip (got $Actual)"
}

$Extract = Join-Path $Cache 'whisper-win'
if (Test-Path $Extract) { Remove-Item -Recurse -Force $Extract }
Expand-Archive -Path $Zip -DestinationPath $Extract
$Cli = Get-ChildItem -Path $Extract -Recurse -Filter whisper-cli.exe | Select-Object -First 1
if (-not $Cli) { throw 'whisper-cli.exe not found in the release zip' }
Get-ChildItem -Path $Cli.DirectoryName -Include *.exe, *.dll -Recurse |
  Where-Object { $_.Name -eq 'whisper-cli.exe' -or $_.Extension -eq '.dll' } |
  ForEach-Object { Copy-Item $_.FullName $Out -Force }
& (Join-Path $Out 'whisper-cli.exe') --help | Select-Object -First 2
