# New path-1@4.0.0 run — BLOCKER at ORC preflight (E4071)

- Date: 2026-11-08
- Branch pushed: `dev/f-v4-note-search-fix` @ `9bbe7d3468432c6d4a139d8c5631821ea9ff6cd7`
- Target process: `path-1.feature@4.0.0`, entry `default`
- ORC: `dev-ORC 8390` (`http://192.168.1.20:8390/mcp`)

## Symptom

`orc_start` fails before creating an execution:

```
[invalid_state] DS preflight: cannot read design/releases on dev/f-v4-note-search-fix: exit status 128 (E4071)
```

## Root cause (verified read-only through ORC)

On the ORC host the project repo is:

- root: `/app/orc-repos/f41f0adb-67d9-4ddf-8ba9-0efd9c6e50a9`
- `.git/HEAD` → `ref: refs/heads/dev/f-v4-note-search`
- `.git/packed-refs` contains only `refs/remotes/origin/main`
- `.git/refs/heads/dev/f-v4-note-search-e2e` → `41a1141` (old)
- no `refs/heads/dev/f-v4-note-search-fix`, no `design/releases/1.0.1/manifest.json` in the working tree

So `git show dev/f-v4-note-search-fix:design/releases/...` exits 128. The branch exists
on `origin` (`git ls-remote` returns `9bbe7d3`), but the ORC checkout was never
fetched/provisioned for it.

The same missing ref blocks `orc_human_request` for the v7 manifest:

```
[internal_error] orc_human_request: read artifact
/app/orc-repos/f41f0adb-67d9-4ddf-8ba9-0efd9c6e50a9/doc/идеи/f-v4-note-search/prototypes/v7/manifest.json:
no such file or directory
```

## Required host-side remediation (exact command)

Run on the ORC host as the ORC service user, then retry `orc_start`:

```bash
git -C /app/orc-repos/f41f0adb-67d9-4ddf-8ba9-0efd9c6e50a9 fetch origin \
  dev/f-v4-note-search-fix:refs/heads/dev/f-v4-note-search-fix
git -C /app/orc-repos/f41f0adb-67d9-4ddf-8ba9-0efd9c6e50a9 rev-parse \
  dev/f-v4-note-search-fix   # must print 9bbe7d3468432c6d4a139d8c5631821ea9ff6cd7
```

Then the s03b approval can be requested for:
`doc/идеи/f-v4-note-search/prototypes/v7/manifest.json` (subject `prototype`,
subject_ref `notebook/prototype`, branch `dev/f-v4-note-search-fix`).

## What is already done and verified locally

- `dev/f-v4-note-search-fix` @ `9bbe7d3` pushed to origin.
- CR-01/02/03 E2E regressions added; full local suite 30/30 passed on `:9082`.
- `go test ./...` OK; `node --check web/app.js` OK.
- `ds-token-drift` implemented in `tools/path1-gate.sh` + `tools/check-ds-token-drift.py`;
  PASS (20 checks); negative test fails closed.
- DS pin/lock/component-refs/design-review moved to Notebook DS 1.0.1
  (`digest sha256:4e0ef105…`); `ds-pin`, `design-integrate`, `unit-ds-lock`,
  `unit-proto-coverage`, `design-review ui/ux` PASS.
- Prototype v7 created with 16 exports; independent UI and UX sessions
  re-reviewed and accepted (0 blockers / 0 majors; minors fixed or accepted).
- The only open item is P-99 (signed approval), blocked by the repo sync above.

## Not started (blocked)

- New ORC execution (no execution id was created).
- s02a → s24 run, s19 test2 lease, s20b/s20c stand evidence, s22a/s22e/s24 gates.
- Bookkeeping (fault verdicts `na`→`covered`, 8 UI invariants `proposed`→`active`)
  is deferred: it needs the new s20c stand evidence, not fake local evidence.
