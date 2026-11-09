# Scope report — f-v4-note-search

- Execution/step: **E6247** · `s02.architect_scope_analysis` · path-1.feature 4.0.0, path-10
- Branch: `dev/path10-runner-07`, base `9e7fae3`; evaluated commit `8e8d111`
  (earlier record: E0809 / 3.2.2, base `406fa965`).
- Status: refresh for the DS 1.0.0 pilot. U01/U02 are already present in `main.go`,
  `web/*`, `main_test.go`, `web_ui_test.go`; this report fixes scope, constraints,
  conflicts, and design inputs. No code or design change is made at s02.
- Revalidated at `8e8d111` for E6247: every code claim below was checked against the
  evaluated commit (section 1a). One drift was corrected — the search query is
  **not** persisted across reload (see `web/app.js` and OD-4).
- Sources: `feature-request.md`, `feature-brief.md`, `s01-product-discuss.md`,
  `plan.md`, `change-definition.md`, `invariants.json`, `main.go`, `main_test.go`,
  `web/*`, `design/` 1.0.0, evaluated tree `8e8d111`.

## 1. Affected domains / layers

| Domain / layer | Surface | Change / status |
|---|---|---|
| Web UI (`notebook-web`) | `web/index.html`, `web/app.js`, `web/app.css`, `web_ui_test.go` | `notes-search` input, `notes-search-clear`, `notes-search-empty`; client-side filter of the loaded owner-scoped list; one `renderNotes()` re-applies the active query after load/create/delete. The query is in-memory only (`searchQuery`); `sessionStorage["notebook.search"]` is only cleared on logout/401/lock, never restored on reload. |
| Notes API (`notebook-api`) | `main.go` (`handleNotes`, `ListNotes`) | Optional `q` on `GET /api/notes`: trim → empty means all; non-empty means case-insensitive substring; `maxQueryBytes=512`; empty result is `[]`, never `null`; JSON error envelope. |
| Storage scope | In-memory `Store` | Read-only projection; owner predicate `note.UserID == session.UserID` in `ListNotes` before filtering; no schema/migration; `UserID` stays out of the wire payload. |
| Auth | `requireAuth`, bearer parsing | Unchanged; `401` before method/query handling; no token, session, or TTL changes. |
| Tests | `main_test.go`, `web_ui_test.go`, `web/e2e/notes-search.spec.js`, `web/e2e/auth-notes.spec.js` | Go search/isolation/encoding/512-cap tests; static UI oracle; 23 E2E scenarios (`SEARCH-E2E-1..20` + `CR-01..03`); user-B isolation in `SEARCH-E2E-20` and auth `E2E-6`. |
| Deploy / docs | `deploy/path1/*`, `UI-GRAPH.yaml`, `design/*` | Preview on `test2` only; UI graph actualized at s21; DS pinned at s02a. |

### 1a. Reality check at evaluated commit `8e8d111`

| Claim | Evidence in the evaluated tree | Status |
|---|---|---|
| `q` capped at 512 bytes before scanning | `main.go:33` (`maxQueryBytes = 512`), `main.go:541-543` (`len(rawQuery) > maxQueryBytes` → `400`), `ListNotes` called after the check at `main.go:545` | verified |
| Owner scoping applied before the text predicate | `main.go:195-207` (`ListNotes` keeps `note.UserID == userID`), text filter at `main.go:544-553` | verified |
| Empty result is `[]`, never `null` | `main.go:198` (`make([]Note, 0)`) | verified |
| UI testids/labelled search | `web/index.html:79-86` (`role="search"`, label, `notes-search`, clear), `web/index.html:98-104` (count/empty), `web/app.js:309-312` | verified |
| Client-side filter, clear restores full list | `web/app.js:444-453` (`filterNotes`), `web/app.js:455-461` (`renderNotes` re-applies), `web/app.js:383-387` (clear visibility) | verified |
| Query is **not** persisted across reload | `web/app.js:7` (`SEARCH_KEY`), only `removeStorage` calls at `:177,487,596,607,733,792`; no read/write; `renderNotes` comment "no persistence"; `feature-brief.md` forbids persistence | verified — corrects the earlier E0809 wording |
| Static same-origin UI, unknown paths `404` | `main.go:24-25` (`//go:embed web/index.html web/app.js web/app.css`), `web/app.js:95` (`credentials: "same-origin"`), `main.go:461-462` | verified |
| No new dependencies; Playwright pinned | `go.mod` (`go 1.23`, no `require`), `package.json:9` (`@playwright/test: 1.64.1`) | verified |
| Search/isolation tests present | `main_test.go:934-1119` (9 search tests incl. `TestNotesSearchQueryTooLong`), `web_ui_test.go:54-55,175-205`, `web/e2e/notes-search.spec.js:173-914` (23 E2E: `SEARCH-E2E-1..20` + `CR-01..03`), `web/e2e/auth-notes.spec.js:135` (E2E-6) | verified |

## 2. Architecture constraints

1. **Same-origin static only.** The UI is embedded from `web/index.html`,
   `web/app.js`, `web/app.css`; no CDN, new origin, CORS, framework, or bundler.
   `fetch` uses `credentials: "same-origin"`; unknown paths stay `404`.
2. **Owner-scoped only.** `q` may narrow the result but must never widen it.
   Missing and foreign notes stay indistinguishable; `UserID` remains `json:"-"`.
3. **`q` cap.** A decoded `q` longer than 512 bytes returns
   `400 {"error":"query too long"}` before any note scan; exactly 512 bytes is
   accepted. The cap is bytes, not runes. Absent/empty/whitespace `q` (≤512)
   returns all own notes.
4. **No new dependencies.** `go.mod` unchanged; vanilla JS/CSS; Playwright stays
   1.64.1 as a test-only dependency; `package.json`/lock are not rolled back.
5. **No title field.** `Note` is `{id, text}`; search is text-only. `noteSearchText()`
   tolerates a future `title`, but this feature must not add, emit, or require one.
6. **Frozen auth/storage/lifecycle.** No auth/session/persistence change; create,
   delete, and reload keep working. Order stays auth → method → query handling.
7. **UI contract.** Stable testids `notes-search`, `notes-search-clear`,
   `notes-search-empty`; labelled `type="search"` with `aria-controls="notes-list"`;
   clear restores the full list; search-empty is only for a non-empty query that
   filters a non-empty collection to zero; base `notes-empty` wins when there are
   no notes at all.
8. **Scope guard.** No unrelated refactors; production/main/stage and canary are
   out; `f-v3-auth-notes`, `E4312`, `E1320` are untouched.

## 3. Potential conflicts

| Conflict | Evidence | Risk | Mitigation |
|---|---|---|---|
| Client-side filter vs server `q` | UI never sends `?q`; the API implements and tests it | Matching drift (Go `ToLower` vs JS `toLowerCase`, trim rules) and duplicate logic | Keep the UI filter authoritative for the screen; server `q` is the API contract for clients; share acceptance vectors; do not move to per-keystroke requests without OD-3. |
| State duplication | `searchQuery`, the input value, and `notes[]` coexist; `sessionStorage["notebook.search"]` is only cleared, never written | Input/state desync after create/delete, user switch | Treat `searchQuery` as the single source, always sync the input through `renderNotes`, clear storage on logout/401/no token; reload intentionally clears the query (brief), cover user-B in E2E. |
| DS tokens vs current CSS | Tokens are extracted from `app.css`, but CSS uses off-scale 6/10/14/18/20/48px, does not apply body 15px/secondary 13px, and `.notes-search-empty` is dead (the element uses `.muted`); `--border-subtle` is unused | False "token-compliant" claim and visual drift | Pin DS by manifest; s03 maps states to existing tokens; gaps become DS proposals, not ad-hoc values; s22a audits rendered CSS. |
| Empty-state precedence | Zero notes + non-empty `q` shows `notes-empty`; `web_ui_test.go` asserts `!noNotes` | Brief wording can be read as requiring `notes-search-empty` | Confirm OD-2; no code change at s02. |
| Release snapshot | DS 1.0.0 manifest `code.sha256` is the release snapshot (`cc4218a`); current `web/` has feature edits | Manifest misread as a live hash of current code | Pin tag/digest; do not claim current `web/` equals release code; re-release only if DS changes. |

## 4. Design recommendations (s02a / s03)

- **One screen only:** the notes screen gains search above the list; login and
  register are unchanged.
- **Pin Notebook DS 1.0.0** from `design/releases/1.0.0/manifest.json`
  (`ds/v1.0.0`, digest), using `design/tokens.json` and `design/registry.json`.
  No new DS release if existing tokens cover search.
- **States to specify:** idle (empty query, list), loading (`notes-loading`),
  results (query + matches), search-empty (`notes-search-empty`), base-empty
  (`notes-empty`), error (`notes-error` for load/create/delete/401), and offline
  (network copy "Ошибка сети. Проверьте соединение."; no new API behavior).
- **Breakpoints:** 390px mobile (search row stacked, full-width 44px controls, no
  horizontal scroll) and 1200px desktop (centered column/card, inline search +
  clear). Current CSS has a 640px column and one `max-width: 640px` query;
  frames must map onto it, not invent a second system.
- **Accessibility:** visible label "Поиск заметок", `type="search"`,
  `aria-controls="notes-list"`, clear `aria-label`, `role="status"` +
  `aria-live="polite"` on the search empty state, 3px focus ring.
- **Copy:** "Поиск заметок", "Поиск по тексту...", "Ничего не найдено.", clear
  "Clear"; text-only, no title.
- **No extra controls/states:** keep create and delete untouched; do not add
  pagination, ranking, highlighting, or a title field.

## 5. Open decisions

| ID | Decision | Options | Recommendation | Status |
|---|---|---|---|---|
| OD-1 | Whitespace-only `q` | all notes / `400` | All notes (trim → empty → all) | **Closed** by `feature-brief.md` and tests. |
| OD-2 | Zero notes + non-empty `q` | base-empty / search-empty | Keep base-empty (current code and `web_ui_test.go`): "ничего не найдено" is misleading when the user has no notes. Confirm at s03; a change would be code/test work outside s02. | Open for s03. |
| OD-3 | UI filtering source | client-only / debounced server `q` | Client-only for this feature: one in-memory owner-scoped list, no request per keystroke, create/delete stay consistent. Server `q` remains the API contract; revisit with pagination/large lists. | Open for s03. |
| OD-4 | Query persistence across reload | restore via `sessionStorage` / reset | **Reset on reload.** `feature-brief.md` explicitly forbids persistence; `web/app.js` keeps `searchQuery` in memory and only clears `SEARCH_KEY`. The plan's "reload re-applies the query" means re-rendering the loaded list, not restoring the query. | **Closed** by brief + code. |
| OD-5 | DS empty-state drift | add `.notes-search-empty` to the element / remove the dead rule and rely on `.muted` | Normalize at s03/s22a; do not add a token for one state. | Open for s03/s22a. |
| OD-6 | Unicode case-fold parity | accept Go/JS differences / define normalization | Accept and document: no locale-specific collation; test ASCII, Cyrillic, and special characters. | **Closed** by `feature-brief.md`. |

No silent decisions: OD-1, OD-4 and OD-6 are closed by the brief/code; OD-2,
OD-3 and OD-5 require s02a/s03 confirmation. Current code is evidence, not
design approval.

## 6. Trace note

- `TestNotesSearchQueryTooLong` covers the 512-byte cap, but `invariants.json`
  has no corresponding invariant id. Recommend adding `INV-SEARCH-Q-MAX`
  (`400` before scan) at the next invariants refresh.
- User-B isolation is covered twice: `web/e2e/notes-search.spec.js`
  `SEARCH-E2E-20` and `web/e2e/auth-notes.spec.js` E2E-6; s20c evidence must cite
  both suites.
