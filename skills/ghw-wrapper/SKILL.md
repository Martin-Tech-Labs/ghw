---
name: ghw-wrapper
description: Safe GitHub CLI wrapper that supports multiple github.com accounts by storing PATs in macOS Keychain and injecting GH_TOKEN into the gh subprocess. Blocks `gh auth` commands to prevent gh from touching Keychain. Use when doing GitHub operations in OpenClaw and you want to avoid granting broad Keychain access to `/usr/bin/security`.
---

# ghw-wrapper

## Why

`gh` sometimes shells out to macOS Keychain via the `security` tool. In some setups this can lead to broader Keychain prompts/permissions than desired.

This skill uses `ghw`, a small Swift wrapper that:
- stores tokens in Keychain (wrapper-controlled)
- injects `GH_TOKEN` to `gh` for each command
- blocks `gh auth ...`

## Build

```bash
cd /Users/agent/.openclaw/workspace/projects/ghw
swift build -c release
```

Binary:
- `/Users/agent/.openclaw/workspace/projects/ghw/.build/release/ghw`

## Install (suggested)

Copy the binary to a stable location (example):

```bash
mkdir -p /Users/agent/.openclaw/workspace/bin
cp -f /Users/agent/.openclaw/workspace/projects/ghw/.build/release/ghw /Users/agent/.openclaw/workspace/bin/ghw
```

## Auth

Add a profile (token via stdin):

```bash
echo "$GITHUB_PAT" | /Users/agent/.openclaw/workspace/bin/ghw login --profile toby --user toby-winter-bot
```

List profiles:

```bash
/Users/agent/.openclaw/workspace/bin/ghw profiles list
```

Use gh with injected token:

```bash
/Users/agent/.openclaw/workspace/bin/ghw --as toby repo view Martin-Tech-Labs/runbook
```

## TODO (hardening)

- Restrict Keychain item access to the signed `ghw` binary (Trusted Applications / access control), which implies stable codesigning.
