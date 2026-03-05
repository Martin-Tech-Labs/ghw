# ghw

`ghw` is a thin wrapper around the GitHub CLI (`gh`) that:

- No default profiles: you must pass `--as <github_username>` per command
- Stores tokens in macOS Keychain
- Injects **only** `GH_TOKEN` into the `gh` subprocess environment
- Blocks `gh auth ...` commands to avoid `gh` touching Keychain

> Security note: This initial version stores tokens as generic password items.
> Next step is to restrict Keychain item access to this signed binary.

## Install (dev)

```bash
swift build -c release
./.build/release/ghw --help
```

## Auth

```bash
# Store token (read from stdin)
echo "$GITHUB_PAT" | ./.build/release/ghw login --as toby-winter-bot

# Run gh
./.build/release/ghw --as toby-winter-bot repo view Martin-Tech-Labs/runbook
```

## PR template

This repo includes `.github/pull_request_template.md` copied from the org template.
