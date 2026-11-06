# s15 regression — notebook-search-deploy-e2e

| Field | Value |
|---|---|
| Unit | `notebook-search-deploy-e2e` |
| Feature | `f-v4-note-search` |
| ORC execution | `E8363-s20.sde_5fexecution-u03` |
| Worktree | `/workspace/projects/notebook-e8363-u03` |
| Branch | `orc-exec-E8363-s20.sde_5fexecution-u03` |
| HEAD audited | `6a1a34e81ed45f7f7915dd7d9dff2fc0d6310a24` |
| Auditor | independent (read-only; no git write commands) |
| Scenario ids | `SEARCH-E2E-1..SEARCH-E2E-6` |
| Verdict | **PASS** — no regression, no out-of-scope source change |

## Regression commands and results

Run from the worktree root, toolchain `go1.24.4 linux/amd64`.

| # | Command | Exit | Result |
|---|---|---|---|
| 1 | `go test -count=1 ./...` | `0` | `ok github.com/ukituki-ps/notebook 2.807s` — full suite |
| 2 | `node --check web/e2e/notes-search.spec.js` | `0` | syntax OK, no output |
| 3 | Playwright discovery: pinned CLI `test --list` with `NODE_PATH=/workspace/projects/notebook/node_modules` and the worktree `playwright.config.js` | `0` | `Total: 13 tests in 2 files` — 7 auth + 6 search |
| 4 | `grep -nE 'test\.(skip\|fixme\|only)\|describe\.(skip\|only)\|xit\(\|xdescribe\(' web/e2e/*.js` | n/a | no matches — no bypass markers in either spec |
| 5 | `git diff f-v3-base...feature -- web/e2e/auth-notes.spec.js` | n/a | empty — auth E2E spec byte-identical |

Playwright listing at HEAD:

```
[chromium] › auth-notes.spec.js:67:1 › E2E-1 register ...
[chromium] › auth-notes.spec.js:82:1 › E2E-2 login and token ...
[chromium] › auth-notes.spec.js:96:1 › E2E-3 create note ...
[chromium] › auth-notes.spec.js:108:1 › E2E-4 reload ...
[chromium] › auth-notes.spec.js:121:1 › E2E-5 delete note ...
[chromium] › auth-notes.spec.js:135:1 › E2E-6 isolation ...
[chromium] › auth-notes.spec.js:168:1 › E2E-7 unauthenticated GET 401 ...
[chromium] › notes-search.spec.js:122:1 › SEARCH-E2E-1 ...
[chromium] › notes-search.spec.js:141:1 › SEARCH-E2E-2 ...
[chromium] › notes-search.spec.js:161:1 › SEARCH-E2E-3 ...
[chromium] › notes-search.spec.js:180:1 › SEARCH-E2E-4 ...
[chromium] › notes-search.spec.js:204:1 › SEARCH-E2E-5 ...
[chromium] › notes-search.spec.js:233:1 › SEARCH-E2E-6 ...
Total: 13 tests in 2 files
```

### Existing auth E2E not weakened

- `web/e2e/auth-notes.spec.js` has **no feature diff** and still declares the
  full `E2E-1..E2E-7` set.
- Both specs contain no `skip`/`fixme`/`only`/`xit`/`xdescribe` markers.
- Search discovery is additive: 6 new tests, existing 7 remain listed; the
  search spec registers its own users/notes and does not alter auth scenarios.

## Out-of-scope check

- Worktree source status vs HEAD: **clean** — only `artifacts/units/**` files
  differ; no `web/e2e/**`, deploy, package, or app-source file is dirty.
- Branch delta vs feature base `9ceafdb` (committed):
  `s10-unit-plan.md` (A), `s11-execution.md` (A), `s12-check.md` (M) —
  artifact files only.
- Feature code delta (base `dev/f-v3-auth-notes` → `9ceafdb`/validation-zero)
  for unit u03: `web/e2e/notes-search.spec.js` only — **exactly the allowed
  scope**.
- No `deploy/**` change: `deploy/path1/e2e-preview.sh` and
  `preview-deploy.sh` are absent from the feature diff.
- No package change: `package.json` and `package-lock.json` are absent from the
  feature diff; Playwright stays pinned at the existing `1.64.1`.
- `path1.project.json` / `path1.ui.json` / `playwright.config.js` unchanged by
  this feature relative to the base.

## Regression/out-of-scope findings

None. No new findings.

## Residual risk / deferred gate

- The live browser run against the `test2` stand is s20c and was not performed
  here. This audit proves discovery, syntax, Go regression, auth-spec integrity
  and configuration scope; it does not claim live browser behavior.
- In-worktree `npx` cannot resolve Playwright because the worktree has no local
  `node_modules` (gitignored); discovery was therefore proven with the pinned
  package from the main project, which is the same `1.64.1` version.
