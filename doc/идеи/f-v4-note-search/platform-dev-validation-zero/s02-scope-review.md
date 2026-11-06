# Scope review — f-v4-note-search (s02.architect_scope_analysis)

- **Step:** `s02.architect_scope_analysis`
- **Execution:** `E8363`
- **Feature:** `f-v4-note-search`
- **Platform:** `web` (`path1.ui.json.platform = "web"`, same-origin static UI, `feature_profile = full`)
- **Branch (this pass):** `validation/platform-dev-20261106-zero`
- **Pass type:** fresh re-validation of the unchanged `scope-report.md` against the
  code at this head. Nothing was rewritten; this review is the only artifact
  produced by this step.

## Verdict

**PASS** — `scope-report.md` still names the affected domains, constraints,
conflicts, and recommendations for a web-only, owner-scoped note search, and the
code at this head implements that scope without material drift.

One **non-blocking descriptive drift** was found (lock wording, D-1 below). It
changes no behavior, contract, or gate; it is a documentation accuracy issue in
an immutable s02-era artifact, not a scope change.

## Inputs reviewed

All paths relative to `/workspace/projects/notebook-valzero/`.

| Input | Role | Observed state |
|---|---|---|
| `doc/идеи/f-v4-note-search/feature-request.md` | Immutable raw request | 45 items; backend 12–23, UI 24–30, deploy/E2E 31–40, constraints 41–45; unchanged |
| `doc/идеи/f-v4-note-search/feature-brief.md` | Final brief (s06) | Goal/scope, API contract table, search semantics, UX, wireframes, AC 1–6, invariants |
| `doc/идеи/f-v4-note-search/scope-report.md` | Subject of this review | 4 domains, constraints 1–7, architecture notes, OD-1/OD-2, conflicts, 3-unit recommendation |
| `path1.project.json` (repo root) | Path-1 project config | `e2e.frontend_dir=web`, `deploy`/`integration` commands, 17 audit oracles; no search-specific semantic change |
| `main.go` (repo root) | Backend | `handleNotes` at 529–565; `q` parsing 535–549; `ListNotes` 194–205 |
| `web/index.html` | Web markup | `notes-search`, `notes-search-clear`, `notes-search-empty`; search above list |
| `web/app.js` | Web behavior | `noteSearchText`/`filterNotes`/`renderNotes` 353–390; input/clear wiring 559–575 |
| `doc/идеи/f-v4-note-search/spec/core.md` | Spec (s14) | API §1.1, UI §3, invariants §4, contract diff §5 |
| `doc/идеи/f-v4-note-search/spec/contract-matrix.md` | Contract matrix (s14) | 19 endpoint rows + negative/edge cases; test names map to existing Go tests |
| `doc/идеи/f-v4-note-search/plan.md` | Plan (s13) | Units U01 `notebook-search-api`, U02 `notebook-search-ui`, U03 `notebook-search-deploy-e2e` |
| `doc/идеи/f-v4-note-search/UI-GRAPH.yaml` | UI graph (s21) | `status: actualized`, `platform: web`, search idle/filtering/results/empty/cleared/after-mutation |
| `doc/идеи/f-v4-note-search/invariants.json` | Machine invariants | 16 active + 2 proposed; search owner/case/empty/not-found/encoding/UI entries active |
| `path1.ui.json` (repo root) | Platform declaration | `platform: "web"` |
| `deploy/path1/e2e-preview.sh` | Deploy/E2E harness | Auth/API smoke + full Playwright run; no dedicated `q=` shell smoke (see D-2) |
| `web/e2e/notes-search.spec.js` | Search E2E | SEARCH-E2E-1..6; no skips/fixmes |
| `web_ui_test.go` | Static UI oracle | `TestUISemantics` asserts testids, label, type=search, empty-state separation |

Supporting cross-checks (read-only): `platform-dev-validation/REPORT.md`,
`platform-dev-validation-zero/s01-product-review.md`,
`main_test.go` search tests 933–1091, `package.json`/`package-lock.json`,
`web/app.css`, `playwright.config.js`.

## Affected domains — still named and still accurate

| Domain named in `scope-report.md` | Code at this head | Status |
|---|---|---|
| **notebook-api** — `main.go`, `main_test.go` | `GET /api/notes` parses `q`, trims/lowercases, calls `ListNotes(session.UserID)` first, then substring-filters; 8 `TestNotesSearch*` tests exist | MATCH |
| **notebook-web** — `web/index.html`, `web/app.js`, `web/app.css`, `web/e2e/notes-search.spec.js` | Search input + clear + empty state; client-side filter/clear/re-render; CSS rules; 6 search E2E scenarios | MATCH |
| **notebook-deploy** — `deploy/path1/e2e-preview.sh` (conditional), `path1.project.json` (no semantic change) | Harness runs auth/API smoke and the full Playwright suite (which includes the search spec); integration command present; no semantic config change | MATCH (conditional part correctly not added) |
| **docs/graph** — `UI-GRAPH.yaml` | `status: actualized`, web, all search states and testids | MATCH |

No new domain is needed. Auth, session, token, storage, and note lifecycle
domains remain untouched, as the report states.

## Constraints — verified

| # | Constraint | Evidence at this head | Status |
|---|---|---|---|
| 1 | Auth/session/token/storage frozen; search is a read-only projection | `ListNotes` unchanged; handler filters a copy; no store mutation on GET; no new fields | HOLDS |
| 2 | Auth guard order auth → method → query | `requireAuth` is first in `handleNotes`; query read only inside `case GET` | HOLDS |
| 3 | Owner predicate first; `q` can only narrow | `ListNotes(session.UserID)` runs before the query loop; `TestNotesSearchIsolation` asserts no cross-user leak | HOLDS |
| 4 | No new dependencies (`go.mod` unchanged), no framework/bundler | `go.mod` is module + `go 1.23` only; UI is plain JS/CSS served from `embed` | HOLDS |
| 5 | Playwright 1.64.1; package/lock not rolled back | `package.json` and lock pin `@playwright/test`/`playwright`/`playwright-core` 1.64.1 | HOLDS |
| 6 | Preview only on `test2`; prod/main/stage and canary out | `path1.project.json` has `test2` stand/integration wiring only; no prod/canary change | HOLDS |
| 7 | `f-v3-auth-notes`, `E4312`, `E1320` not modified | No f-v3 path is changed by this feature set in the current tree; execution-level immutability is not re-verifiable without git (see Limitations) | HOLDS (current tree) |

## Conflicts / risks — still valid, mitigations present

1. **Filter-before-owner leak risk.** Mitigation is present: owner predicate is
   inside `ListNotes` before the query loop, plus `TestNotesSearchIsolation`
   (both directions A/B, and a `UserID` wire-leak check).
2. **UI filter hiding mutations.** Mitigation is present: load/create/delete all
   funnel through one `renderNotes()` → `filterNotes()` path, and
   SEARCH-E2E-5/SEARCH-E2E-6 exercise create/delete with an active query.
3. **E2E runner dependency drift.** Mitigation is present: Playwright is a
   test-only devDependency pinned at 1.64.1; `playwright.config.js` has no
   `test.skip`/`test.fixme` escape hatch and the shell harness is fail-close.

## Ambiguities / decisions — closed and reflected in code

- **OD-1 (whitespace-only `q`):** code does `TrimSpace` before the empty check,
  so absent/`q=`/whitespace all return all own notes. Tests:
  `TestNotesSearchEmptyQuery`, `TestNotesSearchWhitespaceQuery`. MATCH.
- **OD-2 (server query vs client filter):** both exist — server `q` contract in
  `main.go` and `TestNotesSearch*`; UI filters the already-loaded owner-scoped
  list in `web/app.js` with no request per keystroke. MATCH.
- **Recommendation (3 units / no auth-persistence unit):** `plan.md` defines
  exactly U01 `notebook-search-api`, U02 `notebook-search-ui`, U03
  `notebook-search-deploy-e2e`; there is no auth/storage unit or migration. MATCH.

## Drift findings

### D-1 — Non-blocking: lock wording in the architecture notes

`scope-report.md` says: *"Filtering is done while holding the same lock used by
the existing list read; no lock-order change."*

At this head, `Store.ListNotes` (main.go 194–205) takes `Store.mu`, builds and
returns a copy, and releases the lock. `handleNotes` (main.go 535–549) then
filters that **copy** in the handler, outside `Store.mu`.

- **Behavioral impact:** none. The search still reads a consistent snapshot, does
  not mutate stored notes, and introduces no lock-order change or data race.
- **Accuracy impact:** the sentence is descriptively stale; filtering is
  handler-level on a snapshot, not store-level under the lock.
- **Action:** none in this pass (the s02 artifact is immutable for this
  re-validation). If s02 is ever revised, correct the sentence to "filtering is
  applied to the snapshot returned by `ListNotes`; no lock-order change."

### D-2 — Observation (not drift): no dedicated `q=` shell smoke in `e2e-preview.sh`

The scope report names `deploy/path1/e2e-preview.sh` **only if a search smoke is
added**. No `q=` shell assertion was added; the harness instead runs the full
Playwright suite, which includes `web/e2e/notes-search.spec.js`. This is exactly
the conditional behavior the report describes, so it is **not drift**. It does
mean `plan.md` T0009's "API smoke + adapter" is only partially visible as a
shell `q=` smoke; the adapter/integration wiring is present in
`path1.project.json`. No gate depends on a shell-level search smoke.

### D-3 — Observation (already recorded in s01): empty-state copy literal

`web/index.html` renders `Ничего не найдено.` (sentence case + period) while the
raw request/brief use `ничего не найдено`. Product intent is identical and no
scope item constrains copy. This is a brief-vs-code display detail, not a
scope-report drift; s01 already recommends treating the graph/brief as authority
and normalizing any exact-text oracle. No scope change.

### D-4 — Observation: client search also considers an optional `note.title`

`web/app.js` `noteSearchText` joins `note.title` (if present) with `note.text`.
The API emits only `{id,text}`, so effective behavior is text-only today; the
extra branch is future-proofing and adds no contract surface.

**No other drift found:** owner-scope ordering, auth order, response envelope,
`[]`-not-`null`, URL decoding via `r.URL.Query()`, test-name mapping, unit
naming, and the three search invariants all match the scope report and spec.

## Open questions

**No blocking open questions.** OD-1 and OD-2 are closed and reflected in code.

Residual, non-blocking items already recorded elsewhere (no action for this
step):

1. Whether any future oracle should normalize the empty-state literal
   `Ничего не найдено.` vs `ничего не найдено` (s01 mismatch 1; recommendation:
   treat as display copy).
2. `q` has no explicit length cap (RT-NEW-2, info); bounded by the user's own
   note count because owner scoping runs first.
3. Stale `notebook.search` sessionStorage across a later login in the same tab
   (RT-NEW-1, low, cosmetic; notes remain owner-scoped).

## Limitations of this pass

- Per instruction, **no git commands were run**. Drift was checked against the
  working tree at this head, not against a base diff. Therefore constraint 7
  (`f-v3`/`E4312`/`E1320` untouched) is verified only as "no such paths appear
  in the reviewed feature surface", not by commit ancestry.
- Historical execution IDs in `UI-GRAPH.yaml` (`E8895`) and `invariants.json`
  (`E9294`) are prior-run immutable artifacts; this pass runs under `E8363` and
  does not re-stamp them.
