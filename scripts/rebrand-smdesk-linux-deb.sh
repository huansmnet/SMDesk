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
    x86_64|amd64)
        DEB_ARCH="amd64"
        ;;
    arm64|aarch64)
        DEB_ARCH="arm64"
        ;;
    *)
        echo "Unsupported architecture: $ARCH"
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

if [ ! -f "$CONTROL" ]; then
    echo "ERROR: DEBIAN/control not found"
    exit 1
fi


# ==========================================================
# Debian package metadata
#
# IMPORTANT:
# A Debian binary control file must contain ONE stanza only.
# Do not append fields after a blank line.
# ==========================================================

echo "=== Package identity ==="

python3 - "$CONTROL" "$VERSION" "$DEB_ARCH" <<'PY'
from pathlib import Path
import sys

control_path = Path(sys.argv[1])
version = sys.argv[2]
arch = sys.argv[3]

raw = control_path.read_text(encoding="utf-8")

# Binary DEB control must contain one package stanza.
# Remove accidental extra paragraphs/stanzas.
first_stanza = raw.strip().split("\n\n", 1)[0]
lines = first_stanza.splitlines()

# Parse Debian control fields while preserving continuation lines.
blocks = []
current = []

for line in lines:
    if line and not line[0].isspace():
        if current:
            blocks.append(current)
        current = [line]
    else:
        if current:
            current.append(line)

if current:
    blocks.append(current)


def field_name(block):
    if not block:
        return ""
    return block[0].split(":", 1)[0].strip()


def replace_field(name, value):
    global blocks

    for i, block in enumerate(blocks):
        if field_name(block).lower() == name.lower():
            blocks[i] = [f"{name}: {value}"]
            return

    # Insert new fields before Description when possible.
    for i, block in enumerate(blocks):
        if field_name(block).lower() == "description":
            blocks.insert(i, [f"{name}: {value}"])
            return

    blocks.append([f"{name}: {value}"])


def remove_field(name):
    global blocks
    blocks = [
        b for b in blocks
        if field_name(b).lower() != name.lower()
    ]


replace_field("Package", "smdesk")
replace_field("Version", version)
replace_field("Architecture", arch)
replace_field(
    "Maintainer",
    "SMNET Co., Ltd <hello@smnet.vn>"
)
replace_field(
    "Homepage",
    "https://smdesk.smnet.vn"
)

# Avoid conflict with an existing RustDesk installation because
# SMDesk intentionally keeps several upstream runtime paths.
remove_field("Conflicts")
remove_field("Replaces")

replace_field("Conflicts", "rustdesk")
replace_field("Replaces", "rustdesk")

# Replace complete upstream Description block.
blocks = [
    b for b in blocks
    if field_name(b).lower() != "description"
]

blocks.append([
    "Description: SMDesk Remote Support by SMNET",
    " Secure remote support application for business users.",
    " SMDesk connects to the SMNET managed remote support",
    " infrastructure at smdesk.smnet.vn."
])

output = []

for block in blocks:
    output.extend(block)

# Exactly one stanza + exactly one newline at EOF.
control_path.write_text(
    "\n".join(output).rstrip() + "\n",
    encoding="utf-8"
)
PY


echo
echo "===== FINAL DEBIAN CONTROL ====="

cat "$CONTROL"

echo
echo "===== CONTROL STANZA CHECK ====="

python3 - "$CONTROL" <<'PY'
from pathlib import Path
import sys

s = Path(sys.argv[1]).read_text().strip()

stanzas = [
    x for x in s.split("\n\n")
    if x.strip()
]

print("Package stanzas:", len(stanzas))

if len(stanzas) != 1:
    print("ERROR: Debian control must contain exactly one stanza")
    sys.exit(1)

print("Debian control structure: OK")
PY


# ==========================================================
# SMDesk branding
# ==========================================================

echo
echo "=== Install SMDesk icon ==="

mkdir -p \
"$WORK/usr/share/icons/hicolor/256x256/apps"

cp \
branding/smdesk-icon.png \
"$WORK/usr/share/icons/hicolor/256x256/apps/smdesk.png"


# ==========================================================
# Desktop launcher
# ==========================================================

echo "=== Desktop launcher ==="

DESKTOP=""

for candidate in \
    "$WORK/usr/share/applications/rustdesk.desktop" \
    "$WORK/usr/share/applications/RustDesk.desktop"
do
    if [ -f "$candidate" ]; then
        DESKTOP="$candidate"
        break
    fi
done

if [ -n "$DESKTOP" ]; then

    sed -i \
        's/^Name=.*/Name=SMDesk/' \
        "$DESKTOP"

    if grep -q '^GenericName=' "$DESKTOP"; then
        sed -i \
            's/^GenericName=.*/GenericName=Remote Support/' \
            "$DESKTOP"
    else
        sed -i \
            '/^Name=/a GenericName=Remote Support' \
            "$DESKTOP"
    fi

    if grep -q '^Comment=' "$DESKTOP"; then
        sed -i \
            's/^Comment=.*/Comment=SMDesk Remote Support by SMNET/' \
            "$DESKTOP"
    fi

    if grep -q '^Icon=' "$DESKTOP"; then
        sed -i \
            's/^Icon=.*/Icon=smdesk/' \
            "$DESKTOP"
    else
        echo "Icon=smdesk" >> "$DESKTOP"
    fi

    if grep -q '^Exec=' "$DESKTOP"; then
        sed -i \
            's|^Exec=.*|Exec=/usr/bin/smdesk %u|' \
            "$DESKTOP"
    fi

    mv \
        "$DESKTOP" \
        "$WORK/usr/share/applications/smdesk.desktop"
else

    echo "Upstream desktop file not found - creating SMDesk desktop entry"

    mkdir -p "$WORK/usr/share/applications"

    cat > "$WORK/usr/share/applications/smdesk.desktop" <<DESKTOPFILE
[Desktop Entry]
Name=SMDesk
GenericName=Remote Support
Comment=SMDesk Remote Support by SMNET
Exec=/usr/bin/smdesk %u
Icon=smdesk
Terminal=false
Type=Application
Categories=Network;RemoteAccess;
StartupNotify=true
DESKTOPFILE

fi


# ==========================================================
# smdesk command
#
# Keep upstream binary/runtime naming internally.
# Expose /usr/bin/smdesk to the user.
# ==========================================================

echo "=== SMDesk command alias ==="

mkdir -p "$WORK/usr/bin"

if [ -e "$WORK/usr/bin/rustdesk" ]; then

    ln -sfn \
        rustdesk \
        "$WORK/usr/bin/smdesk"

elif [ -e "$WORK/usr/share/rustdesk/rustdesk" ]; then

    ln -sfn \
        /usr/share/rustdesk/rustdesk \
        "$WORK/usr/bin/smdesk"

else

    echo "ERROR: RustDesk runtime binary not found"

    find "$WORK/usr" \
        -maxdepth 4 \
        -type f \
        -iname '*rustdesk*' \
        -print || true

    exit 1

fi


# ==========================================================
# SMDesk documentation
# ==========================================================

echo "=== Product metadata ==="

mkdir -p \
"$WORK/usr/share/doc/smdesk"

cat > "$WORK/usr/share/doc/smdesk/README.SMDesk" <<DOC
SMDesk Remote Support
=====================

Version
-------
${VERSION}

Platform
--------
Linux ${ARCH}

Product
-------
SMDesk Remote Support by SMNET

Remote Support Server
---------------------
smdesk.smnet.vn

Website
-------
https://smdesk.smnet.vn

SMNET
-----
https://smnet.vn

Support
-------
hello@smnet.vn
028 7301 6068

SMDesk is based on open-source remote desktop technology.
Some internal runtime files retain upstream technical names
for compatibility.
DOC


# ==========================================================
# Build
# ==========================================================

echo
echo "=== Build SMDesk DEB ==="

rm -f "$OUT" "$OUT.sha256"

dpkg-deb \
    --root-owner-group \
    --build \
    "$WORK" \
    "$OUT"


# ==========================================================
# Validation
# ==========================================================

echo
echo "=== Verify SMDesk DEB ==="

dpkg-deb -I "$OUT"

echo
echo "=== Verify package name ==="

PACKAGE_NAME="$(
    dpkg-deb -f "$OUT" Package
)"

PACKAGE_VERSION="$(
    dpkg-deb -f "$OUT" Version
)"

PACKAGE_ARCH="$(
    dpkg-deb -f "$OUT" Architecture
)"

echo "Package:      $PACKAGE_NAME"
echo "Version:      $PACKAGE_VERSION"
echo "Architecture: $PACKAGE_ARCH"

if [ "$PACKAGE_NAME" != "smdesk" ]; then
    echo "ERROR: expected Package: smdesk"
    exit 1
fi

if [ "$PACKAGE_VERSION" != "$VERSION" ]; then
    echo "ERROR: package version mismatch"
    exit 1
fi

if [ "$PACKAGE_ARCH" != "$DEB_ARCH" ]; then
    echo "ERROR: package architecture mismatch"
    exit 1
fi


echo
echo "=== SHA256 ==="

sha256sum "$OUT" \
    > "${OUT}.sha256"

cat "${OUT}.sha256"


echo
echo "=============================================="
echo " SMDesk Linux package successfully created"
echo "=============================================="

ls -lh \
    "$OUT" \
    "${OUT}.sha256"


rm -rf "$WORK"
