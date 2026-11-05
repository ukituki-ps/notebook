# f-v4-note-search — change-definition (s10)

- Execution: **E9294**, step **s10.change_definition**
- Branch: `dev/f-v4-note-search`, base `406fa965`
- Sources: `feature-brief.md` (FINAL), `invariants.json`, `scope-report.md`,
  `expertise-report.md`, `intent-brief.md`, `intent-trace.json`,
  `main.go`, `main_test.go`, `web/*`, `path1.project.json`.

## Domains and surfaces

| Domain | Surface | Change |
|---|---|---|
| `notebook-api` | `main.go`, `main_test.go` | `GET /api/notes` query parsing + owner-scoped case-insensitive filter; search tests |
| `notebook-web` | `web/index.html`, `web/app.js`, `web/app.css`, `web_ui_test.go` | search input, live filtering, clear, `notes-search-empty`, testids |
| `notebook-tests` | `main_test.go`, `web/e2e/notes-search.spec.js` | backend tests + Playwright search scenarios |
| `notebook-deploy` | `deploy/path1/e2e-preview.sh`, `path1.project.json` | search API smoke + E2E entry (no runtime dependency change) |
| `path1-adapter` | `doc/идеи/f-v4-note-search/UI-GRAPH.yaml` | planned at s04, actualized at s21 |

## Changes

### C1. GET /api/notes?q= (notebook-api)

- **Before:** `GET /api/notes` returns all notes of the current user; no query.
- **After:** optional `q`; trim; empty/whitespace → all own notes; non-empty →
  case-insensitive substring over the current user's notes; `[]` not `null`;
  missing/bad bearer still `401` before query handling; `UserID` never exposed.
- **Files:** `main.go`, `main_test.go`.
- **Acceptance:** `TestNotesSearchFinds`, `TestNotesSearchNotFound`,
  `TestNotesSearchIsolation`, `TestNotesSearchAuthRequired`,
  `TestNotesSearchEmptyQuery`, `TestNotesSearchWhitespaceQuery`,
  `TestNotesSearchEncoding`, `TestNotesSearchCaseInsensitive`.

### C2. Notes search UI (notebook-web)

- **Before:** notes list with create/delete/loading/empty; no search.
- **After:** labelled search input (`data-testid="notes-search"`), live filtering
  of the loaded owner-scoped list, clear control, `notes-search-empty`
  (`data-testid="notes-search-empty"`) only for a non-empty query with no
  matches; create/delete/reload re-apply the active query.
- **Files:** `web/index.html`, `web/app.js`, `web/app.css`, `web_ui_test.go`.
- **Acceptance:** `TestUISemantics`, `INV-SEARCH-UI-FILTER`,
  `INV-SEARCH-UI-EMPTY`, `INV-SEARCH-UI-TESTIDS`.

### C3. Tests and E2E (notebook-tests)

- **Before:** auth/notes Go tests and 7 auth E2E scenarios.
- **After:** search Go tests above plus Playwright
  `web/e2e/notes-search.spec.js` covering login, 2 notes, find one, find none,
  clear returns both, user B isolation. Playwright stays 1.64.1.
- **Files:** `main_test.go`, `web/e2e/notes-search.spec.js`.
- **Acceptance:** full `go test ./...`, Playwright green, pngdiff OK.

### C4. Adapter / preview (notebook-deploy, path1-adapter)

- **Before:** API-only integration smoke + auth E2E on `test2`.
- **After:** integration smoke includes unauth 401 and search find/not-found;
  E2E entry unchanged except the new spec discovery; UI graph actualized at s21.
- **Files:** `deploy/path1/e2e-preview.sh`, `path1.project.json`,
  `doc/идеи/f-v4-note-search/UI-GRAPH.yaml`.
- **Acceptance:** `s20b` preview on `test2`, `s20c` E2E pass/verified, `s21`
  graph gate.

## Not in scope

- Auth/session/token/persistence changes.
- Pagination, ranking, fuzzy search, highlighting.
- New runtime dependencies, framework, bundler.
- prod/main/stage, canary rollout, s45/s46.
- Changes to `f-v3-auth-notes`, `E4312`, `E1320`.
