# f-v4-note-search — change-definition (s10)

- Execution: **E0809**, step **s10.change_definition**, role **architect**
- Branch: `dev/f-v4-note-search-e2e`, base `e6aeb44e`
- Process: `path-1.feature` **4.0.0** (entry `default`, platform `web`, profile `full`)
- DS: **Notebook DS 1.0.0** — tag `ds/v1.0.0`, digest `02f027a8…da3d`,
  constraint `=1.0.0`
- Sources: `feature-brief.md` (FINAL, s06), `intent-brief.md` (s07),
  `scope-report.md`, `design-impact.md`, `ds.lock.json`, `component-refs.json`,
  `design-gaps.json`, `invariants.json`, `prototypes/v6/prototype-review.json`,
  `main.go`, `main_test.go`, `web/index.html`, `web/app.js`,
  `web/e2e/notes-search.spec.js`.
- Status: change definition only. No code, `web/`, or `design/` change is made at
  s10. s20 implements, s20c verifies on `test2`, s22a/s22b/s22c review, s24
  approves.

## Domains and surfaces

| Domain | Surface | Change |
|---|---|---|
| `notebook-api` | `main.go`, `main_test.go` | `GET /api/notes?q=` contract; owner-scoped case-insensitive filter; 512-byte cap; search tests |
| `notebook-web` | `web/index.html`, `web/app.js`, `web/app.css`, `web_ui_test.go` | search input/filter/clear/search-empty; count, retry, offline banner, zero-note disable, localized Delete; DS-only styling |
| `notebook-tests` | `main_test.go`, `web_ui_test.go`, `web/e2e/notes-search.spec.js` | Go search/isolation/encoding/cap tests; 15+ Playwright search scenarios |
| `notebook-deploy` | `deploy/path1/e2e-preview.sh`, `path1.project.json` | `test2` preview + E2E entry; no runtime dependency change |
| `path1-adapter` | `UI-GRAPH.yaml`, `ds.lock.json`, `component-refs.json`, `design-gaps.json`, `prototypes/v6/*` | UI graph actualized at s21; DS 1.0.0 contract artifacts owned here |

The DS contract artifacts (`ds.lock.json`, `component-refs.json`,
`design-gaps.json`, `prototypes/v6/prototype-review.json`) are path1-adapter
inputs for s22a/s24; they are not application code.

## Changes

### C1. GET /api/notes?q= (notebook-api)

- **Before:** `GET /api/notes` returns all notes of the current user; no query.
- **After:** optional `q`, semantics unchanged — trim; empty/whitespace → all own
  notes; non-empty → case-insensitive substring over the current user's notes;
  `[]` not `null`; missing/bad bearer → `401` before query handling; `UserID`
  never exposed.
- **Owner predicate first:** `ListNotes(session.UserID)` narrows scope before the
  text predicate, so `q` can only narrow, never widen (INV-SEARCH-OWNER-SCOPE).
- **512-byte cap (existing contract):** decoded `q` > 512 bytes →
  `400 {"error":"query too long"}` before any note scan; exactly 512 bytes is
  accepted; the cap is bytes, not runes (INV-SEARCH-Q-MAX).
- **Files:** `main.go`, `main_test.go`.
- **Acceptance:** `TestNotesSearchFinds`, `TestNotesSearchNotFound`,
  `TestNotesSearchIsolation`, `TestNotesSearchAuthRequired`,
  `TestNotesSearchEmptyQuery`, `TestNotesSearchWhitespaceQuery`,
  `TestNotesSearchEncoding`, `TestNotesSearchCaseInsensitive`,
  `TestNotesSearchQueryTooLong`.

### C2. Notes search UI (notebook-web)

- **Before:** notes screen (composer, list, loading/empty/error), client-side
  search with clear and `notes-search-empty`; no count, retry, or offline
  treatment; Delete label is `Delete`; search stays enabled after load even with
  zero notes.
- **After — result count:** `Найдено N` (`data-testid="notes-search-count"`,
  `aria-live="polite"`) only for a non-empty trimmed query, including
  `Найдено 0`; hidden when the query is empty (AOD-5).
- **After — retry:** error state shows a `Повторить` control
  (`data-testid="notes-retry"`) wired to `loadNotes`; retry reuses the normal
  load path (loading state, 401 handling, active query re-applied).
- **After — offline:** banner (`data-testid="notes-offline"`) driven by
  `navigator.onLine` plus the loaded notes; copy states that loaded notes are
  shown; `Проверить сеть` (`data-testid="notes-offline-check"`) re-runs
  `loadNotes` when online; an offline-zero variant covers no loaded notes, with no
  false "nothing found" state (AOD-4).
- **After — zero notes:** search is disabled when `notes.length == 0` (also
  disabled in loading/error/offline); the base `notes-empty` state wins over
  `notes-search-empty` (AOD-1). Search stays enabled for a non-empty collection.
- **After — Delete label:** visible label `Удалить`, `aria-label="Удалить
  заметку #N"` per row; `Add`/`Logout` remain English under the DS-term policy
  (AOD-6).
- **After — order:** composer above search, search above the list; unchanged
  composer-first order (AOD-7, matches the v6 prototype export).
- **After — query state:** in-memory only; not restored from storage/URL across
  reload and cleared on login/logout/401 (AOD-3).
- **Design System:** Notebook DS 1.0.0 components/tokens only; 0 local instances
  and no local CSS. `GAP-1` (count label, missing pattern), `GAP-3` (delete
  danger variant, registry omission), `GAP-2` (input disabled state, missing
  state) remain accepted and non-blocking (path6: `n-count`, `n-delete`).
- **Files:** `web/index.html`, `web/app.js`, `web/app.css` (existing DS rules
  only), `web_ui_test.go`.
- **Acceptance:** `TestUISemantics`, `INV-UI-LABEL`, `INV-UI-A11Y-NAME`,
  `INV-XSS-ESCAPE`, `INV-SEARCH-UI-FILTER`, `INV-SEARCH-UI-EMPTY`,
  `INV-SEARCH-UI-TESTIDS`.

### C3. Tests and E2E (notebook-tests)

- **Before:** `web/e2e/notes-search.spec.js` has 8 scenarios
  (`SEARCH-E2E-1..8`): find, not-found empty state, case-insensitive, clear,
  create with active query, delete with active query, whitespace-only query,
  no-token cleanup. User-B isolation is in `auth-notes.spec.js` E2E-6.
- **After — 20 scenarios total.** Existing 1–8 above plus:
  9. result count `Найдено N` visible only for a non-empty query and hidden when empty
  10. zero-notes collection: base `notes-empty` wins and search is disabled
  11. loading state: `notes-loading` visible and search disabled
  12. error state: load failure shows error and `Повторить`; retry re-runs `loadNotes`
  13. offline banner with loaded notes (navigator offline) and no false empty state
  14. offline-zero: offline with nothing loaded shows the variant, not search-empty
  15. XSS/escaping: HTML/script in note text renders literally via `textContent`
  16. keyboard/focus/aria: tab order, visible focus, labels, `aria-live` regions
  17. 512-byte API cap: request-level `q` > 512 bytes → `400 query too long`; 512 accepted
  18. 390px and 1200px viewports: no horizontal overflow; stacked/inline search row
  19. clear returns focus to the search input and restores the full list
  20. owner-scope B: user B's search never surfaces user A's notes
- **Harness note:** scenarios 9–20 are defined here and their actual Playwright
  code is added in s20; s10 does not modify tests or application code.
- **Files:** `main_test.go`, `web_ui_test.go`, `web/e2e/notes-search.spec.js`.
- **Acceptance:** full `go test ./...`, Playwright green, per-scenario
  screenshots/`pngdiff`, no skips/fixmes.

### C4. Adapter / preview (notebook-deploy, path1-adapter)

- **Before:** preview on `test2` under lease; auth E2E plus the search spec.
- **After:** preview **only on `test2`** under the E0809 stand lease; E2E entry
  unchanged except discovery of the expanded spec; platform and DS frozen until
  s24. No prod/main/test1, no canary, s45/s46 stay skipped; lock files are not
  rolled back. UI graph actualized at s21.
- **Files:** `deploy/path1/e2e-preview.sh`, `path1.project.json`,
  `doc/идеи/f-v4-note-search/UI-GRAPH.yaml`.
- **Acceptance:** `s20b` preview on `test2`, `s20c` E2E pass/verified, `s21`
  graph gate, `s24` ds-drift and owner approval.

### C5. Design System contract (path1-adapter)

- **Prototype v6:** approved `2026-11-08T14:49:20Z`; 0 blockers / 0 majors /
  0 open minors, 10/10 items fixed; 7 states + `normal`; exports at 390/1200.
- **Independent reviews:** UI and UX reviewers distinct from the author, both
  `accept` with 0/0 (P-01, P-08, P-09).
- **DS usage accepted:** Notebook DS 1.0.0 pinned (`ds/v1.0.0`, digest
  `02f027a8…da3d`); 12 registry components used; `path6_required =
  [n-count, n-delete]` covered by accepted non-blocking gaps; 0 local instances.
- **Residual token drift documented and accepted** in `design-impact.md`:
  typography sizes, unused `--border-subtle`, `accent_hover`/`--accent-dark`
  naming, hardcoded `radius.sm`, off-scale spacing, and provenance notes. No DS
  file is edited; the pinned digest does not change.
- **Files:** `ds.lock.json`, `component-refs.json`, `design-gaps.json`,
  `prototypes/v6/prototype-review.json`.

## Acceptance

- `go test ./...` green (backend contract, static UI oracle, search/isolation/
  encoding/512-cap tests).
- `npx playwright test web/e2e/notes-search.spec.js` green on `test2` with 15+
  scenarios, no skips/fixmes, per-scenario screenshots and `pngdiff`.
- `s22a` UI audit: **0 DS-usage violations**, 0 local instances, path6 gaps
  still accepted/non-blocking.
- `s24`: `ds-drift` clean (no unreviewed token/CSS drift) and owner approval via
  the signed Nexus request.

## Not in scope

- Auth/session/token/persistence changes.
- Pagination, ranking, fuzzy search, highlighting.
- New runtime dependencies, framework, bundler, or new DS release.
- prod/main/stage/test1, canary rollout, s45/s46.
- Changes to `f-v3-auth-notes`, `E4312`, `E1320`.
