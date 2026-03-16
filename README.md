# ghw

[![Main](https://github.com/Martin-Tech-Labs/ghw/actions/workflows/main.yml/badge.svg?branch=main)](https://github.com/Martin-Tech-Labs/ghw/actions/workflows/main.yml)
![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)
![Swift 6.1+](https://img.shields.io/badge/Swift-6.1%2B-orange.svg?logo=swift)

`ghw` is a thin wrapper around the GitHub CLI (`gh`) that:

- requires `--as <alias>` on every command (no defaults)
- stores GitHub personal access tokens in **macOS Keychain**
- injects environment variable `GH_TOKEN` into the `gh` subprocess environment
- blocks `gh auth ...` so `gh` can’t store/read credentials via Keychain shell-outs

## Why

`gh` accesses keychain using shell's command security, leading to process  `/usr/bin/security` getting access to the stored GitHub Token. This will allow any process using shell to get access to stored github tokens. See https://github.com/cli/cli/issues/7123.

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

## Tests

Run locally:

```bash
swift test
```

(These are lightweight CI sanity checks; they mainly ensure the package and wrapper plumbing stay buildable.)

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

```

## Signing (recommended)

Signing is recommended so we can store Keychain tokens with an ACL that trusts **only** the signed `ghw` binary.

> `scripts/sign.sh` contains **no keys**. It just invokes `codesign` with an identity that already exists in your Keychain.

### Option A: Local self-signed Code Signing certificate (no Apple Developer ID needed)

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

### Default: interactive hidden prompt

If you run `ghw login` in a normal terminal, it will prompt for the token with hidden input.

```bash
ghw login --as <alias>
```

### Automation/CI: stdin

If stdin is not a TTY (piped input), `ghw login` reads the token from stdin:

```bash
echo "$GITHUB_PAT" | ghw login --as <alias>
```

## Usage (always pass --as)

```bash
# sanity check
ghw --as <alias> whoami

# example command
ghw --as <alias> repo view <owner>/<repo>

# create PR using template
ghw --as <alias> pr create --body-file .github/pull_request_template.md
```

## PR template

This repo includes `.github/pull_request_template.md` copied from the org template.

# Skills

This repo also includes a skill which uses ghw to create repository and manage pull requests along with mandated repository settings and PR templates.