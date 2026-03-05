---
name: github
description: Manage GitHub (repos + pull requests) safely in Martin-Tech-Labs using the `ghw` wrapper. Always run `gh` operations through `ghw` so tokens come from Keychain and `gh auth …` is blocked. For pull requests, use `ghw pr …` and use the PR template documented in references/pull-request.md.
---

# GitHub (Martin-Tech-Labs) — via `ghw`

This skill is the **single entrypoint** for GitHub work.

## Core rule (security)

- **Never run `gh auth ...`**
- **Never run raw `gh ...`** when authentication matters.
- Always use the wrapper:

```bash
/Users/agent/.openclaw/workspace/bin/ghw <gh args...>
```

`ghw` injects `GH_TOKEN` from **macOS Keychain** and blocks `gh auth` so GitHub CLI can’t store/read credentials via Keychain shell-outs.

## Setup (one-time)

### 1) Build ghw

```bash
cd /Users/agent/.openclaw/workspace/projects/ghw
swift build -c release
```

### 2) Install ghw into a stable path

```bash
mkdir -p /Users/agent/.openclaw/workspace/bin
cp -f /Users/agent/.openclaw/workspace/projects/ghw/.build/release/ghw /Users/agent/.openclaw/workspace/bin/ghw
```

### 3) Add account token (per profile)

Token must be provided via stdin:

```bash
echo "$GITHUB_PAT" | /Users/agent/.openclaw/workspace/bin/ghw login --profile toby --user toby-winter-bot
```

Select default profile:

```bash
/Users/agent/.openclaw/workspace/bin/ghw profiles use toby
```

## Pull requests

See: `references/pull-request.md`

Quick example:

```bash
/Users/agent/.openclaw/workspace/bin/ghw pr create --help
```

When creating a PR, prefer using the template file:

```bash
/Users/agent/.openclaw/workspace/bin/ghw pr create \
  --title "OPS-123: Short title" \
  --body-file .github/pull_request_template.md
```

## Repositories

Create/clone/view repos via `ghw`:

```bash
/Users/agent/.openclaw/workspace/bin/ghw repo view Martin-Tech-Labs/runbook
/Users/agent/.openclaw/workspace/bin/ghw repo clone Martin-Tech-Labs/ghw
```

## Resources

- PR workflow: `references/pull-request.md`
