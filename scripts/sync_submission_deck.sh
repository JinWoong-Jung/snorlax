#!/bin/sh
# Rebuild v7 from the preserved v5 deck, retaining its inspected object anchors.
set -eu
cd "$(dirname "$0")/.."
artifact_runtime=${JAMMANBO_ARTIFACT_RUNTIME:-"$HOME/.cache/codex-runtimes/codex-primary-runtime"}
export JAMMANBO_ARTIFACT_RUNTIME="$artifact_runtime"
export RUNTIME_NODE_MODULES="$artifact_runtime/dependencies/node/node_modules"
build_dir=$(mktemp -d "${TMPDIR:-/tmp}/jammanbo-uiux.XXXXXX")
ln -s "$RUNTIME_NODE_MODULES" "$build_dir/node_modules"
cp scripts/sync_submission_deck.mjs "$build_dir/build.mjs"
"$artifact_runtime/dependencies/node/bin/node" "$build_dir/build.mjs" "$PWD/output/pptx/02_Jammanbo_UIUX_v5.pptx" "$build_dir"
cp "$build_dir/final/02_Jammanbo_UIUX_v7.pptx" output/pptx/02_Jammanbo_UIUX_v7.pptx
cp "$build_dir/final/02_Jammanbo_UIUX_v7.pptx" 02_Jammanbo_UIUX.pptx
printf 'Validated deck copied. Inspect rendered slides before PDF export: %s/build\n' "$build_dir"
