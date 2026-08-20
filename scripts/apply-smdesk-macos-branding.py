from pathlib import Path
import re

VERSION = "1.2.1"

print("Applying safe SMDesk macOS pre-build branding...")

# IMPORTANT:
# Do NOT change PRODUCT_NAME before build.
# RustDesk build.py expects RustDesk.app during compilation.
# Final rename to SMDesk.app happens after build.

# Copyright only
p = Path("flutter/macos/Runner/Configs/AppInfo.xcconfig")

if p.exists():
    s = p.read_text(encoding="utf-8")

    s = re.sub(
        r"PRODUCT_COPYRIGHT\s*=.*",
        "PRODUCT_COPYRIGHT = Copyright © 2026 SMNET Co., Ltd. All rights reserved.",
        s
    )

    p.write_text(s, encoding="utf-8")
    print("Updated macOS copyright")

# Flutter visible version
p = Path("flutter/pubspec.yaml")

if p.exists():
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

print("Safe macOS pre-build branding completed.")
