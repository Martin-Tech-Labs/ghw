# Security

## Threat model

`ghw` is designed for environments where the account running automation is **not fully trusted**, but the installation prefix and the OS admin/root account are trusted.

### We aim to protect against

- Use of `gh auth ...` commands that may store/retrieve credentials implicitly.
- Token leakage via shell-outs to `/usr/bin/security`.
- Accidental use of the wrong identity (requires `--as <alias>` on every command).

### Non-goals

- If **admin/root** is compromised, `ghw` cannot protect secrets.
- `ghw` does not attempt to secure `gh` itself; it constrains how `gh` is invoked.

## Key design points

- Tokens live at rest in **macOS Keychain**.
- `ghw` injects `GH_TOKEN` into the `gh` subprocess environment for a single invocation.
- `ghw` blocks `gh auth ...` and provides `ghw login` as the only way to store tokens.

## Multi-identity

- `--as <alias>` selects a Keychain account entry.
- There is intentionally no default identity.
