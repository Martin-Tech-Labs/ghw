# ghw

`ghw` is a thin wrapper around the GitHub CLI (`gh`) that:

- requires `--as <github_username>` on every command (no defaults)
- stores PATs in **macOS Keychain**
- injects **only** `GH_TOKEN` into the `gh` subprocess environment
- blocks `gh auth ...` so `gh` can’t store/read credentials via Keychain shell-outs

## Why

`gh` can shell out to `/usr/bin/security` (Keychain) depending on configuration. If you accidentally grant broad Keychain access, that’s a security risk.

`ghw` keeps the token flow explicit and local:

- `ghw` reads a token from Keychain using Keychain APIs
- `ghw` runs `gh` with `GH_TOKEN` set **only for that subprocess**

## Prerequisites

- macOS
- GitHub CLI:
  ```bash
  brew install gh
  ```
- Swift toolchain (Xcode Command Line Tools):
  ```bash
  xcode-select --install
  ```

## Build

```bash
swift build -c release
```

Binary:
- `./.build/release/ghw`

## Install (recommended)

Install `ghw` to a stable location **and add it to PATH**, so you can run `ghw` directly.

Example:

```bash
mkdir -p /Users/agent/.openclaw/workspace/bin
cp -f ./.build/release/ghw /Users/agent/.openclaw/workspace/bin/ghw
chmod +x /Users/agent/.openclaw/workspace/bin/ghw

# zsh:
echo 'export PATH="/Users/agent/.openclaw/workspace/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc

# fish (alternative):
# set -Ux fish_user_paths /Users/agent/.openclaw/workspace/bin $fish_user_paths
```

## Signing (recommended)

Signing is recommended so we can store Keychain tokens with an ACL that trusts **only** the signed `ghw` binary.

> `scripts/sign.sh` contains **no keys**. It just invokes `codesign` with an identity that already exists in your Keychain.

### Option A: Local self-signed Code Signing certificate (no Apple Developer account needed)

1) Open **Keychain Access**
2) **Keychain Access → Certificate Assistant → Create a Certificate…**
3) Name: `ghw-local`
4) Identity Type: **Self Signed Root**
5) Certificate Type: **Code Signing**

Then:

```bash
swift build -c release
SIGN_ID="ghw-local" ./scripts/sign.sh
```

### Option B: Apple Developer ID (if you have one)

Use your Developer ID Application identity, e.g.:

```bash
swift build -c release
SIGN_ID="Developer ID Application: Your Name (TEAMID)" ./scripts/sign.sh
```

## Add an account token

Provide a PAT via stdin:

```bash
echo "$GITHUB_PAT" | ghw login --as <github_username>
```

## Usage (always pass --as)

```bash
# sanity check
ghw --as <github_username> whoami

# example command
ghw --as <github_username> repo view <owner>/<repo>

# create PR using template
ghw --as <github_username> pr create --body-file .github/pull_request_template.md
```

## PR template

This repo includes `.github/pull_request_template.md` copied from the org template.
