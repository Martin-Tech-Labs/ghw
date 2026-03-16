#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# Build debug binary (fast) for smoke/acceptance testing.
swift build

BIN="$ROOT_DIR/.build/debug/ghw"
if [[ ! -x "$BIN" ]]; then
  echo "error: ghw binary not found at: $BIN" >&2
  exit 1
fi

echo "[acceptance] ghw binary: $BIN"

# 1) ghw auth fails (blocked before touching Keychain or gh)
set +e
OUT="$($BIN --as alice auth login 2>&1)"
CODE=$?
set -e
if [[ $CODE -eq 0 ]]; then
  echo "[acceptance] expected auth to fail, got exit 0" >&2
  echo "$OUT" >&2
  exit 1
fi
if ! echo "$OUT" | grep -qi "Blocked"; then
  echo "[acceptance] expected 'Blocked' message for auth" >&2
  echo "$OUT" >&2
  exit 1
fi

echo "[acceptance] ok: auth blocked"

# 2) ghw login fails with fake credential
# Force gh validation to fail deterministically by pointing to a non-existent gh path (DEBUG-only override).
set +e
OUT="$(echo "fake-token" | GHW_GH_PATH="/nonexistent/gh" $BIN login --as alice 2>&1)"
CODE=$?
set -e
if [[ $CODE -eq 0 ]]; then
  echo "[acceptance] expected login to fail, got exit 0" >&2
  echo "$OUT" >&2
  exit 1
fi

# Accept either "Token validation failed" (if gh ran and returned non-zero)
# or "Failed to run gh" (if gh couldn't be executed).
if ! (echo "$OUT" | grep -qi "Token validation failed" || echo "$OUT" | grep -qi "Failed to run gh" ); then
  echo "[acceptance] expected login failure message" >&2
  echo "$OUT" >&2
  exit 1
fi

echo "[acceptance] ok: login fails for fake token"
