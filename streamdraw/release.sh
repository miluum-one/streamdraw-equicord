#!/usr/bin/env bash
# Publishes the build as the latest release and prunes old ones.
# Equicord's updater compares the last word of the release title with its own commit hash.
set -euo pipefail
: "${HEAD_SHA:?}" "${GITHUB_REPOSITORY:?}"

keep="${KEEP_RELEASES:-5}"
tag="build-${HEAD_SHA:0:12}"
repo_url="https://github.com/${GITHUB_REPOSITORY}"
download="${repo_url}/releases/latest/download"
up="$(sed -n 's/^upstream=//p' streamdraw/versions)"
plugin="$(sed -n 's/^plugin=//p' streamdraw/versions)"

out="$(mktemp -d)"
cp equicord/dist/desktop.asar equicord/dist/equibop.asar "$out/"
for f in install.ps1 install.sh; do
    sed -e "s#__SD_DOWNLOAD_BASE__#${download}#g" -e "s#__SD_REPO_URL__#${repo_url}#g" "streamdraw/$f" > "$out/$f"
done

notes="Equicord [\`${up:0:7}\`](https://github.com/Equicord/Equicord/commit/${up}) with StreamDraw \`${plugin:0:7}\`.

Install on Windows (PowerShell):
\`\`\`
irm ${download}/install.ps1 | iex
\`\`\`
Install on macOS (Terminal):
\`\`\`
curl -fsSL ${download}/install.sh | sh
\`\`\`"

# a forced rebuild of the same commit replaces its release
gh release delete "$tag" --cleanup-tag --yes 2>/dev/null || true
gh release create "$tag" --target "$HEAD_SHA" --title "Equicord StreamDraw ${HEAD_SHA}" \
    --notes "$notes" --latest "$out"/*
echo "released ${tag}"

gh release list --limit 100 --json tagName,createdAt \
    --jq 'sort_by(.createdAt) | reverse | .[].tagName' \
    | grep '^build-' | tail -n +"$((keep + 1))" \
    | while read -r old; do
        echo "pruning ${old}"
        gh release delete "$old" --cleanup-tag --yes
    done
