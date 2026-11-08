#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
artifact_runtime=${JAMMANBO_ARTIFACT_RUNTIME:-"$HOME/.cache/codex-runtimes/codex-primary-runtime"}
artifact_python="$artifact_runtime/dependencies/python/bin/python3.12"
artifact_soffice="$artifact_runtime/dependencies/bin/override/soffice"
artifact_render="$artifact_runtime/plugins/openai-primary-runtime/plugins/documents/skills/documents/render_docx.py"
if [ ! -x "$artifact_python" ] || [ ! -x "$artifact_soffice" ] || [ ! -f "$artifact_render" ]; then
  echo 'Codex artifact runtime is required. Set JAMMANBO_ARTIFACT_RUNTIME to its directory.' >&2
  exit 1
fi
render_dir=$(mktemp -d "${TMPDIR:-/tmp}/jammanbo-docs.XXXXXX")
cat > "$render_dir/fonts.conf" <<CONF
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
<fontconfig>
<dir>/System/Library/Fonts</dir>
<dir>/System/Library/Fonts/Supplemental</dir>
<dir>/Library/Fonts</dir>
<dir>/usr/share/fonts</dir>
<cachedir>$render_dir/font-cache</cachedir>
<alias><family>Calibri</family><prefer><family>Apple SD Gothic Neo</family></prefer></alias>
<alias><family>Malgun Gothic</family><prefer><family>Apple SD Gothic Neo</family></prefer></alias>
<alias><family>sans-serif</family><prefer><family>Apple SD Gothic Neo</family></prefer></alias>
</fontconfig>
CONF
export FONTCONFIG_FILE="$render_dir/fonts.conf"
for doc in 01_Jammanbo_SSRD 03_Jammanbo_SSAD; do
  "$artifact_python" "$artifact_render" "$doc.docx" --output_dir "$render_dir/$doc" --emit_pdf --dpi 110
  case "$doc" in
    01*|03*) cp "$render_dir/$doc/$doc.pdf" "output/pdf/$doc.pdf" ;;
  esac
done
"$artifact_soffice" "-env:UserInstallation=file://$render_dir/lo-deck" --headless --convert-to pdf --outdir "$render_dir" output/pptx/02_Jammanbo_UIUX_v7.pptx
cp "$render_dir/02_Jammanbo_UIUX_v7.pdf" output/pdf/02_Jammanbo_UIUX.pdf
"$artifact_runtime/dependencies/bin/override/pdftoppm" -r 85 -png "$render_dir/02_Jammanbo_UIUX_v7.pdf" "$render_dir/slide" >/dev/null 2>&1
printf 'Inspect all page PNGs before delivery: %s\n' "$render_dir"
