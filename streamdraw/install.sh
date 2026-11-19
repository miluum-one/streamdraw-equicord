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

# stdin is the script itself when piped from curl, so questions go through the terminal
ask() {
    printf '%s ' "$1" > /dev/tty 2>/dev/null || true
    answer=""
    read -r answer < /dev/tty 2>/dev/null || true
}

# ---- which Discord? ---------------------------------------------------------------------
# branch|app name|support folder name

candidates="stable|Discord|discord
ptb|Discord PTB|discordptb
canary|Discord Canary|discordcanary"

found=""
count=0
while IFS='|' read -r branch name support; do
    app=""
    for apps_dir in /Applications "$HOME/Applications"; do
        if [ -d "$apps_dir/$name.app" ]; then app="$apps_dir/$name.app"; break; fi
    done
    # newer Discord builds can live in a versioned folder under Application Support
    if [ -z "$app" ]; then
        # shellcheck disable=SC2012 # glob of known-safe names
        app="$(ls -d "$HOME/Library/Application Support/$support/"*/"$name.app" 2>/dev/null | tail -n 1 || true)"
    fi
    [ -n "$app" ] || continue
    count=$((count + 1))
    found="$found$branch|$name|$support|$app
"
done <<EOF
$candidates
EOF

if [ "$count" -eq 0 ]; then
    echo "No Discord installation found. Install Discord from https://discord.com/download first."
    exit 1
fi

pick=1
if [ "$count" -gt 1 ]; then
    echo "Several Discord versions are installed. Which one should get Equicord + StreamDraw?"
    i=0
    printf '%s' "$found" | while IFS='|' read -r branch name support app; do
        i=$((i + 1))
        echo "  [$i] $name"
    done
    ask "Number (Enter = 1):"
    if [ -n "$answer" ]; then
        case "$answer" in
            *[!0-9]*) echo "'$answer' isn't one of the options."; exit 1 ;;
        esac
        if [ "$answer" -lt 1 ] || [ "$answer" -gt "$count" ]; then
            echo "'$answer' isn't one of the options."
            exit 1
        fi
        pick="$answer"
    fi
fi

target="$(printf '%s' "$found" | sed -n "${pick}p")"
branch="${target%%|*}"
rest="${target#*|}"
name="${rest%%|*}"
rest="${rest#*|}"
support="${rest%%|*}"
app="${rest#*|}"
echo "Installing into $name ($app)."

# ---- BetterDiscord? ---------------------------------------------------------------------
# BetterDiscord injects through discord_desktop_core/index.js, which the Equicord
# installer doesn't look at. Running both mods at once tends to break Discord.

support_dir="$HOME/Library/Application Support/$support"
if [ -d "$support_dir" ] && find "$support_dir" -maxdepth 4 -path '*discord_desktop_core/index.js' -exec grep -qi betterdiscord {} \; -print 2>/dev/null | grep -q .; then
    echo
    echo "BetterDiscord is installed in $name."
    echo "Running it together with Equicord usually breaks Discord. Uninstall it first with the"
    echo "BetterDiscord installer (https://betterdiscord.app), then run this again."
    ask "Install anyway? [y/N]"
    case "$answer" in
        y | Y | yes | YES) ;;
        *) echo "Cancelled."; exit 0 ;;
    esac
fi

# ---- download ---------------------------------------------------------------------------

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

# ---- install ----------------------------------------------------------------------------

# Discord keeps the old build open while running
osascript -e "quit app \"$name\"" >/dev/null 2>&1 || true
sleep 2
mv -f "$tmp/desktop.asar" "$asar"

echo "Patching Discord..."
# EQUICORD_DEV_INSTALL: use our build instead of downloading the official one
EQUICORD_DEV_INSTALL=1 EQUICORD_DIRECTORY="$asar" "$tmp/equilotl" --install --branch "$branch"

open -a "$name" >/dev/null 2>&1 || open "$app" >/dev/null 2>&1 || true

echo
echo "Done! $name now runs Equicord with StreamDraw and keeps itself updated."
echo "Enable StreamDraw under Settings > Equicord > Plugins, then click a relay invite link."
