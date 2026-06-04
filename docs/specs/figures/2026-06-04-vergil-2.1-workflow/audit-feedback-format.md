# `.vergil/audit-feedback.yml` format

Written by the `audit` skill, read by the `implement` skill. Minimal YAML
subset (flat keys, `key: |` blocks), written atomically (temp file + `mv`).
Sibling of `pr-template.yml`; never folded into it.

```yaml
verdict: approve            # approve | changes  (ERROR = file withheld, human alerted)
commits:                    # SHAs reviewed this round (the audit trail on approve)
  - <full-sha>
findings:                   # present only when verdict: changes
  - severity: warning       # warning (fix & re-update) | info
    file: path/to/file.py
    line: 42
    note: |
      Removable `# type: ignore` — add the real return type instead of
      suppressing MyPy.
```

## Semantics

- `verdict: approve` — all listed `commits` are signed off; the local loop ends.
- `verdict: changes` — the USER agent fixes every `findings` entry,
  re-validates, rewrites `pr-template.yml`, and the audit re-reviews.
- **ERROR (new unapproved suppression, or unfixable issue needing the human):**
  the audit does **not** write this file. It alerts the human and stops; the
  USER agent stays parked on its `vrg-await`. Silence is the signal.

See the design spec
[§5](../../2026-06-04-vergil-2.1-workflow-and-skill-rationalization-design.md)
and [§7](../../2026-06-04-vergil-2.1-workflow-and-skill-rationalization-design.md)
for the surrounding loop and the audit feedback model.
