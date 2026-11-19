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

function Confirm-Choice([string]$question) {
    $answer = Read-Host "$question [y/N]"
    return $answer -match '^(y|yes)$'
}

# ---- which Discord? ------------------------------------------------------------------

$branches = @(
    @{ Branch = 'stable'; Name = 'Discord'; Folder = 'Discord'; Exe = 'Discord' },
    @{ Branch = 'ptb'; Name = 'Discord PTB'; Folder = 'DiscordPTB'; Exe = 'DiscordPTB' },
    @{ Branch = 'canary'; Name = 'Discord Canary'; Folder = 'DiscordCanary'; Exe = 'DiscordCanary' }
)

$installed = @()
foreach ($b in $branches) {
    $root = Join-Path $env:LOCALAPPDATA $b.Folder
    $app = Get-ChildItem -Path $root -Directory -Filter 'app-*' -ErrorAction SilentlyContinue |
        Where-Object { (Test-Path (Join-Path $_.FullName 'resources\app.asar')) -or (Test-Path (Join-Path $_.FullName 'resources\_app.asar')) } |
        Sort-Object { [version]($_.Name -replace '^app-', '') } -Descending |
        Select-Object -First 1
    if ($app) { $installed += $b + @{ Root = $root; App = $app.FullName } }
}

if ($installed.Count -eq 0) {
    throw 'No Discord installation found. Install Discord from https://discord.com/download first.'
}

$target = $installed[0]
if ($installed.Count -gt 1) {
    Write-Host 'Several Discord versions are installed. Which one should get Equicord + StreamDraw?'
    for ($i = 0; $i -lt $installed.Count; $i++) { Write-Host "  [$($i + 1)] $($installed[$i].Name)" }
    $pick = Read-Host "Number (Enter = 1)"
    if ($pick -match '^\d+$' -and [int]$pick -ge 1 -and [int]$pick -le $installed.Count) {
        $target = $installed[[int]$pick - 1]
    } elseif ($pick) {
        throw "'$pick' isn't one of the options."
    }
}
Write-Host "Installing into $($target.Name)."

# ---- BetterDiscord? ------------------------------------------------------------------
# BetterDiscord injects through discord_desktop_core\index.js, which the Equicord
# installer doesn't look at. Running both mods at once tends to break Discord.

$coreIndex = Get-ChildItem -Path (Join-Path $target.App 'modules') -Directory -Filter 'discord_desktop_core-*' -ErrorAction SilentlyContinue |
    ForEach-Object { Join-Path $_.FullName 'discord_desktop_core\index.js' } |
    Where-Object { Test-Path $_ }
$hasBetterDiscord = $false
foreach ($f in $coreIndex) {
    if ((Get-Content -Raw -Path $f) -match 'betterdiscord') { $hasBetterDiscord = $true }
}
if ($hasBetterDiscord) {
    Write-Host ''
    Write-Host "BetterDiscord is installed in $($target.Name)." -ForegroundColor Yellow
    Write-Host 'Running it together with Equicord usually breaks Discord. Uninstall it first with the'
    Write-Host 'BetterDiscord installer (https://betterdiscord.app), then run this again.'
    if (-not (Confirm-Choice 'Install anyway?')) { Write-Host 'Cancelled.'; return }
}

# ---- download --------------------------------------------------------------------------

New-Item -ItemType Directory -Force -Path $dir | Out-Null

Write-Host 'Downloading Equicord with StreamDraw...'
Invoke-WebRequest -UseBasicParsing -Uri "$base/desktop.asar" -OutFile "$asar.download"

Write-Host 'Downloading the official Equicord installer...'
Invoke-WebRequest -UseBasicParsing -Uri "https://github.com/Equicord/Equilotl/releases/latest/download/$cliName" -OutFile $cli

# ---- install ---------------------------------------------------------------------------

# Discord keeps the old build open while running
Get-Process -Name $target.Exe -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 2
Move-Item -Force "$asar.download" $asar

Write-Host 'Patching Discord...'
$env:EQUICORD_DEV_INSTALL = '1'   # use our build instead of downloading the official one
$env:EQUICORD_DIRECTORY = $asar
& $cli --install --branch $target.Branch
$code = $LASTEXITCODE
Remove-Item Env:EQUICORD_DEV_INSTALL, Env:EQUICORD_DIRECTORY
Remove-Item -Force $cli -ErrorAction SilentlyContinue
if ($code -ne 0) { throw "The Equicord installer failed (exit code $code)." }

$update = Join-Path $target.Root 'Update.exe'
if (Test-Path $update) { Start-Process -FilePath $update -ArgumentList '--processStart', "$($target.Exe).exe" }

Write-Host ''
Write-Host "Done! $($target.Name) now runs Equicord with StreamDraw and keeps itself updated." -ForegroundColor Green
Write-Host 'Enable StreamDraw under Settings > Equicord > Plugins, then click a relay invite link.'
