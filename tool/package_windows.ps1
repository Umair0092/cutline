# Builds Cutline for Windows and makes an installer in build\dist\ with
# Inno Setup (choco install innosetup).
#
# Signing happens when these are set (otherwise Windows SmartScreen warns
# on other PCs):
#   WINDOWS_CERT_PATH      path to a code signing .pfx
#   WINDOWS_CERT_PASSWORD  its password
#
# Run tool\fetch_ffmpeg_windows.ps1 and tool\fetch_whisper_windows.ps1 first.
$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')

$version = (Select-String -Path pubspec.yaml -Pattern '^version: ([0-9.]+)').Matches[0].Groups[1].Value
flutter build windows --release
if ($LASTEXITCODE -ne 0) { throw 'flutter build failed' }
$release = Resolve-Path 'build\windows\x64\runner\Release'
New-Item -ItemType Directory -Force -Path 'build\dist' | Out-Null
$dist = Resolve-Path 'build\dist'

function Sign-File($file) {
  if (-not $env:WINDOWS_CERT_PATH) { return }
  $signtool = Get-ChildItem 'C:\Program Files (x86)\Windows Kits\10\bin' -Recurse -Filter signtool.exe |
    Where-Object { $_.FullName -match 'x64' } | Select-Object -Last 1
  & $signtool.FullName sign /fd SHA256 /tr http://timestamp.digicert.com /td SHA256 `
    /f $env:WINDOWS_CERT_PATH /p $env:WINDOWS_CERT_PASSWORD $file
  if ($LASTEXITCODE -ne 0) { throw "signing $file failed" }
}

if ($env:WINDOWS_CERT_PATH) {
  Get-ChildItem $release -Recurse -Include *.exe, *.dll | ForEach-Object { Sign-File $_.FullName }
} else {
  Write-Host 'No WINDOWS_CERT_PATH: the installer is unsigned (SmartScreen will warn).'
}

$iscc = 'C:\Program Files (x86)\Inno Setup 6\ISCC.exe'
& $iscc "/DAppVersion=$version" "/DSourceDir=$release" "/DOutputDir=$dist" windows\installer\cutline.iss
if ($LASTEXITCODE -ne 0) { throw 'Inno Setup failed' }
$setup = Join-Path $dist "Cutline-$version-windows-setup.exe"
Sign-File $setup
Write-Host "Made $setup"
