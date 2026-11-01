# Downloads an LGPL ffmpeg.exe for Windows into third_party\ffmpeg\windows\.
# The build is from https://github.com/BtbN/FFmpeg-Builds (LGPL variant:
# no GPL parts; H.264 via NVENC/QSV/AMF hardware or OpenH264 in software).
#
# BtbN deletes old dated builds after a while. If the download 404s, pick a
# newer "autobuild-*" release, and update $Url and $Sha256 from its
# win64-lgpl zip (the release page lists each file's sha256).
$ErrorActionPreference = 'Stop'

$Url = 'https://github.com/BtbN/FFmpeg-Builds/releases/download/autobuild-2026-10-31-12-59/ffmpeg-n9.0.2-39-g7adfbe40dc-win64-lgpl-9.0.zip'
$Sha256 = '9d37c564e0d01c18cde184a079fa6ef04d7d2783ada41da81d04165cc8f1a650'

$Root = Split-Path -Parent $PSScriptRoot
$Cache = Join-Path $Root 'third_party\.cache'
$Out = Join-Path $Root 'third_party\ffmpeg\windows'
New-Item -ItemType Directory -Force -Path $Cache, $Out | Out-Null

$Zip = Join-Path $Cache (Split-Path -Leaf $Url)
if (-not (Test-Path $Zip)) {
  Invoke-WebRequest -Uri $Url -OutFile "$Zip.tmp"
  Move-Item "$Zip.tmp" $Zip
}
$Actual = (Get-FileHash -Algorithm SHA256 $Zip).Hash.ToLower()
if ($Actual -ne $Sha256) {
  Remove-Item $Zip
  throw "sha256 mismatch for $Zip (got $Actual)"
}

$Extract = Join-Path $Cache 'ffmpeg-win'
if (Test-Path $Extract) { Remove-Item -Recurse -Force $Extract }
Expand-Archive -Path $Zip -DestinationPath $Extract
$Exe = Get-ChildItem -Path $Extract -Recurse -Filter ffmpeg.exe | Select-Object -First 1
Copy-Item $Exe.FullName (Join-Path $Out 'ffmpeg.exe') -Force
$License = Get-ChildItem -Path $Extract -Recurse -Filter LICENSE.txt | Select-Object -First 1
if ($License) { Copy-Item $License.FullName (Join-Path $Out 'LICENSE.txt') -Force }
& (Join-Path $Out 'ffmpeg.exe') -hide_banner -version | Select-Object -First 1
