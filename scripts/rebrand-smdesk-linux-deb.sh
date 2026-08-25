#!/bin/bash
set -euo pipefail

VERSION="${1:-1.2.2}"
ARCH="${2:-x86_64}"
INPUT="${3:-}"

if [ -z "$INPUT" ] || [ ! -f "$INPUT" ]; then
    echo "Usage:"
    echo "$0 VERSION ARCH input.deb"
    exit 1
fi

case "$ARCH" in
    x86_64)
        DEB_ARCH="amd64"
        ;;
    arm64|aarch64)
        DEB_ARCH="arm64"
        ;;
    *)
        echo "Unsupported arch: $ARCH"
        exit 1
        ;;
esac

ROOT="$(pwd)"
WORK="$ROOT/.smdesk-linux-package"
OUT="$ROOT/SMDesk-${VERSION}-Linux-${ARCH}.deb"

rm -rf "$WORK"
mkdir -p "$WORK"

echo "=== Extract upstream package ==="

dpkg-deb -R "$INPUT" "$WORK"

CONTROL="$WORK/DEBIAN/control"

test -f "$CONTROL"

echo "=== Package identity ==="

sed -i \
    's/^Package:.*/Package: smdesk/' \
    "$CONTROL"

sed -i \
    "s/^Version:.*/Version: ${VERSION}/" \
    "$CONTROL"

sed -i \
    "s/^Architecture:.*/Architecture: ${DEB_ARCH}/" \
    "$CONTROL"

sed -i \
    's/^Maintainer:.*/Maintainer: SMNET Co., Ltd <hello@smnet.vn>/' \
    "$CONTROL"

sed -i \
    's|^Homepage:.*|Homepage: https://smdesk.smnet.vn|' \
    "$CONTROL"

sed -i \
    's/^Description:.*/Description: SMDesk Remote Support by SMNET/' \
    "$CONTROL"

# Prevent installing RustDesk and SMDesk side-by-side because
# internal runtime paths are intentionally preserved.
if ! grep -q '^Conflicts:' "$CONTROL"; then
    echo "Conflicts: rustdesk" >> "$CONTROL"
fi

if ! grep -q '^Replaces:' "$CONTROL"; then
    echo "Replaces: rustdesk" >> "$CONTROL"
fi

echo "=== Install SMDesk icon ==="

mkdir -p \
"$WORK/usr/share/icons/hicolor/256x256/apps"

cp \
branding/smdesk-icon.png \
"$WORK/usr/share/icons/hicolor/256x256/apps/smdesk.png"

echo "=== Desktop launcher ==="

DESKTOP="$WORK/usr/share/applications/rustdesk.desktop"

if [ -f "$DESKTOP" ]; then

    sed -i \
        's/^Name=.*/Name=SMDesk/' \
        "$DESKTOP"

    sed -i \
        's/^GenericName=.*/GenericName=Remote Support/' \
        "$DESKTOP" || true

    sed -i \
        's/^Comment=.*/Comment=SMDesk Remote Support by SMNET/' \
        "$DESKTOP" || true

    sed -i \
        's/^Icon=.*/Icon=smdesk/' \
        "$DESKTOP"

    # Keep internal rustdesk binary but expose SMDesk command.
    sed -i \
        's|^Exec=.*|Exec=/usr/bin/smdesk %u|' \
        "$DESKTOP"

    mv \
        "$DESKTOP" \
        "$WORK/usr/share/applications/smdesk.desktop"
fi

echo "=== SMDesk command alias ==="

mkdir -p "$WORK/usr/bin"

if [ -e "$WORK/usr/bin/rustdesk" ]; then
    ln -sfn rustdesk "$WORK/usr/bin/smdesk"
else
    ln -sfn \
        /usr/share/rustdesk/rustdesk \
        "$WORK/usr/bin/smdesk"
fi

echo "=== Product metadata ==="

mkdir -p "$WORK/usr/share/doc/smdesk"

cat > "$WORK/usr/share/doc/smdesk/SMDesk-README.txt" <<DOC
SMDesk Remote Support
Version: ${VERSION}
Platform: Linux ${ARCH}

Product:
SMDesk Remote Support by SMNET

Website:
https://smdesk.smnet.vn

Support:
https://smnet.vn
hello@smnet.vn
028 7301 6068

SMDesk is based on open-source remote desktop technology.
Internal runtime paths may retain upstream technical names
for compatibility.
DOC

echo "=== Build SMDesk DEB ==="

dpkg-deb --build "$WORK" "$OUT"

rm -rf "$WORK"

echo
echo "===== SMDesk Linux Release ====="
ls -lh "$OUT"

sha256sum "$OUT" > "${OUT}.sha256"

cat "${OUT}.sha256"
