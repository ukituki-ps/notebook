# f-v4-note-search — change-definition (s10)

- Execution: **E8363**, step **s10.change_definition**
- Branch: `dev/f-v4-note-search-validation-zero`, base `5935e148`
- Pass: fresh E8363 re-validation of the existing change definition against the
  code at this head; no platform, path-1, auth, or persistence change.
- Sources: `feature-brief.md` (FINAL/s06, E8363), `intent-brief.md` (E8363),
  `intent-trace.json` (E8363), `invariants.json` (E8363), `scope-report.md`,
  `expertise-report.md`, `plan.md`, `main.go`, `main_test.go`, `web/*`,
  `path1.project.json`, `deploy/path1/e2e-preview.sh`, `UI-GRAPH.yaml`
  (planned E8363), and the s01–s07 validation artifacts under
  `platform-dev-validation-zero/`.

## Domains and surfaces

| Domain | Surface | Change |
|---|---|---|
| `notebook-api` | `main.go`, `main_test.go` | `GET /api/notes` optional `q` parsing + owner-scoped case-insensitive filter; search tests |
| `notebook-web` | `web/index.html`, `web/app.js`, `web/app.css` | labelled search input, live client-side filtering, clear control, search empty state, testids |
| `notebook-tests` | `main_test.go`, `web_ui_test.go`, `web/e2e/notes-search.spec.js` | backend search tests, UI semantics oracle, 6 Playwright search scenarios |
| `notebook-deploy` | `deploy/path1/e2e-preview.sh` (unchanged), `path1.project.json` (no semantic change) | integration/E2E entry on `test2`; Playwright discovers the new spec via `playwright.config.js` |
| `path1-adapter` | `doc/идеи/f-v4-note-search/UI-GRAPH.yaml` | planned at s04 (E8363), actualized at s21 |

## Changes

### C1. `GET /api/notes?q=` (notebook-api)

- **Before:** `GET /api/notes` returns all notes of the current user; no query
  handling.
- **After:** optional `q`; trim; empty/whitespace `q` → all own notes;
  non-empty `q` → case-insensitive substring over the current user's notes;
  no match → `200 []` (never `null`); missing/bad bearer still `401` before
  method/query handling; `UserID` is never serialized. The owner predicate is
  applied by `ListNotes(session.UserID)` before the query filter, so `q` can only
  narrow.
- **Files:** `main.go`, `main_test.go`.
- **Acceptance:** `TestNotesSearchFinds`, `TestNotesSearchNotFound`,
  `TestNotesSearchCaseInsensitive`, `TestNotesSearchEmptyQuery`,
  `TestNotesSearchWhitespaceQuery`, `TestNotesSearchIsolation`,
  `TestNotesSearchAuthRequired`, `TestNotesSearchEncoding`,
  `TestHTTPTransport`; invariants `INV-SEARCH-OWNER-SCOPE`,
  `INV-SEARCH-CASE-INSENSITIVE`, `INV-SEARCH-EMPTY-Q`,
  `INV-SEARCH-NOT-FOUND`, `INV-SEARCH-AUTH-REQUIRED`,
  `INV-SEARCH-ENCODING`, `INV-WIRE-CASING`.

### C2. Notes search UI (notebook-web)

- **Before:** notes list with create/delete/loading/empty; no search.
- **After:** a labelled search input (`data-testid="notes-search"`,
  `type="search"`, `aria-controls="notes-list"`); a separate clear control
  (`data-testid="notes-search-clear"`, hidden while the raw query is empty);
  live client-side filtering of the already loaded owner-scoped list; a search
  empty state (`data-testid="notes-search-empty"`, `role="status"`,
  `aria-live="polite"`, copy `"Ничего не найдено."`) shown only when the trimmed
  query is non-empty, the loaded collection is non-empty, and zero notes match.
  `notes-empty` remains the genuinely-empty server-list state. Create/delete
  re-render through the same filter; the current `sessionStorage` reload-restore
  is an implementation convenience only (OD-6, not contract).
- **Files:** `web/index.html`, `web/app.js`, `web/app.css`.
- **Acceptance:** `TestUISemantics`; invariants `INV-SEARCH-UI-FILTER`,
  `INV-SEARCH-UI-EMPTY`, `INV-SEARCH-UI-TESTIDS`, `INV-UI-LABEL`,
  `INV-UI-A11Y-NAME`, `INV-UI-TRUTH`; E2E `SEARCH-E2E-1..6`.

### C3. Tests and E2E (notebook-tests)

- **Before:** auth/notes Go tests and 7 auth E2E scenarios
  (`web/e2e/auth-notes.spec.js`, E2E-1..7).
- **After:** the 8 backend search tests above; `TestUISemantics` covers search
  testids, label/a11y, filter serialization, and empty-state separation; 6 new
  Playwright search scenarios in `web/e2e/notes-search.spec.js`
  (`SEARCH-E2E-1` find, `-2` not found/empty state, `-3` case-insensitive,
  `-4` clear restores both, `-5` create while query active, `-6` delete while
  query active). Login is a precondition in every search test; user-B isolation
  remains covered by auth E2E-6 and `TestNotesSearchIsolation`, not by the search
  spec itself. Playwright stays 1.64.1.
- **Files:** `main_test.go`, `web_ui_test.go`,
  `web/e2e/notes-search.spec.js`.
- **Acceptance:** `go build ./...`, `go vet ./...`,
  `go test -count=1 ./...`; `npx --no-install playwright test` (or the targeted
  `web/e2e/notes-search.spec.js`); `SEARCH-E2E-1..6`; auth E2E-6; `pngdiff` OK.

### C4. Adapter / preview (notebook-deploy, path1-adapter)

- **Before:** API-only integration smoke (health, auth, notes CRUD) plus the auth
  Playwright suite on `test2`; no search spec.
- **After:** no search-specific API smoke was added to
  `deploy/path1/e2e-preview.sh`; in `E2E_API_ONLY=1` mode it remains the
  health/auth/notes smoke used by s20a. The full Playwright run at s20c
  auto-discovers `web/e2e/notes-search.spec.js` via `playwright.config.js`
  (`testDir: "web/e2e"`). `path1.project.json` keeps its `test2` integration
  command and the `UI-E2E-PREVIEW` audit oracle (healthz + unauth `401`); no
  semantic config change. The planned E8363 UI graph is actualized from code at
  s21.
- **Files:** `deploy/path1/e2e-preview.sh` (unchanged),
  `path1.project.json` (no semantic change), `UI-GRAPH.yaml`,
  `playwright.config.js` (unchanged; discovers the new spec).
- **Acceptance:** `E2E_API_ONLY=1 bash deploy/path1/e2e-preview.sh` (integration,
  auth/notes API smoke); `E2E_BASE_URL=<test2> npx --no-install playwright test`
  at s20c; audit oracle `UI-E2E-PREVIEW`; s20b preview on `test2`; s21 UI-graph
  gate; `pngdiff` on the scenario screenshots.

## Not in scope

- Auth, session, token, or persistence behaviour changes (R41); notes stay
  in-memory.
- Changes to `POST /api/notes` or `DELETE /api/notes/{id}`, new endpoints, new
  auth headers, or CORS changes; `GET /api/notes` response schema stays
  `[{"id":N,"text":"..."}]`.
- Pagination, sorting, ranking, fuzzy matching, or server-side highlighting
  (R42; brief out of scope).
- New runtime dependencies, framework, or bundler; Playwright downgrade;
  rollback of `package.json`/`package-lock.json` (R38/R39).
- prod/main/stage deployment, canary rollout, `s45.push_primary`,
  `s46.post_deploy_verify` (R5/R8/R45).
- Changes to `f-v3-auth-notes`, `E4312`, or `E1320` (R6/R7/R43/R44).
- Unrelated refactors outside search scope (R42).
- Query persistence across a full page reload via `sessionStorage`
  `notebook.search` (OD-6): the current UI restore is an implementation
  convenience, not part of this contract; s07 proposes not to persist it.
- No force/skip/waiver, no fake or self-signed evidence, no per-run artifact
  commits (R10; process constraint, not a change surface).
