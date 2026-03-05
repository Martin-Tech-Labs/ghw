# Pull requests

Use the org PR template as the baseline (adjust org/owner as needed):
- https://github.com/<org>/.github/blob/main/pull_request_template.md

## Minimum requirements

- Include the Jira key when applicable (e.g. `OPS-123`) in:
  - branch name, and/or
  - PR title
- Fill the template sections:
  - summary + context
  - test plan

## How to open a PR (always via ghw)

Example:

```bash
# Create branch
git checkout -b OPS-123-short-title

# Commit work
git commit -am "OPS-123: Do the thing"

# Push branch
# (always pass --as)
ghw --as <profile> repo view <owner>/<repo>
git push -u origin HEAD

# Create PR
# (always pass --as)
ghw --as <profile> pr create \
  --title "OPS-123: Short title" \
  --body-file .github/pull_request_template.md
```

Notes:
- `--body-file` should point at the template file in the repo.
- If the repo relies on the org-level template only, copy it into the repo first.
