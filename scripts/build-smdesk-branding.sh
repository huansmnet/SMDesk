#!/bin/bash
set -e

ROOT="/root/Projects/smdesk-client"
cd "$ROOT"

ICON="branding/smdesk-icon.png"
SMNET="branding/smnet-logo.png"
OUT="branding/generated"

mkdir -p "$OUT"

if [ ! -f "$ICON" ]; then
    echo "ERROR: missing $ICON"
    exit 1
fi

if [ ! -f "$SMNET" ]; then
    echo "ERROR: missing $SMNET"
    exit 1
fi

echo "=== Generate SMDesk application icon ==="

convert "$ICON" \
    -background none \
    -resize 1024x1024 \
    "$OUT/smdesk-icon.png"

echo "=== Generate Windows ICO ==="

convert "$ICON" \
    -background none \
    -define icon:auto-resize=256,128,64,48,32,24,16 \
    "$OUT/smdesk-app.ico"

echo "=== Generate favicon ==="

convert "$ICON" \
    -background none \
    -define icon:auto-resize=64,48,32,16 \
    "$OUT/favicon.ico"

echo "=== Generate SMDesk light logo ==="

convert -size 1200x260 xc:none \
    \( "$ICON" -resize 190x190 \) \
    -geometry +15+30 -composite \
    -font DejaVu-Sans-Bold \
    -pointsize 100 \
    -fill "#00AEEF" \
    -annotate +225+120 "SM" \
    -fill "#0B163B" \
    -annotate +415+120 "Desk" \
    -font DejaVu-Sans \
    -pointsize 34 \
    -fill "#6B7280" \
    -annotate +230+190 "Remote Support by SMNET" \
    "$OUT/smdesk-logo-light.png"

cp "$OUT/smdesk-logo-light.png" \
   "$OUT/smdesk-logo.png"

echo "=== Generate SMDesk dark logo ==="

convert -size 1200x260 xc:none \
    \( "$ICON" -resize 190x190 \) \
    -geometry +15+30 -composite \
    -font DejaVu-Sans-Bold \
    -pointsize 100 \
    -fill "#00AEEF" \
    -annotate +225+120 "SM" \
    -fill "#FFFFFF" \
    -annotate +415+120 "Desk" \
    -font DejaVu-Sans \
    -pointsize 34 \
    -fill "#D7DCE5" \
    -annotate +230+190 "Remote Support by SMNET" \
    "$OUT/smdesk-logo-dark.png"

echo "=== Install assets into RustDesk/SMDesk source ==="

cp "$OUT/smdesk-icon.png" \
   res/icon.png

cp "$OUT/smdesk-icon.png" \
   flutter/assets/icon.png

cp "$OUT/smdesk-app.ico" \
   flutter/windows/runner/resources/app_icon.ico

cp "$OUT/smdesk-logo.png" \
   flutter/assets/logo.png

cp "$OUT/smdesk-logo-light.png" \
   flutter/assets/logo_light.png

cp "$OUT/smdesk-logo-dark.png" \
   flutter/assets/logo_dark.png

echo
echo "=== Generated files ==="
ls -lh "$OUT"

echo
echo "Brand assets installed successfully."
