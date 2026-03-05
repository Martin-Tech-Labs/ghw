# Setup (ghw)

This repo provides `ghw`, a wrapper around GitHub CLI (`gh`) that:

- supports multiple accounts (by GitHub username)
- stores PATs in **macOS Keychain**
- injects **only** `GH_TOKEN` into the `gh` subprocess environment
- blocks `gh auth ...` to prevent `gh` from touching Keychain

> The security hardening goal is to restrict Keychain items so only the signed `ghw` binary can read them.

## Prerequisites

- macOS
- `gh` installed (Homebrew):
  ```bash
  brew install gh
  ```
- Swift toolchain (Xcode Command Line Tools):
  ```bash
  xcode-select --install
  ```

## Build

```bash
cd /Users/agent/.openclaw/workspace/projects/ghw
swift build -c release
```

Binary:
- `./.build/release/ghw`

## Install (recommended)

Install `ghw` to a stable location **and add it to PATH**, so you can run `ghw` directly (avoid `./.build/release/...`).

Example:

```bash
mkdir -p /Users/agent/.openclaw/workspace/bin
cp -f ./.build/release/ghw /Users/agent/.openclaw/workspace/bin/ghw

# Add to PATH (choose ONE of the following)
# zsh:
echo 'export PATH="/Users/agent/.openclaw/workspace/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc

# fish:
# set -Ux fish_user_paths /Users/agent/.openclaw/workspace/bin $fish_user_paths
```

After this, use:

```bash
ghw --help
```

## Add an account

Provide a PAT via stdin:

```bash
echo "$GITHUB_PAT" | ghw login --as <github_username>
```

## Usage rule: always pass --as

For safety, there are **no default profiles**. You must pass `--as <github_username>` on every command.

Test:

```bash
ghw --as <github_username> whoami
```

## Notes on signing + Keychain access control (planned)

The current implementation stores tokens as generic-password items.

Next step is to:
- codesign `ghw`
- store Keychain items with an ACL restricted to the `ghw` code signature

This prevents other processes from reading tokens via Keychain APIs/`security` without explicit approval.
