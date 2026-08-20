from pathlib import Path
import re

VERSION = "1.2.1"

def replace(path, old, new, required=True):
    p = Path(path)
    s = p.read_text(encoding="utf-8")

    if old not in s:
        if required:
            raise SystemExit(f"ERROR: not found in {path}: {old}")
        print(f"Skip: {path}")
        return

    p.write_text(s.replace(old, new), encoding="utf-8")
    print(f"Updated: {path}")

# -------------------------------------------------
# macOS product identity
# -------------------------------------------------

replace(
    "flutter/macos/Runner/Configs/AppInfo.xcconfig",
    "PRODUCT_NAME = RustDesk",
    "PRODUCT_NAME = SMDesk"
)

replace(
    "flutter/macos/Runner/Configs/AppInfo.xcconfig",
    "PRODUCT_BUNDLE_IDENTIFIER = com.carriez.flutterHbb",
    "PRODUCT_BUNDLE_IDENTIFIER = vn.smnet.smdesk"
)

p = Path("flutter/macos/Runner/Configs/AppInfo.xcconfig")
s = p.read_text(encoding="utf-8")
s = re.sub(
    r"PRODUCT_COPYRIGHT\s*=.*",
    "PRODUCT_COPYRIGHT = Copyright © 2026 SMNET Co., Ltd. All rights reserved.",
    s
)
p.write_text(s, encoding="utf-8")

# -------------------------------------------------
# Xcode product name
# -------------------------------------------------

p = Path("flutter/macos/Runner.xcodeproj/project.pbxproj")
s = p.read_text(encoding="utf-8")
s = s.replace("RustDesk.app", "SMDesk.app")
p.write_text(s, encoding="utf-8")
print("Updated: Xcode SMDesk.app")

# -------------------------------------------------
# build.py contains RustDesk.app hard-coded
# -------------------------------------------------

p = Path("build.py")
s = p.read_text(encoding="utf-8")
s = s.replace(
    "Release/RustDesk.app/Contents/MacOS/",
    "Release/SMDesk.app/Contents/MacOS/"
)
p.write_text(s, encoding="utf-8")
print("Updated: build.py")

# -------------------------------------------------
# URL identity
# Keep rustdesk:// scheme internally for now
# to avoid breaking upstream protocol handling.
# -------------------------------------------------

p = Path("flutter/macos/Runner/Info.plist")
s = p.read_text(encoding="utf-8")
s = s.replace(
    "<string>com.carriez.rustdesk</string>",
    "<string>vn.smnet.smdesk</string>"
)
p.write_text(s, encoding="utf-8")
print("Updated: Info.plist")

# -------------------------------------------------
# Visible macOS app version
# -------------------------------------------------

p = Path("flutter/pubspec.yaml")
s = p.read_text(encoding="utf-8")

s, count = re.subn(
    r"(?m)^version:\s*[^\n]+",
    f"version: {VERSION}+121",
    s,
    count=1
)

if count:
    p.write_text(s, encoding="utf-8")
    print(f"Flutter version -> {VERSION}+121")
else:
    print("WARNING: version line not found in pubspec.yaml")

print()
print("SMDesk macOS branding patch completed.")
