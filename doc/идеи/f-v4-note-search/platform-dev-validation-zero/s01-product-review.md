# Product review — f-v4-note-search (s01.product_discuss)

- **Step:** `s01.product_discuss`
- **Execution:** `E8363`
- **Feature:** `f-v4-note-search`
- **Platform:** `web` (`path1.ui.json.platform = "web"`, `feature_profile = full`)
- **Branch (this pass):** `validation/platform-dev-20261106-zero`
- **Platform under test:** `730d144a1e63837b590f3e95d01f67142ca3a699`
- **Pass type:** fresh re-validation of the already finalized brief. Nothing was
  rewritten; this review is the only artifact produced.

## Verdict

**PASS** — the final brief (`feature-brief.md`, FINAL/s06) still faithfully
covers the immutable raw request for a web-only, owner-scoped note search. The
core contract (query parameter, case-insensitive substring matching, owner
scoping, client-side filter/clear/empty states) is complete and consistent with
`expertise-report.md`, `scope-report.md`, `invariants.json`, `UI-GRAPH.yaml`, and
`path1.ui.json`.

## Reviewed inputs

All paths relative to `/workspace/projects/notebook-valzero/`.

| Input | Role | Observed state |
|---|---|---|
| `doc/идеи/f-v4-note-search/feature-request.md` | Immutable raw request (45 items) | Unchanged; 45 items, backend/U01 12–23, UI/U02 24–30, deploy/U03 31–40, constraints 41–45 |
| `doc/идеи/f-v4-note-search/feature-brief.md` | Draft → final brief (s06) | FINAL; API contract table, search semantics, UX, wireframes, AC 1–6, invariants summary |
| `doc/идеи/f-v4-note-search/scope-report.md` | Scope/impact report | Domains notebook-api / notebook-web / notebook-deploy / docs-graph; constraints 1–7; OD-1/OD-2 |
| `doc/идеи/f-v4-note-search/expertise-report.md` | Architect validation (s05) | B-1…B-9; OD-1 and OD-2 closed; no blocking finding |
| `doc/идеи/f-v4-note-search/UI-GRAPH.yaml` | UI graph (actualized, s21) | `schema: ui-graph/v1`, `status: actualized`, platform web; search idle/filtering/results/empty/cleared/after-mutation states; testids `notes-search`, `notes-search-clear`, `notes-search-empty` |
| `doc/идеи/f-v4-note-search/invariants.json` | Machine-readable invariants | 16 active + 2 proposed; search owner/case/empty/not-found/encoding/UI invariants present |
| `path1.ui.json` (repo root) | Platform declaration | `platform: "web"`; same-origin static UI, token in localStorage |

Supporting cross-checks (read-only, not normative inputs):
`doc/идеи/f-v4-note-search/spec/core.md`,
`doc/идеи/f-v4-note-search/spec/contract-matrix.md`,
`doc/идеи/f-v4-note-search/platform-dev-validation/REPORT.md`.

## Coverage of raw request bullets

Status: `COVERED` = explicitly reflected in the final brief and/or its normative
companions (`expertise-report.md`, `scope-report.md`, `invariants.json`,
`UI-GRAPH.yaml`); `COVERED-BY-REF` = the brief binds the item by reference to the
request/AC rather than restating it.

### Process requirements (1–11)

| # | Requirement | Where covered | Status |
|---|---|---|---|
| 1 | New small feature in path-10 contour | Brief Goal/In scope; scope-report | COVERED |
| 2 | `path-1.feature` 3.2.2, `default`, web, full | `platform-dev-validation/REPORT.md` (E8895), `spec/core.md` header | COVERED |
| 3 | Base `dev/f-v3-auth-notes` @ `406fa965…` | `spec/core.md` §header ("base 406fa965"); scope-report | COVERED |
| 4 | Work branch `dev/f-v4-note-search`; feature dir | `invariants.json.branch`, `spec/core.md` | COVERED (this pass runs on the validation branch by design) |
| 5 | Skip `s45.push_primary` / `s46.post_deploy_verify` | Expertise B-9; `spec/core.md` §6 | COVERED |
| 6 | Do not roll back / rework `f-v3-auth-notes` | Scope-report constraint 7 | COVERED |
| 7 | Do not resume/accept `E4312`; do not touch `E1320` | Scope-report constraint 7; `spec/core.md` §6 | COVERED |
| 8 | No prod/main/stage; no canary | Brief Out of scope; scope-report constraint 6 | COVERED |
| 9 | Gates s21, s22a, s22b/s22c, s24 | Brief AC 5–6 | COVERED |
| 10 | No force/skip/waiver, no fake/self-signed evidence | Process constraint; prior REPORT hygiene records no bypass | COVERED |
| 11 | Post-s20 fan-out: 3 child executions, 3 distinct sessions | Prior execution evidence (REPORT P1, E8895); process-level, not a brief item | COVERED (historical) |

### Backend — U01 (12–23)

| # | Requirement | Where covered | Status |
|---|---|---|---|
| 12 | `GET /api/notes?q=<text>` | Brief API contract; `spec/core.md` §1.1 | COVERED |
| 13 | Without `q` → all current-user notes | Brief table row "No `q` parameter" | COVERED |
| 14 | With `q` → case-insensitive search over note text | Brief "Search semantics"; expertise B-3 | COVERED |
| 15 | Only current user's notes | Brief In scope + `INV-SEARCH-OWNER-SCOPE`; expertise B-4 | COVERED |
| 16 | No bearer token → `401` | Brief table row + `INV-SEARCH-AUTH-REQUIRED` | COVERED |
| 17 | Empty `q` → all notes | Brief table row `q=` + `INV-SEARCH-EMPTY-Q` | COVERED |
| 18 | Whitespace-only `q` fixed as all notes or `400` | Brief table row + decision paragraph; expertise OD-1 closed → all notes | COVERED |
| 19 | Test: search finds a note | Brief AC 1; expertise B-2/B-3 oracles | COVERED |
| 20 | Test: absent note not found | Brief AC 1 + `INV-SEARCH-NOT-FOUND` | COVERED |
| 21 | Test: user cannot see another user's notes | Brief AC 1 + `INV-SEARCH-OWNER-SCOPE` / `TestNotesSearchIsolation` | COVERED |
| 22 | Test: unauthenticated → `401` | Brief AC 1 + `INV-SEARCH-AUTH-REQUIRED` | COVERED |
| 23 | Test: URL-encoding / special characters in `q` | Brief AC 1 + `INV-SEARCH-ENCODING`; expertise B-5 | COVERED |

### Web UI — U02 (24–30)

| # | Requirement | Where covered | Status |
|---|---|---|---|
| 24 | Search field in the notes view | Brief UX; UI-GRAPH `notes-search` | COVERED |
| 25 | Filtering the notes list by the query | Brief UX (client-side over the loaded owner-scoped list); expertise B-6 | COVERED |
| 26 | Clearing the search restores the full list | Brief UX; UI-GRAPH `search-cleared` | COVERED |
| 27 | Empty state "ничего не найдено" | Brief UX + wireframe; `INV-SEARCH-UI-EMPTY` | COVERED |
| 28 | Do not break create/delete/reload | Brief UX ("after create/delete the active query is re-applied"); Risks; UI-GRAPH `search-after-mutation` | COVERED |
| 29 | `data-testid` for search field and empty state | Brief UX (`notes-search`, `notes-search-empty`); `INV-SEARCH-UI-TESTIDS` | COVERED |
| 30 | Actualize the UI graph | Brief AC 5; UI-GRAPH `status: actualized` | COVERED |

### Deploy / E2E — U03 (31–40)

| # | Requirement | Where covered | Status |
|---|---|---|---|
| 31 | Preview deploy on `test2` | Brief AC 4; scope-report constraint 6 | COVERED |
| 32 | E2E: login | Brief AC 4 ("all requested scenarios") | COVERED-BY-REF |
| 33 | E2E: create 2 notes | Brief AC 4 | COVERED-BY-REF |
| 34 | E2E: search finds one note | Brief AC 4; UI-GRAPH `SEARCH-E2E-1` | COVERED |
| 35 | E2E: search finds nothing | Brief AC 4; UI-GRAPH `SEARCH-E2E-2` | COVERED |
| 36 | E2E: clearing returns both notes | Brief AC 4; UI-GRAPH `SEARCH-E2E-4` | COVERED |
| 37 | E2E: user B does not see user A's notes | Brief AC 4 (explicit); expertise risk 1 | COVERED |
| 38 | Playwright 1.64.1 | Scope-report constraint 5; expertise B-8 | COVERED |
| 39 | Do not roll back package/lock files | Scope-report constraint 5; expertise B-8 | COVERED |
| 40 | `pngdiff` OK | Brief AC 4 | COVERED |

### Constraints (41–45)

| # | Requirement | Where covered | Status |
|---|---|---|---|
| 41 | Auth and persistence behaviour unchanged | Brief Out of scope + Invariants; `INV-AUTH-REQUIRED`, `INV-USER-ISOLATION` | COVERED |
| 42 | Only search scope; no unrelated refactors | Brief Out of scope; scope-report constraints 1–4 | COVERED |
| 43 | No changes to `f-v3-auth-notes` branch/artifacts | Scope-report constraint 7 | COVERED |
| 44 | `E4312`/`E1320` not resumed, accepted, modified | Scope-report constraint 7; `spec/core.md` §6 | COVERED |
| 45 | Preview only on `test2`; prod/main/stage/canary out | Brief Out of scope; scope-report constraint 6 | COVERED |

## Mismatches and observations (non-blocking)

These do not change product scope or the verdict; none requires a brief change.

1. **Empty-state copy casing/punctuation.** The raw request (item 27) and the
   final brief use the exact phrase `ничего не найдено` (lowercase). The
   actualized `UI-GRAPH.yaml` selector label is `"Ничего не найдено."` (sentence
   case + trailing period). Product intent is identical; only the literal string
   differs. If any oracle asserts the exact text, it should normalize case and
   terminal punctuation. Recommendation: keep the brief as authority and treat
   the graph label as display copy.
2. **Search control labelling.** The s03 wireframe shows the placeholder
   `Search notes`, while `UI-GRAPH.yaml` records the accessible label
   `"Поиск заметок"`. The raw request does not constrain interface language or
   copy, and the brief only requires a visible label/accessible name. This is a
   design-detail divergence, not a scope mismatch.
3. **E2E scenario enumeration.** AC 4 binds "all requested scenarios" by
   reference instead of listing login / create 2 / find one / find none / clear /
   user-B isolation / pngdiff. The concrete mapping exists in the raw request and
   in `UI-GRAPH.yaml` `evidence` (`SEARCH-E2E-*`) plus the prior REPORT's 13/13
   run. Traceability is intact; no action required for this pass.
4. **Historical execution IDs in the reviewed artifacts.** `UI-GRAPH.yaml`
   carries `execution_id: E8895` and `invariants.json` carries
   `execution_id: E9294`, whereas this re-validation runs under `E8363`. These
   are immutable prior-run artifacts; re-stamping them would be a rewrite, which
   this pass explicitly does not do.

## Open questions

**No new open questions.** The only previously recorded open decisions are
already closed and remain consistent with the raw request:

- **OD-1** (whitespace-only `q`): closed → treated as empty, returns all of the
  current user's notes (`expertise-report.md` B-2; brief API contract).
- **OD-2** (server-side search vs client-side filtering): closed → both
  contracts exist; the UI filters the already loaded owner-scoped list
  (`expertise-report.md` B-6).

## Re-validation statement

This is a **fresh re-validation on platform `730d144a`** of the unchanged raw
request, final brief, and companion artifacts. It is not a rewrite: no brief,
scope, expertise, invariant, UI-graph, spec, source, or path-1 file was modified,
and the only write from this step is this review document. There are **no
platform or path-1 changes** in this pass.
