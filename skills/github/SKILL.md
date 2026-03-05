---
name: github
description: Manage GitHub repositories + pull requests safely using the `ghw` wrapper. Always run `gh` operations through `ghw` so tokens come from Keychain and `gh auth …` is blocked. For pull requests, use `ghw pr …` and follow the PR template workflow in references/pull-request.md.
---

# GitHub — via `ghw`

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

Setup/build/signing/token enrollment live in this repo:
- `SETUP.md`

(Keep this skill focused on *usage*, not installation.)

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

Create/clone/view repos via `ghw`.

Note: repo owners and names vary by task. Do not hardcode an org; use the repo specified by the user/Jira or project runbook.

Examples:

```bash
/Users/agent/.openclaw/workspace/bin/ghw repo view <owner>/<repo>
/Users/agent/.openclaw/workspace/bin/ghw repo clone <owner>/<repo>
```

## Resources

- PR workflow: `references/pull-request.md`
