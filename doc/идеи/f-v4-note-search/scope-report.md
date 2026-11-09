# Scope report — f-v4-note-search (E4138)

- Execution/step: **E4138** · `s02.architect_scope_analysis` · `path-1.feature@4.0.0`, path-10
- Branch: `dev/path10-runner-12`, base `9e7fae353c61e717505dc40019627a1d7ab48820`
- Status: re-validation on a tree where U01/U02 are already present
  (`main.go`, `web/*`, `main_test.go`, `web_ui_test.go`). This report fixes
  scope, constraints, conflicts, and design inputs for the current execution.
  No code or design change is made at s02.
- Sources: `feature-request.md`, `feature-brief.md`,
  `s01-product-discuss.md` (E4138), `plan.md`, `change-definition.md`,
  `invariants.json`, `main.go`, `main_test.go`, `web_ui_test.go`, `web/*`,
  `design/releases/1.0.0`.

## 1. Affected domains / layers

| Domain / layer | Surface | Change / status |
|---|---|---|
| Web UI (`notebook-web`) | `web/index.html`, `web/app.js`, `web/app.css`, `web_ui_test.go` | `notes-search` input, `notes-search-clear`, `notes-search-count`, `notes-search-empty`; client-side filter of the loaded owner-scoped list; one `renderNotes()` re-applies the active query after load/create/delete/reload; query is in-memory only (no persistence). |
| Notes API (`notebook-api`) | `main.go` (`handleNotes`, `ListNotes`, `maxQueryBytes`) | Optional `q` on `GET /api/notes`: trim → empty means all; non-empty means case-insensitive substring; `maxQueryBytes=512`; empty result is `[]`, never `null`; JSON error envelope. |
| Storage scope | In-memory `Store` | Read-only projection; owner predicate `note.UserID == session.UserID` in `ListNotes` before filtering; no schema/migration; `UserID` stays out of the wire payload. |
| Auth | `requireAuth`, bearer parsing | Unchanged; `401` before method/query handling; no token, session, or TTL changes. |
| Tests | `main_test.go`, `web_ui_test.go`, `web/e2e/notes-search.spec.js`, `web/e2e/auth-notes.spec.js` | Go tests `TestNotesSearchFinds/NotFound/CaseInsensitive/Isolation/AuthRequired/EmptyQuery/WhitespaceQuery/Encoding/QueryTooLong`; static UI oracle `TestUISemantics`; SEARCH-E2E-1..N search scenarios; user-B isolation remains in auth E2E-6. |
| Deploy / docs | `deploy/path1/*`, `UI-GRAPH.yaml`, `design/*` | Preview on `test2` only; UI graph actualized at s21; DS pinned at s02a (`design/releases/1.0.0`). |

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
   `1.64.1` (root `package.json`) as a test-only dependency; `package.json`/lock
   are not rolled back.
5. **No title field.** `Note` is `{id, text}`; search is text-only.
   `noteSearchText()` tolerates a future `title` (joins `title` + `text`), but
   this feature must not add, emit, or require one.
6. **Frozen auth/storage/lifecycle.** No auth/session/persistence change; create,
   delete, and reload keep working. Order stays auth → method → query handling.
7. **UI contract.** Stable testids `notes-search`, `notes-search-clear`,
   `notes-search-count`, `notes-search-empty`; labelled `type="search"` with
   `aria-controls="notes-list"`; clear restores the full list; search-empty is
   only for a non-empty query that filters a non-empty collection to zero; base
   `notes-empty` wins when there are no notes at all; search is disabled while
   the list is busy, failed, or offline.
8. **No query persistence.** The query lives in `searchQuery` (in-memory) and is
   cleared on login/logout/401; it is not restored after reload and never enters
   the URL/hash. `sessionStorage["notebook.search"]` is only *removed*
   defensively (legacy key) and is never read or written.
9. **Scope guard.** No unrelated refactors; production/main/stage and canary are
   out; `f-v3-auth-notes`, `E4312`, `E1320` are untouched.

## 3. Potential conflicts

| Conflict | Evidence | Risk | Mitigation |
|---|---|---|---|
| Client-side filter vs server `q` | UI never sends `?q`; the API implements and tests it | Matching drift (Go `ToLower` vs JS `toLowerCase`, trim rules) and duplicate logic | Keep the UI filter authoritative for the screen; server `q` is the API contract for clients; share acceptance vectors; do not move to per-keystroke requests without a new decision. |
| Title tolerance vs text-only contract | `noteSearchText()` joins `note.title` if present; API filters `note.Text` only | A future/phantom `title` could make UI and API results diverge | Keep `Note = {id, text}`; do not add or send `title`; any title feature is a separate data-model change. |
| State sync (no storage) | `searchQuery`, input value, and `notes[]` coexist; no persistence | Stale/hidden query after user switch or 401 | `renderNotes()` is the single path: input and list always derive from `searchQuery`; clear on login/logout/401; cover reload and user-B in E2E. |
| DS tokens vs current CSS | CSS uses off-scale 6/10/14/18/20/48px; `.notes-search-empty` rule exists alongside `.muted`; `--border-subtle` may be unused | False "token-compliant" claim and visual drift | Pin DS 1.0.0 by manifest; s03 maps states to existing tokens; gaps become DS proposals, not ad-hoc values; s22a audits rendered CSS. |
| Empty-state precedence | Zero notes + non-empty `q` shows `notes-empty`; search input disabled; `web_ui_test.go` asserts the precedence | Brief wording can be read as requiring `notes-search-empty` | Closed by AOD-1; no code change at s02. |
| Release snapshot | DS 1.0.0 manifest `code.sha256` is the release snapshot, not the current `web/` | Manifest misread as a live hash of current code | Pin tag/digest; do not claim current `web/` equals release code; re-release only if DS changes. |

## 4. Design recommendations (s02a / s03)

- **One screen only:** the notes screen gains search above the list; login and
  register are unchanged.
- **Pin Notebook DS 1.0.0** from `design/releases/1.0.0/manifest.json`
  (`ds/v1.0.0`, digest), using `design/tokens.json` and `design/registry.json`.
  No new DS release if existing tokens cover search.
- **States to specify:** idle (empty query, list), loading (`notes-loading`),
  results (query + matches + `notes-search-count`), search-empty
  (`notes-search-empty`), base-empty (`notes-empty`), error (`notes-error` for
  load/create/delete/401), and offline (banner "Нет сети — показаны загруженные
  заметки."; search disabled; no new API behavior).
- **Breakpoints:** 390px mobile (search row stacked, full-width 44px controls, no
  horizontal scroll) and 1200px desktop (centered column/card, inline search +
  clear). Current CSS has a 640px column and one `max-width: 640px` query;
  frames must map onto it, not invent a second system.
- **Accessibility:** visible label "Поиск заметок", `type="search"`,
  `aria-controls="notes-list"`, clear `aria-label`, live result count
  (`aria-live="polite"`), accessible names on the empty states, 3px focus ring.
- **Copy:** "Поиск заметок", "Поиск по тексту...", "Ничего не найдено.",
  "Найдено N", clear control; text-only, no title.
- **No extra controls/states:** keep create and delete untouched; do not add
  pagination, ranking, highlighting, or a title field.

## 5. Open decisions

| ID | Decision | Options | Resolution | Status |
|---|---|---|---|---|
| OD-1 | Whitespace-only `q` | all notes / `400` | All notes (trim → empty → all), per s01 and the brief | **Closed** by `feature-brief.md` and `TestNotesSearchWhitespaceQuery`. |
| OD-2 | Zero notes + non-empty `q` | base-empty / search-empty | Base-empty wins; search disabled when the collection is empty | **Closed** by AOD-1. |
| OD-3 | UI filtering source | client-only / debounced server `q` | Client-only for this feature; server `q` remains the API contract | **Closed** by AOD-2. |
| OD-4 | Query persistence across reload | restore via `sessionStorage` / reset | Reset: no persistence, cleared on login/logout/401 | **Closed** by AOD-3; current code matches. |
| OD-5 | DS empty-state drift | normalize `.notes-search-empty` vs `.muted` | Normalize at s03/s22a; do not add a token for one state | Open for s03/s22a (design audit, not s02). |
| OD-6 | Unicode case-fold parity | accept Go/JS differences / define normalization | Accept and document: no locale-specific collation; test ASCII, Cyrillic, and special characters | **Closed** by `feature-brief.md` and `TestNotesSearchEncoding`. |

No blocking decision remains for s02a/s03. The only open item (OD-5) is a
design-system drift check owned by s03/s22a.

## 6. Trace note

- `TestNotesSearchQueryTooLong` and `INV-SEARCH-Q-MAX` are both present; the
  invariant covers the 512-byte `400`-before-scan rule.
- User-B isolation is covered by `web/e2e/auth-notes.spec.js` E2E-6, not by
  `notes-search.spec.js`; s20c evidence must cite both suites.
- Non-blocking observation (no action at s02): `SEARCH_KEY` in `web/app.js` is
  only used for defensive `removeStorage` of a legacy key and is never read;
  removing it would be unrelated churn and stays out of this feature's scope.
