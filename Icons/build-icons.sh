#!/bin/bash
set -euo pipefail

ICONS_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$ICONS_DIR/.." && pwd)"
OUTPUT_DIR="$ICONS_DIR/output"

echo "=== IShare Icon Builder ==="

if ! command -v rsvg-convert &>/dev/null; then
  echo "rsvg-convert (librsvg) is required. Install with:"
  echo "  brew install librsvg"
  exit 1
fi

rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

# --- App Icon (macOS standard sizes) ---
echo "Generating app icon sizes..."
ICONSET_DIR="$OUTPUT_DIR/AppIcon.iconset"
mkdir -p "$ICONSET_DIR"

SIZES=(
  "16,16x16"
  "32,16x16@2x"
  "32,32x32"
  "64,32x32@2x"
  "128,128x128"
  "256,128x128@2x"
  "256,256x256"
  "512,256x256@2x"
  "512,512x512"
  "1024,512x512@2x"
)

for entry in "${SIZES[@]}"; do
  IFS=, read -r px label <<< "$entry"
  echo "  -> ${px}px (${label})"
  rsvg-convert -w "$px" -h "$px" -o "$ICONSET_DIR/icon_${label}.png" "$ICONS_DIR/app-icon.svg"
done

echo "Creating .icns..."
iconutil -c icns --output "$OUTPUT_DIR/IShare.icns" "$ICONSET_DIR"
echo "  -> IShare.icns created"

# --- Alternative icon with transparent bg ---
ALT_DIR="$OUTPUT_DIR/AppIcon-Alt.iconset"
mkdir -p "$ALT_DIR"

for entry in "${SIZES[@]}"; do
  IFS=, read -r px label <<< "$entry"
  rsvg-convert -w "$px" -h "$px" -o "$ALT_DIR/icon_${label}.png" "$ICONS_DIR/app-icon-alt.svg"
done

iconutil -c icns --output "$OUTPUT_DIR/IShare-Alt.icns" "$ALT_DIR"
echo "  -> IShare-Alt.icns created"

# --- Menu bar icon (monochrome template) ---
echo "Generating menu bar icon..."
rsvg-convert -w 24 -h 24 -o "$OUTPUT_DIR/menubar-icon.png" "$ICONS_DIR/menubar-icon.svg"
echo "  -> menubar-icon.png (24x24)"

# --- Status icons ---
echo "Generating status icons..."
for icon in status-uploading status-success status-error; do
  rsvg-convert -w 32 -h 32 -o "$OUTPUT_DIR/${icon}.png" "$ICONS_DIR/${icon}.svg"
  echo "  -> ${icon}.png (32x32)"
done

# --- Large PNG previews ---
echo "Generating preview PNGs..."
rsvg-convert -w 512 -h 512 -o "$OUTPUT_DIR/app-icon-preview.png" "$ICONS_DIR/app-icon.svg"
rsvg-convert -w 512 -h 512 -o "$OUTPUT_DIR/app-icon-alt-preview.png" "$ICONS_DIR/app-icon-alt.svg"

echo ""
echo "=== Done ==="
echo "Output: $OUTPUT_DIR"
echo ""
ls -lh "$OUTPUT_DIR"
