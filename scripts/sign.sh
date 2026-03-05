#!/usr/bin/env bash
set -euo pipefail

# Sign the ghw binary so Keychain ACLs can trust it.
#
# This script does NOT contain any private keys.
# It just invokes `codesign` with a signing identity that must already exist in your Keychain.
#
# Usage:
#   SIGN_ID="Your Developer ID Application: ..." ./scripts/sign.sh
#   SIGN_ID="ghw-local" ./scripts/sign.sh

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$ROOT_DIR/.build/release/ghw"

if [[ ! -f "$BIN" ]]; then
  echo "Binary not found: $BIN" >&2
  echo "Run: swift build -c release" >&2
  exit 1
fi

SIGN_ID="${SIGN_ID:-}"
if [[ -z "$SIGN_ID" ]]; then
  echo "Missing SIGN_ID env var (codesign identity)." >&2
  echo "Example: SIGN_ID=ghw-local ./scripts/sign.sh" >&2
  exit 2
fi

# Hardened runtime is optional for local tools; omit by default.
/usr/bin/codesign --force --timestamp=none --sign "$SIGN_ID" "$BIN"

# Verify
/usr/bin/codesign --verify --verbose=2 "$BIN"
/usr/bin/codesign -dv --verbose=2 "$BIN" 2>&1 | sed -n '1,25p'

echo "OK signed: $BIN"
