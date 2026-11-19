#!/usr/bin/env bash
# Records which upstream Equicord and plugin commits the next build uses (streamdraw/versions),
# commits that if it changed, and decides whether a build is needed.
# Expects ./equicord and ./plugin to be checked out already.
set -euo pipefail

up="$(git -C equicord rev-parse HEAD)"
plugin="$(git -C plugin rev-parse HEAD)"
want="$(printf 'upstream=%s\nplugin=%s' "$up" "$plugin")"

if [[ "$(cat streamdraw/versions 2>/dev/null || true)" != "$want" ]]; then
    printf '%s\n' "$want" > streamdraw/versions
    git add streamdraw/versions
    git -c user.name="github-actions[bot]" -c user.email="41898282+github-actions[bot]@users.noreply.github.com" \
        commit --quiet -m "Equicord ${up:0:7} + StreamDraw ${plugin:0:7}"
    # pushes made with the workflow token don't trigger new workflow runs
    git push --quiet origin "HEAD:${PUSH_BRANCH:-main}"
    echo "recorded Equicord ${up:0:7} + StreamDraw ${plugin:0:7}"
fi

head="$(git rev-parse HEAD)"
latest="$(gh release view --json name --jq .name 2>/dev/null || true)"

build=true
if [[ "$latest" == *" $head" && "${FORCE:-false}" != "true" ]]; then
    build=false
    echo "already released ${head:0:12}, nothing to do"
fi

{
    echo "head=$head"
    echo "build=$build"
} >> "${GITHUB_OUTPUT:-/dev/stdout}"
