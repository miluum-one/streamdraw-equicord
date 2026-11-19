#!/usr/bin/env bash
# Builds standalone Equicord with the plugin baked in. The build is stamped with this repo's
# commit and name, so Equicord's own updater looks for new releases here.
set -euo pipefail
: "${HEAD_SHA:?}"

dest=equicord/src/userplugins/streamDraw
rm -rf "$dest"
mkdir -p "$dest"
tar -C plugin --exclude=.git --exclude=.github --exclude=relay -cf - . | tar -C "$dest" -xf -

cd equicord
if [[ -z "${SKIP_PNPM_SETUP:-}" ]]; then
    npm install -g --silent "$(node -p "require('./package.json').packageManager")"
    pnpm config set store-dir "$HOME/.pnpm-store"
fi
pnpm install --frozen-lockfile
EQUICORD_HASH="$HEAD_SHA" EQUICORD_REMOTE="${GITHUB_REPOSITORY:?}" pnpm buildStandalone

for f in dist/desktop.asar dist/equibop.asar; do
    [[ -s "$f" ]] || { echo "missing build output $f" >&2; exit 1; }
done
