# Equicord + StreamDraw installer for Windows.
# Usage: irm __SD_DOWNLOAD_BASE__/install.ps1 | iex
#
# Downloads the StreamDraw build of Equicord, then lets the official Equicord installer
# (Equilotl) patch Discord to load it. Afterwards Equicord updates itself from
# __SD_REPO_URL__ including upstream Equicord changes.

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'  # makes Invoke-WebRequest much faster

$base = '__SD_DOWNLOAD_BASE__'
$dir = Join-Path $env:APPDATA 'Equicord'
$asar = Join-Path $dir 'equicord.asar'
$cliName = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'EquilotlCli-arm64.exe' } else { 'EquilotlCli.exe' }
$cli = Join-Path $env:TEMP $cliName

New-Item -ItemType Directory -Force -Path $dir | Out-Null

Write-Host 'Downloading Equicord with StreamDraw...'
Invoke-WebRequest -UseBasicParsing -Uri "$base/desktop.asar" -OutFile "$asar.download"

Write-Host 'Downloading the official Equicord installer...'
Invoke-WebRequest -UseBasicParsing -Uri "https://github.com/Equicord/Equilotl/releases/latest/download/$cliName" -OutFile $cli

# Discord keeps the old build open while running
Get-Process -Name 'Discord' -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 2
Move-Item -Force "$asar.download" $asar

Write-Host 'Patching Discord...'
$env:EQUICORD_DEV_INSTALL = '1'   # use our build instead of downloading the official one
$env:EQUICORD_DIRECTORY = $asar
& $cli --install --branch auto
$code = $LASTEXITCODE
Remove-Item Env:EQUICORD_DEV_INSTALL, Env:EQUICORD_DIRECTORY
Remove-Item -Force $cli -ErrorAction SilentlyContinue
if ($code -ne 0) { throw "The Equicord installer failed (exit code $code)." }

$update = Join-Path $env:LOCALAPPDATA 'Discord\Update.exe'
if (Test-Path $update) { Start-Process -FilePath $update -ArgumentList '--processStart', 'Discord.exe' }

Write-Host ''
Write-Host 'Done! Discord now runs Equicord with StreamDraw and keeps itself updated.' -ForegroundColor Green
Write-Host 'Enable StreamDraw under Settings > Equicord > Plugins, then click a relay invite link.'
