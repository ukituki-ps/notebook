# Change-definition review — f-v4-note-search (s10.change_definition)

- **Step:** `s10.change_definition`
- **Execution:** `E8363`
- **Feature:** `f-v4-note-search`
- **Platform:** `web` (`path1.ui.json.platform = "web"`, `feature_profile = full`)
- **Branch (this pass):** `dev/f-v4-note-search-validation-zero`
- **Base:** `5935e148` (`5935e148584b5fef28bd77ac4e45b800f10da03b`)
- **Pass type:** fresh E8363 re-validation of the existing change definition
  against the code at this head. Only `change-definition.md` and this review were
  written; no platform, path-1, auth, or persistence change was made.

## Verdict

**PASS** — the change definition is accurate for E8363 after metadata and scope
corrections. All five domains are identified, every C1–C4 change has
before/after, files, and executable acceptance refs, and "Not in scope" matches
the raw-request constraints (R41–R45) plus the interface freeze and OD-6.

No blocking drift remains. The material corrections are:

1. **C4 no longer claims a search API smoke** that `e2e-preview.sh` does not
   contain. The integration command is auth/notes API-only in
   `E2E_API_ONLY=1` mode; search E2E is Playwright at s20c.
2. **C3 no longer claims the search spec covers user-B isolation.** The six
   search scenarios cover find / not-found / case / clear / create-active /
   delete-active; user-B isolation remains auth E2E-6 plus
   `TestNotesSearchIsolation`.
3. **C2 now states the full empty-state guard** (non-empty trimmed query,
   non-empty loaded collection, zero matches) and labels the `sessionStorage`
   reload-restore as an implementation convenience (OD-6), not contract.

## Inputs reviewed

All paths relative to `/workspace/projects/notebook-valzero/`.

| Input | Role | Observed state |
|---|---|---|
| `doc/идеи/f-v4-note-search/feature-brief.md` | Final brief (s06/E8363) | FINAL; API table, search semantics, 10-state wireframes, AC 1–6; OD-6 explicitly not contractual |
| `doc/идеи/f-v4-note-search/intent-brief.md` | E8363 intent brief | R01–R45 asked→doing; refinements listed; OD-6 proposed "do not persist" |
| `doc/идеи/f-v4-note-search/intent-trace.json` | E8363 machine trace | `execution_id: E8363`, branch `validation/platform-dev-20261106-zero`, base `5935e148…`; 45 items; OD-6 needs-human |
| `doc/идеи/f-v4-note-search/invariants.json` | E8363 invariants | 16 active + 2 proposed; all active have `test_ref`; search + UI sets present |
| `doc/идеи/f-v4-note-search/scope-report.md` | Scope/impact | 4 domains; constraints 1–7; OD-1/OD-2 closed; 3-unit recommendation |
| `doc/идеи/f-v4-note-search/expertise-report.md` | Prior architect validation | B-1…B-9; OD-1/OD-2 closed; interface freeze |
| `doc/идеи/f-v4-note-search/plan.md` | Plan (prior run) | U01/U02/U03; T0001 "Store/List search helper"; T0009 "API smoke + adapter" |
| `doc/идеи/f-v4-note-search/change-definition.md` | Subject | Updated in this step: E8363 header, five domains, C1–C4 before/after/files/acceptance, Not in scope |
| `main.go` | API implementation | `handleNotes` 529–565; `q` trim/lower 535–549; `ListNotes` owner filter 194–205 |
| `main_test.go` | Backend tests | `TestNotesSearchFinds` 933 … `TestNotesSearchEncoding` 1069 (8 tests) |
| `web/index.html` | UI markup | `notes-search`, `notes-search-clear`, `notes-search-empty`; search above list |
| `web/app.js` | UI behaviour | `filterNotes` 362–368; `renderNotes` 372–390; load/create/delete re-render; search/clear wiring 559–575 |
| `web/app.css` | UI styling | Search rules 185–213; `.notes-search-empty` rule present but unused by the DOM |
| `web_ui_test.go` | Static UI oracle | `TestUISemantics` asserts testids, label, `type=search`, `aria-controls`, empty-state separation |
| `web/e2e/notes-search.spec.js` | Search E2E | `SEARCH-E2E-1..6`; no skips/fixmes |
| `web/e2e/auth-notes.spec.js` | Auth/notes E2E | E2E-1..7; E2E-2 login, E2E-6 user-B isolation |
| `path1.project.json` | Path-1 config | `integration: E2E_API_ONLY=1 bash deploy/path1/e2e-preview.sh`; `UI-E2E-PREVIEW` oracle; no search-specific config |
| `deploy/path1/e2e-preview.sh` | Deploy/E2E harness | Auth/notes API smoke only; full Playwright run unless `E2E_API_ONLY=1`; no `q=` search smoke |
| `platform-dev-validation-zero/s05–s07` | E8363 design/trace context | OD-6 needs-human; B-3/B-6/B-7 refinements surfaced |

## Domains

| Domain | Surface | Verdict |
|---|---|---|
| `notebook-api` | `main.go` (`GET /api/notes` `q` parsing + owner-scoped filter), `main_test.go` | PRESENT / ACCURATE |
| `notebook-web` | `web/index.html`, `web/app.js`, `web/app.css` (search markup, filter, clear, empty states) | PRESENT / ACCURATE |
| `notebook-tests` | `main_test.go`, `web_ui_test.go`, `web/e2e/notes-search.spec.js` | PRESENT / ACCURATE |
| `notebook-deploy` | `deploy/path1/e2e-preview.sh` (unchanged), `path1.project.json` (no semantic change) | PRESENT / ACCURATE (corrected from overclaim) |
| `path1-adapter` | `doc/идеи/f-v4-note-search/UI-GRAPH.yaml` (planned E8363, actualized s21) | PRESENT / ACCURATE |

Surface correction: `web_ui_test.go` is listed under `notebook-tests`, not
`notebook-web`; it is a Go static oracle, not a web asset. `main_test.go` remains
under both `notebook-api` (test of the API change) and `notebook-tests` (test
surface), which is intentional.

## C1–C4 acceptance check

| Change | Before → After | Files | Acceptance refs |
|---|---|---|---|
| C1 `GET /api/notes?q=` | no query → optional trimmed `q`; empty/whitespace all own notes; non-empty case-insensitive substring; `[]` not `null`; auth before query; owner first | `main.go`, `main_test.go` | 8 `TestNotesSearch*` tests; `TestHTTPTransport`; `INV-SEARCH-OWNER-SCOPE`, `INV-SEARCH-CASE-INSENSITIVE`, `INV-SEARCH-EMPTY-Q`, `INV-SEARCH-NOT-FOUND`, `INV-SEARCH-AUTH-REQUIRED`, `INV-SEARCH-ENCODING`, `INV-WIRE-CASING` |
| C2 Notes search UI | no search → labelled input, client-side filter, separate clear, search-empty over a non-empty collection, `notes-empty` for genuinely empty; create/delete re-render; reload restore is OD-6 convenience | `web/index.html`, `web/app.js`, `web/app.css` | `TestUISemantics`; `INV-SEARCH-UI-FILTER`, `INV-SEARCH-UI-EMPTY`, `INV-SEARCH-UI-TESTIDS`, `INV-UI-LABEL`, `INV-UI-A11Y-NAME`, `INV-UI-TRUTH`; `SEARCH-E2E-1..6` |
| C3 Tests/E2E | 7 auth E2E + auth/notes Go tests → +8 search Go tests, +`TestUISemantics` search assertions, +6 Playwright search scenarios; user-B isolation remains auth E2E-6 | `main_test.go`, `web_ui_test.go`, `web/e2e/notes-search.spec.js` | `go build ./...`, `go vet ./...`, `go test -count=1 ./...`; Playwright full/targeted suite; `SEARCH-E2E-1..6`; auth E2E-6; `pngdiff` |
| C4 Adapter/preview | auth/notes API smoke + auth E2E → no search API smoke added; Playwright auto-discovers the new spec; `path1.project.json` unchanged semantically; graph actualized s21 | `deploy/path1/e2e-preview.sh` (unchanged), `path1.project.json` (no semantic change), `UI-GRAPH.yaml`, `playwright.config.js` (unchanged) | `E2E_API_ONLY=1 bash deploy/path1/e2e-preview.sh`; `E2E_BASE_URL=<test2> npx --no-install playwright test` at s20c; `UI-E2E-PREVIEW` oracle; s20b preview; s21 graph gate; `pngdiff` |

Every C1–C4 entry now has before, after, files, and concrete acceptance refs.
The acceptance refs resolve to existing test functions, spec files, shell
commands, or gate names at this head.

## Drift findings

### D-1 — C4 integration-smoke overclaim (material, corrected)

The prior change definition said "integration smoke includes unauth 401 and
search find/not-found." At this head, `deploy/path1/e2e-preview.sh` contains the
health/auth/notes API smoke but **no `q=` search find/not-found assertion**. In
`E2E_API_ONLY=1` mode it exits after the API smoke; the full Playwright suite is
what exercises search at s20c. The change definition now states this accurately.

### D-2 — C3 E2E coverage overclaim (material, corrected)

The prior C3 said the Playwright search spec covers "login, 2 notes, find one,
find none, clear returns both, user B isolation." Actual `notes-search.spec.js`
has six scenarios: find, not-found/empty, case-insensitive, clear, create while
active, delete while active. Login and two-note setup are preconditions in each
test; **user-B isolation is auth E2E-6**, not a search-spec scenario. C3 now
distinguishes the two specs. Raw-request E2E scenarios R32–R37 remain covered
across `auth-notes.spec.js` + `notes-search.spec.js`.

### D-3 — C2 empty-state condition under-specified (corrected)

The prior C2 said `notes-search-empty` is shown "only for a non-empty query with
no matches." The code requires `hasQuery && !noNotes && visible.length === 0`
(`web/app.js` 386–388); a genuinely empty server list shows `notes-empty`, not
`notes-search-empty`. C2 now records the full guard.

### D-4 — C2 reload persistence vs OD-6 (clarified)

`web/app.js` persists the query in `sessionStorage` `notebook.search` and
restores it on load. That is real code behaviour, but s07 explicitly proposes
**not** making it contractual (OD-6, needs-human). The change definition labels
it an implementation convenience and lists query persistence in "Not in scope".

### D-5 — Plan-vs-code drift (non-blocking, s14 alignment)

`plan.md` (prior E9294 run) says T0001 "Store/List search helper" and T0009
"API smoke + adapter" / verification "search find/not-found" on the stand. At
this head, the filter is handler-level on the `ListNotes` snapshot
(`main.go` 535–549), and the integration smoke has no search `q=` assertion.
The change definition follows the code; s14 should align the plan/spec wording
and not reintroduce a search API smoke requirement.

### D-6 — Metadata/branch label drift (non-blocking)

The change-definition header is now E8363 / `dev/f-v4-note-search-validation-zero`
/ `5935e148` per this step's instruction. `plan.md` still records E9294 /
`dev/f-v4-note-search` / `406fa965`; `s06`/`s07` and `intent-trace.json` record
the validation branch `validation/platform-dev-20261106-zero` with the same base
`5935e148…`. These are prior/parallel branch labels, not code drift. s14 should
use one branch label consistently in the final spec record.

### D-7 — Minor presentation/CSS drift (non-blocking)

`web/app.css` defines `.notes-search-empty`, but the DOM element uses
`class="muted"`; the rule is unused (s03 D-6). No functional impact and no
change-definition correction needed beyond keeping `web/app.css` in the
`notebook-web` surface.

### D-8 — "Not in scope" coverage (verified)

The updated list covers the raw-request constraints: R41 auth/persistence, R42
no unrelated refactors, R43 f-v3, R44 E4312/E1320, R45 test2-only/no prod/canary,
plus R5/R8 (s45/s46, prod/main/stage/canary) and R38/R39 (Playwright/package
lock). It adds the interface freeze (no new endpoint/auth header/CORS; POST/DELETE
unchanged) and OD-6 (no contractual reload persistence). No raw-request
constraint is missing.

## Verdict and conditions

**PASS.** The five-domain change definition is accurate for E8363 after the
metadata and scope corrections above. There are no blocking drift findings.

Conditions for later steps:

1. **s14** should use the corrected C4 wording (no search API smoke) and align
   `plan.md` T0001/T0009/verification language with the handler-level filter and
   Playwright-only search E2E.
2. **s14** should settle the branch-label metadata (E8363 validation branch vs
   `validation/platform-dev-20261106-zero`) in one place.
3. **s08** should resolve OD-6; the change definition already treats reload
   persistence as non-contract.

## Limitations

- Per instruction, **no git commands were run**; verification is against the
  working tree at this head, not a base diff.
- Historical execution IDs and branch labels in `plan.md`, `expertise-report.md`,
  `invariants.json`, `intent-trace.json`, and `s06`/`s07` are prior/parallel-run
  metadata. They were not re-stamped; this review records the E8363
  change-definition state.
- Only two files were written: `change-definition.md` and this review. No
  source, CSS, graph, spec, invariant, or path-1 file was modified.
