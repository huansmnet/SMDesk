#!/usr/bin/env python3

from pathlib import Path
import re
import sys

CONFIG = Path("libs/hbb_common/src/config.rs")

APP_NAME = "SMDesk"
SERVER = "smdesk.smnet.vn"
PUB_KEY = "GEh9Ovb6UUE9dxuWMpAFuLNjBuSaVtNvUD93gaiPio4="

if not CONFIG.exists():
    print(f"ERROR: {CONFIG} not found")
    print("Run: git submodule update --init --recursive")
    sys.exit(1)

text = CONFIG.read_text(encoding="utf-8")

original = text

# ------------------------------------------------------------------
# 1. Application name
# ------------------------------------------------------------------

pattern = r'pub static ref APP_NAME:\s*RwLock<String>\s*=\s*RwLock::new\("RustDesk"\.to_owned\(\)\);'

replacement = (
    f'pub static ref APP_NAME: RwLock<String> = '
    f'RwLock::new("{APP_NAME}".to_owned());'
)

text, count_app = re.subn(pattern, replacement, text)

# ------------------------------------------------------------------
# 2. Production rendezvous server
# ------------------------------------------------------------------

pattern = (
    r'pub static ref PROD_RENDEZVOUS_SERVER:\s*RwLock<String>\s*='
    r'\s*RwLock::new\(""\.to_owned\(\)\);'
)

replacement = (
    f'pub static ref PROD_RENDEZVOUS_SERVER: RwLock<String> = '
    f'RwLock::new("{SERVER}".to_owned());'
)

text, count_prod = re.subn(pattern, replacement, text)

# ------------------------------------------------------------------
# 3. Public fallback rendezvous servers
#    Prevent fallback to RustDesk public infrastructure.
# ------------------------------------------------------------------

pattern = r'pub const RENDEZVOUS_SERVERS:\s*&\[&str\]\s*=\s*&\[[^\]]*\];'

replacement = (
    f'pub const RENDEZVOUS_SERVERS: &[&str] = '
    f'&["{SERVER}"];'
)

text, count_servers = re.subn(pattern, replacement, text)

# ------------------------------------------------------------------
# 4. Server public key
# ------------------------------------------------------------------

pattern = r'pub const RS_PUB_KEY:\s*&str\s*=\s*"[^"]*";'

replacement = f'pub const RS_PUB_KEY: &str = "{PUB_KEY}";'

text, count_key = re.subn(pattern, replacement, text)

print("SMDesk branding patch results:")
print(f"  APP_NAME                : {count_app}")
print(f"  PROD_RENDEZVOUS_SERVER  : {count_prod}")
print(f"  RENDEZVOUS_SERVERS      : {count_servers}")
print(f"  RS_PUB_KEY               : {count_key}")

required = {
    "APP_NAME": count_app,
    "PROD_RENDEZVOUS_SERVER": count_prod,
    "RENDEZVOUS_SERVERS": count_servers,
    "RS_PUB_KEY": count_key,
}

failed = [name for name, count in required.items() if count != 1]

if failed:
    print()
    print("ERROR: unexpected upstream source structure:")
    for name in failed:
        print(f"  {name}: expected 1 replacement")
    print()
    print("No file was modified.")
    sys.exit(1)

CONFIG.write_text(text, encoding="utf-8")

print()
print("SMDesk branding applied successfully.")
