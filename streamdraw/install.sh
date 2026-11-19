#!/bin/sh
# Equicord + StreamDraw installer for macOS.
# Usage: curl -fsSL __SD_DOWNLOAD_BASE__/install.sh | sh
#
# Downloads the StreamDraw build of Equicord, then lets the official Equicord installer
# (Equilotl) patch Discord to load it. Afterwards Equicord updates itself from
# __SD_REPO_URL__ including upstream Equicord changes.
set -eu

base='__SD_DOWNLOAD_BASE__'

if [ "$(uname)" != "Darwin" ]; then
    echo "This installer is for macOS. On Windows run: irm $base/install.ps1 | iex"
    exit 1
fi
if [ "$(id -u)" -eq 0 ]; then
    echo "Run this as your normal user, not with sudo."
    exit 1
fi

dir="$HOME/Library/Application Support/Equicord"
asar="$dir/equicord.asar"
case "$(uname -m)" in
    arm64) cli_name=EquilotlCli-arm64 ;;
    *) cli_name=EquilotlCli-x64 ;;
esac

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$dir"

echo "Downloading Equicord with StreamDraw..."
curl -fsSL "$base/desktop.asar" -o "$tmp/desktop.asar"

echo "Downloading the official Equicord installer..."
curl -fsSL "https://github.com/Equicord/Equilotl/releases/latest/download/$cli_name" -o "$tmp/equilotl"
chmod +x "$tmp/equilotl"

# Discord keeps the old build open while running
osascript -e 'quit app "Discord"' >/dev/null 2>&1 || true
sleep 2
mv -f "$tmp/desktop.asar" "$asar"

echo "Patching Discord..."
# EQUICORD_DEV_INSTALL: use our build instead of downloading the official one
EQUICORD_DEV_INSTALL=1 EQUICORD_DIRECTORY="$asar" "$tmp/equilotl" --install --branch auto

open -a Discord >/dev/null 2>&1 || true

echo
echo "Done! Discord now runs Equicord with StreamDraw and keeps itself updated."
echo "Enable StreamDraw under Settings > Equicord > Plugins, then click a relay invite link."
