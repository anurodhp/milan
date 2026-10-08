#!/bin/bash
# Renders the Lucide SVGs (ISC, icons/LICENSE-lucide.txt) in icons/src into the TIFFs Milan draws
# (every GNUstep reads TIFF): toolbar glyphs in normal/disabled/pressed colours, and the larger
# coloured file-type icons. The outputs are committed (icons/*.tiff), so the cross build needs none of
# this; it runs on the macOS host only (AppKit rasterises the SVG, sips converts to TIFF).
#   Usage: tools/make_icons.sh
set -euo pipefail
cd "$(dirname "$0")/.."
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
clang -fobjc-arc -framework AppKit -o "$T/svg2png" tools/svg2png.m

# render <out-name> <svg> <pixels> <stroke> <fill> <stroke-width>
render() {
    local out="$1" src="icons/src/$2.svg" px="$3" col="$4" fill="$5" sw="$6"
    sed -e "s/stroke=\"currentColor\"/stroke=\"$col\"/" -e "s/fill=\"none\"/fill=\"$fill\"/" \
        -e "s/stroke-width=\"2\"/stroke-width=\"$sw\"/" "$src" > "$T/in.svg"
    "$T/svg2png" "$T/in.svg" "$T/out.png" "$px"
    sips -s format tiff "$T/out.png" --out "icons/$out.tiff" > /dev/null
}

# toolbar glyphs, 20 px box (2x the 10-unit... drawn at pixel size): name:lucide-name
for pair in back:chevron-left forward:chevron-right up:arrow-up icons:layout-grid list:list columns:columns-3 \
            newfolder:folder-plus info:info copy:copy paste:clipboard-paste trash:trash; do
    n="${pair%%:*}"; s="${pair#*:}"
    render "tb-$n-normal"   "$s" 20 "#4a4a4a" none 2
    render "tb-$n-disabled" "$s" 20 "#b4b4b4" none 2
    render "tb-$n-pressed"  "$s" 20 "#111111" none 2
    render "tb-$n-selected" "$s" 20 "#0a64d6" none 2.2
done

# file-type icons, 64 px: name:lucide-name:stroke:fill
while IFS=: read -r n s col fill; do
    render "ft-$n" "$s" 64 "$col" "$fill" 1.6
done <<'LIST'
folder:folder:#2f7fd8:#a9d1ff
file:file:#6b7480:#f4f6f8
text:file-text:#6b7480:#f4f6f8
code:file-code:#7a4fd0:#efe8fb
image:image:#1f9d6b:#dff5ea
audio:music:#d6407a:#fbe3ed
video:film:#d6702a:#fbebdc
archive:archive:#a07a1e:#f8efd6
app:app-window:#2f7fd8:#dcebff
exec:square-terminal:#3b4350:#e5e8ec
config:file-cog:#6b7480:#f4f6f8
disk:hard-drive:#6b7480:#e8ebef
trash:trash:#6b7480:#eceff2
LIST
# the application icon (an original platypus head), 128 px TIFF for the dock/about panel and a 512 px PNG
"$T/svg2png" icons/app/milan.svg "$T/app.png" 128 && sips -s format tiff "$T/app.png" --out icons/app/Milan.tiff > /dev/null
"$T/svg2png" icons/app/milan.svg icons/app/Milan.png 512
ls -1 icons/*.tiff | wc -l | sed 's/$/ icons written/'
