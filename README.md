# ghw

`ghw` is a thin wrapper around the GitHub CLI (`gh`) that:

- Supports multiple profiles (accounts)
- Stores tokens in macOS Keychain
- Injects `GH_TOKEN` into the `gh` subprocess environment
- Blocks `gh auth ...` commands to avoid `gh` touching Keychain

> Security note: This initial version stores tokens as generic password items.
> Next step is to restrict Keychain item access to this signed binary.

## Install (dev)

```bash
swift build -c release
./.build/release/ghw profiles list
```

## Auth

```bash
# Store token (read from stdin)
echo "$GITHUB_PAT" | ./.build/release/ghw login --profile toby --user toby-winter-bot

# Use profile
./.build/release/ghw --as toby repo view Martin-Tech-Labs/runbook
```

## PR template

This repo includes `.github/pull_request_template.md` copied from the org template.
