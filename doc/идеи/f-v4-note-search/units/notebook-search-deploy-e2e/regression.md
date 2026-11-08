# s15 unit regression — notebook-search-deploy-e2e (E0809 s20, u03)

- **Execution:** `E0809-s20.sde_5fexecution-u03`
- **Step:** `s15.unit_regression` (auditor, independent of `sde-infra`)
- **Unit:** `notebook-search-deploy-e2e` (domain `notebook-e2e`, `plain`)
- **Branch:** `orc-exec-E0809-s20.sde_5fexecution-u03`
- **Base:** `f5943f5ed87e8bbcaadf48ec23dd005ac2c38f95`
- **HEAD:** `5352d4e` (working tree clean at audit start)
- **Auditor session:** `c85a0714-39fe-41b5-959b-3ac8b4841925` (machine `ac20c5a3-012b-452a-b8b8-4adcc202b3e5`)
- **Date:** 2026-11-08 (UTC)

## regression_status: **pass**

**new_findings: []** — no regression introduced by this unit.

The only red command is the pre-existing base oracle **R-1**
(`TestUISemantics`), reproduced unchanged at the unit base and not caused by
u03; see §4.

## 1. Diff scope — PASS

`git diff --name-status f5943f5..HEAD` contains exactly the expected five
feature/doc files plus the unit plan:

| File | Status |
|---|---|
| `web/e2e/notes-search.spec.js` | M |
| `deploy/path1/e2e-preview.sh` | M |
| `doc/идеи/f-v4-note-search/scenarios.json` | M |
| `doc/идеи/f-v4-note-search/scenario-evidence.json` | M |
| `artifacts/units/notebook-search-deploy-e2e/execution-report.md` | A |
| `doc/идеи/f-v4-note-search/units/notebook-search-deploy-e2e/plan.md` | A |

Exclusion check (empty output, rc=0):

```text
$ git diff --name-only f5943f5..HEAD -- . \
    ':(exclude)web/e2e/notes-search.spec.js' \
    ':(exclude)deploy/path1/e2e-preview.sh' \
    ':(exclude)doc/идеи/f-v4-note-search/scenarios.json' \
    ':(exclude)doc/идеи/f-v4-note-search/scenario-evidence.json' \
    ':(exclude)artifacts/units/notebook-search-deploy-e2e/execution-report.md' \
    ':(exclude)doc/идеи/f-v4-note-search/units/notebook-search-deploy-e2e/plan.md'
(no output)
```

No changes to `main.go`, `main_test.go`, `web/index.html`, `web/app.js`,
`web/app.css`, `web_ui_test.go`, `design/**`, `UI-GRAPH.yaml`, or
`web/e2e/auth-notes.spec.js`:

```text
$ git diff --name-status f5943f5..HEAD -- main.go main_test.go web/index.html \
    web/app.js web/app.css web_ui_test.go design UI-GRAPH.yaml
(no output)
```

No auditor code changes and no commit were made in this step.

## 2. Static checks — PASS

| Command | Result |
|---|---|
| `node --check web/e2e/notes-search.spec.js` | OK |
| `bash -n deploy/path1/e2e-preview.sh` | OK |
| `npx --no-install playwright test web/e2e/notes-search.spec.js --list` | `Total: 20 tests in 1 file` |
| `grep -cE '^test\("SEARCH-E2E-' web/e2e/notes-search.spec.js` | `20` |
| `grep -c 'await shot(page, "SEARCH-E2E-' web/e2e/notes-search.spec.js` | `20` |
| `grep -nE '\.(skip|fixme|only)\(|test\.(skip|fixme|only)|describe\.(skip|only)' web/e2e/notes-search.spec.js playwright.config.js` | no matches |

The `--list` output enumerates `SEARCH-E2E-1..20` exactly once each, in order.
No `skip`/`fixme`/`only` directive exists anywhere in the spec or the Playwright
config. `playwright.config.js` sets `forbidOnly` when `CI` is set.

## 3. Scenario manifest + evidence — PASS (truthful pending skeleton)

Python JSON validation:

```text
scenarios count: 20
evidence count: 20
scenario ids exact: True          # SEARCH-E2E-1..20, unique, ordered
evidence ids exact: True
all scenario statuses planned: True
e2e_ref == id: True
evidence execution: E0809
evidence run_at: None
evidence status: pending-s20c
all evidence rows pending/null: True
  (status=pending, screenshot=null, sha256=null, pngdiff=null)
any pass/hash/screenshot fabricated: []
spec test ids exact: True         # 20 top-level test() ids match evidence ids
```

No pass entry, screenshot path, SHA-256, or `pngdiff: OK` is pre-filled.
`scenarios.json` describes intended behaviour (`status: planned`), not an
observed result. This matches the instruction that real 20/20 evidence is an
s20c obligation.

## 4. Commands and results

| Command | Result |
|---|---|
| `go test -count=1 ./...` | **FAIL** — `TestUISemantics`: `app.css missing "min-height: 44px"` |
| `go test -count=1 -skip '^TestUISemantics$' ./...` | **PASS** (rc=0) |
| `go test -count=1 -run 'TestNotesSearch\|TestNotesIsolation\|TestAuthRequired' -v ./...` | **PASS** — 11/11 |
| `node --check web/e2e/notes-search.spec.js` | PASS |
| `bash -n deploy/path1/e2e-preview.sh` | PASS |
| `npx --no-install playwright test web/e2e/notes-search.spec.js --list` | PASS — 20 tests |

### R-1 — pre-existing base failure (not u03)

`TestUISemantics` fails because `web_ui_test.go:264` expects the literal
`min-height: 44px`, while `web/app.css` uses
`min-height: var(--control-height)` (token value `44px` at line 14). Proof that
this predates u03:

```text
$ git diff f5943f5..HEAD -- web_ui_test.go web/app.css
(no output)                    # blobs identical to base

$ git archive f5943f5 | tar -x -C /tmp/kilo/regbase
$ cd /tmp/kilo/regbase && go test -count=1 ./...
--- FAIL: TestUISemantics (0.00s)
    web_ui_test.go:264: app.css missing "min-height: 44px"
FAIL	github.com/ukituki-ps/notebook
```

The failure was introduced by the DS commit `9f9c5d6` replacing the literal with
the DS variable. U02 (`orc-exec-E0809-s20.sde_5fexecution-u02`, `97cf108`)
aligns the oracle to `min-height: var(--control-height)`, so s20b integration
clears it. It is already documented as R-1 in `verify.md` §4 and `quality.md`;
it is **not** a new finding of this audit and not attributable to u03.

## 5. test2-only guard — PASS

Guard exercised before any network call:

```text
BASE=<unset>                                  rc=2  e2e-preview: E2E_BASE_URL не задан
BASE=https://prod.example.com                 rc=2  test2-only guard: host 'prod.example.com' не разрешён
BASE=https://test1.nexus.ukituki.tech         rc=2  test2-only guard: host 'test1.nexus.ukituki.tech' не разрешён
BASE=https://stage.example.com                rc=2  test2-only guard: host 'stage.example.com' не разрешён
BASE=https://canary.example.com               rc=2  test2-only guard: host 'canary.example.com' не разрешён
BASE=https://test2.prod.example.com           rc=2  test2-only guard: запрещённый контур
BASE=https://notebook-stand-test2-prod-1      rc=2  test2-only guard: запрещённый контур
BASE=https://test2.stage.example.com          rc=2  test2-only guard: запрещённый контур
```

Allowed contours are `test2`, `test2.*`, `localhost`, `127.0.0.1`,
`host.docker.internal`, and `notebook-stand-test2-*`; the second case still
rejects prod/stage/canary/test1 inside those. `prod`, `test1`, `stage`, and
`canary` cannot reach the API smoke or Playwright.

Search-smoke order is owner-scope → not-found `[]` → B owner-scope `[]` →
unauth `401` + `WWW-Authenticate` → 513-byte `400 query too long` → 512-byte
`200` array, all before Playwright. Backend corroboration: `main.go`
`maxQueryBytes = 512`, auth before query handling, cap before `ListNotes`; the
11 targeted auth/search Go tests above pass.

## 6. Selector/contract consistency (static, against U02 integration target)

The E2E spec targets the final search UI delivered by U02, which is **not**
present on the u03 base (u03 is based on `f5943f5`, before the U02 branch
`97cf108`). Static cross-check against `97cf108` confirms every selector/copy
used by the spec exists there:

- testids: `notes-search`, `notes-search-clear`, `notes-search-count`,
  `notes-search-empty`, `notes-loading`, `notes-error`, `notes-retry`,
  `notes-offline`, `notes-offline-check`, `note-item`, `delete-note`,
  `note-input`, `add-note`, `logout`;
- copy: `Найдено N`, `Ничего не найдено. Сократите запрос или очистите поиск.`,
  `Пока нет заметок. Добавьте первую выше.`, `Повторить`, both offline variants;
- behaviour: 512-byte cap in `main.go`, `:focus-visible` ring, 640px breakpoint
  → stacked `.notes-search-row`, no-token `notebook.search` cleanup,
  clear → focus search, count/offline/retry/disable wiring.

This is a static compatibility check only; runtime proof remains s20c.

## 7. Residual risks

1. **s20c pending.** No run against `test2` happened in this step. s20c must run
   `E2E_BASE_URL=<test2>` without `E2E_API_ONLY=1`, produce 20/20 screenshots +
   SHA-256 + `pngdiff`, and fill `scenario-evidence.json` (currently
   `run_at=null`, `status=pending-s20c`, all rows pending/null).
2. **Go suite red until U02 integrates (R-1).** `go test ./...` fails only
   `TestUISemantics`; all other tests pass. s20b must merge U02's oracle
   alignment before the full suite can be green. Not attributable to u03.
3. **Integration target is U02 + u03.** The u03 base lacks the count/retry/
   offline UI; running the spec against a stand built from u03 alone will fail
   by design. s20c must use the integrated preview containing U02.
4. **Guard is a contour guard, not an allowlist of one DNS name.** Any
   `test2.*` host and loopback/host-docker aliases are allowed by design for the
   leased stand/local edge. A per-run alias outside those patterns fails closed
   at rc=2 and must be added explicitly, not by weakening the guard.
5. **Stale tracked screenshots.** `SEARCH-E2E-1..6.png` exist at base; the
   evidence references none of them. s20c must overwrite 1–6 and add 7–20; no
   stale frame may be attached to a pass entry.
6. **Local 20-pass claim is not independently reproducible from this audit.**
   `execution-report.md` reports a temporary local run against the U02 build,
   but its artifacts were deleted. It is labelled local and is not used as
   evidence; the evidence file remains a truthful pending skeleton.
7. **Banner annotation is evidence-cosmetic.** The 96px per-scenario strip is
   test-only and does not alter product state; s20c should confirm annotated
   frames are acceptable (or capture unannotated frames) for `pngdiff`.
8. **Plan wording.** `plan.md` T0011 mentions "20 pass entries" for the manifest
   step, while its DoD and this audit require a pending skeleton at s20c. The
   implementation follows the truthful pending requirement; the T0011 wording is
   stale and should not be read as a claim of recorded passes.

**Verdict: pass — diff is in scope, static checks are green, evidence is honest, and
the unit introduces no regression. Runtime acceptance and real evidence remain
the explicit s20c obligation.**
