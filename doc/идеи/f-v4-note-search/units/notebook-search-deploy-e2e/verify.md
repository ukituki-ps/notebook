# s13 unit verify — notebook-search-deploy-e2e (E0809 s20, u03)

- **Execution:** `E0809-s20.sde_5fexecution-u03`
- **Step:** `s13.unit_verify` (architect ≠ executor `sde-infra`)
- **Unit:** `notebook-search-deploy-e2e` (domain `notebook-e2e`, change class `plain`)
- **Branch:** `orc-exec-E0809-s20.sde_5fexecution-u03`
- **Base:** `f5943f5ed87e8bbcaadf48ec23dd005ac2c38f95`
- **HEAD:** `5352d4e` (clean working tree)
- **verified_by:** `architect`
- **Date:** 2026-11-08 (UTC)

## Verdict: **pass**

All unit deliverables are present and statically consistent with T0103 and the unit
plan. Runtime proof on `test2` is correctly deferred to s20c; this step did not run
the suite against the stand. One pre-existing workspace test failure is recorded
below and is **not** attributable to this unit.

## Scope checked

Diff `f5943f5..HEAD` touches only the four unit feature files plus two docs:

| File | Status |
|---|---|
| `web/e2e/notes-search.spec.js` | modified (8 → 20 scenarios) |
| `deploy/path1/e2e-preview.sh` | modified (test2 guard + search API smoke) |
| `doc/идеи/f-v4-note-search/scenarios.json` | modified (20 planned entries) |
| `doc/идеи/f-v4-note-search/scenario-evidence.json` | modified (truthful pending skeleton) |
| `artifacts/units/notebook-search-deploy-e2e/execution-report.md` | added |
| `doc/идеи/f-v4-note-search/units/notebook-search-deploy-e2e/plan.md` | added |

No changes to `main.go`, `main_test.go`, `web/index.html`, `web/app.js`,
`web/app.css`, `web_ui_test.go`, `design/**`, `UI-GRAPH.yaml`, or
`web/e2e/auth-notes.spec.js`:

```text
$ git diff --name-only f5943f5..HEAD -- main.go main_test.go web/index.html \
    web/app.js web/app.css web_ui_test.go design '**/design/**' UI-GRAPH.yaml \
    web/e2e/auth-notes.spec.js
(no output)
```

## 1. Playwright spec — PASS

```text
$ grep -cE '^test\("SEARCH-E2E-' web/e2e/notes-search.spec.js
20

$ grep -nE 'test\.(skip|fixme|only)|describe\.(skip|only)|\bxit\(|\bxdescribe\(' \
    web/e2e/notes-search.spec.js
(no matches)

$ grep -c 'await shot(page, "SEARCH-E2E-' web/e2e/notes-search.spec.js
20

$ npx --no-install playwright test web/e2e/notes-search.spec.js --list
Listing tests:
  [chromium] › notes-search.spec.js:173:1 › SEARCH-E2E-1 search finds matching note
  ...
  [chromium] › notes-search.spec.js:749:1 › SEARCH-E2E-20 owner scope B never sees user A notes
Total: 20 tests in 1 file
```

- Exactly 20 top-level `test()` calls, IDs `SEARCH-E2E-1..20`, each with one
  scenario-specific `shot(page, "SEARCH-E2E-N")`.
- No `skip`, `fixme`, `only`, `xit`, or `xdescribe`.
- Scenarios 9–20 cover the required additions (count, zero-notes, loading,
  error/retry, offline loaded, offline-zero, XSS, keyboard/aria, 512-byte cap,
  390/1200 layout, clear focus, owner-scope B). Scenarios 1–8 retain the prior
  find/empty/case/clear/create/delete/whitespace/no-token coverage.

## 2. Deploy script + API smoke — PASS

`bash -n deploy/path1/e2e-preview.sh` → OK.

Static review confirms the required order and assertions:

- `E2E_BASE_URL` is required (`rc=2` when absent).
- test2-only allowlist is enforced before any network call; prod/stage/canary/
  test1 are rejected:
  - no `E2E_BASE_URL` → `rc=2`
  - `https://prod.example.com` → `rc=2` (`host 'prod.example.com' не разрешён`)
  - `https://test1.nexus.ukituki.tech` → `rc=2`
  - `https://canary.example.com` → `rc=2`
- Auth-before-query: unauthenticated `GET /api/notes?q=...` → `401` with
  `WWW-Authenticate: Bearer` (lines 184–189).
- Owner scope: A finds A's note; not-found returns literal `[]`; B searching A's
  text returns `[]` (lines 163–182).
- 512-byte cap: 513 decoded bytes → `400 {"error":"query too long"}`; exactly 512
  bytes → `200` JSON array (lines 191–208).
- API smoke runs before the Playwright entry (line 261 vs lines 296–298).
- Playwright remains fail-close on missing node/npm/browser/spec.

Backend corroboration in `main.go`: `maxQueryBytes = 512` (line 33), auth via
`requireAuth` before method/query handling (line 536), length check before
`ListNotes` scan (lines 541–545).

## 3. Manifest + evidence — PASS

```text
scenarios count: 20
ids: SEARCH-E2E-1..20 (unique, ordered)
all have given/when/then/e2e_ref: True
statuses: ['planned']

evidence scenarios: 20
execution: E0809
run_at: null
status: pending-s20c
evidence statuses: ['pending']
all screenshot/sha256/pngdiff null: True
stale E8895 data: False
```

Evidence is honest: it is a skeleton for s20c, not a claimed pass. No screenshot,
hash, or `pngdiff` verdict is fabricated.

## 4. Commands — PASS (with one pre-existing base failure recorded)

| Command | Result |
|---|---|
| `node --check web/e2e/notes-search.spec.js` | OK |
| `bash -n deploy/path1/e2e-preview.sh` | OK |
| `npx --no-install playwright test web/e2e/notes-search.spec.js --list` | 20 tests in 1 file |
| `go test -count=1 ./...` | **FAIL** `TestUISemantics` (`web_ui_test.go:264: app.css missing "min-height: 44px"`) |

The Go failure is **pre-existing at the unit base** and unrelated to u03:

- `web/app.css` and `web_ui_test.go` blobs at HEAD are identical to base
  (`97fc1de…` and `0df00ae…`), and u03 does not touch them.
- Running `go test -count=1 ./...` in a detached worktree at base `f5943f5`
  reproduces the same failure.
- This is the known R-1 blocker documented in `spec/core.md` §3.6: the oracle
  expects a literal `min-height: 44px` while the DS token is
  `min-height: var(--control-height)`. U02 aligns the oracle to the DS token
  (`orc-exec-E0809-s20.sde_5fexecution-u02:web_ui_test.go` requires
  `min-height: var(--control-height)`), so integration of U02 clears it. It is a
  coordination residual for s20a/s20c, not a defect introduced by this unit.

## Residuals

1. **Runtime deferred to s20c:** the 20 scenarios and the full API smoke have not
   been executed against `test2` in this step. s20c must run with
   `E2E_BASE_URL=<test2>` (no `E2E_API_ONLY=1`) and populate real 20/20 evidence.
2. **Go suite red until U02 integrates:** see R-1 above. Not caused by u03.
3. **Stale tracked screenshots:** `doc/идеи/f-v4-note-search/screenshots/
   SEARCH-E2E-1..6.png` exist at base and are still tracked, but
   `scenario-evidence.json` references none of them (all fields `null`). s20c must
   overwrite them and add 7–20; no stale frame may be attached to a pass entry.
4. No code changes and no commit were made by this verification.
