# Scope report — f-v4-note-search

- Execution/step: **E6588** · `s02.architect_scope_analysis` · role **architect**
- Process: `path-1.feature@4.0.0`, entry `default`, platform `web`, profile `full`
- A/B arm: `path-10`, key `notebook-path10-08`
- Branch: `dev/path10-runner-06` · base `9e7fae353c61e717505dc40019627a1d7ab48820`
- Input: draft brief `feature-brief.md`, `s01-product-discuss.md` (E6588, done),
  `feature-request.md` (raw, 45 items)
- Status: scope re-validation for this execution. No code, `web/`, `design/`, or
  test change is made at s02; scope is frozen to the request.
- Sources: `feature-brief.md`, `s01-product-discuss.md`, `invariants.json`,
  `plan.md`, `main.go`, `main_test.go`, `web_ui_test.go`, `web/*`,
  `web/e2e/*`, `design/releases/1.0.1/manifest.json`, `ds-pin.json`,
  `UI-GRAPH.yaml`.

## 1. Affected domains / layers

| Domain / layer | Surface | Change / status |
|---|---|---|
| Web UI (`notebook-web`) | `web/index.html`, `web/app.js`, `web/app.css`, `web_ui_test.go` | `notes-search` input, `notes-search-clear`, `notes-search-count`, `notes-search-empty`; client-side filter of the loaded owner-scoped list; one `renderNotes()` re-applies the active query after load/create/delete/reload. Query is **in-memory only** (`searchQuery`, `web/app.js:335`); the legacy `notebook.search` key is only removed, never written. |
| Notes API (`notebook-api`) | `main.go` (`handleNotes`, `ListNotes`) | Optional `q` on `GET /api/notes`: trim → empty means all; non-empty means case-insensitive substring; `maxQueryBytes = 512` (`main.go:33`); empty result is `[]`, never `null`; JSON error envelope. |
| Storage scope | In-memory `Store` (`main.go:195`) | Read-only projection; owner predicate `note.UserID == session.UserID` applied before the text filter; no schema/migration; `UserID` stays out of the wire payload (`Note.UserID` is `json:"-"`). |
| Auth | `requireAuth`, bearer parsing | Unchanged; `401` before method/query handling; no token, session, or TTL changes. |
| Tests | `main_test.go`, `web_ui_test.go`, `web/e2e/notes-search.spec.js`, `web/e2e/auth-notes.spec.js` | Go: `TestNotesSearch{Finds,NotFound,CaseInsensitive,Isolation,AuthRequired,EmptyQuery,WhitespaceQuery,Encoding,QueryTooLong}` plus `TestNotesIsolation`/`TestNotesPrefixBoundary`; static UI oracle in `web_ui_test.go`; 14 search E2E scenarios; user-B isolation remains in auth E2E-6. |
| Deploy / docs | `deploy/path1/*`, `UI-GRAPH.yaml`, `design/*` | Preview on `test2` only; UI graph actualized at s21 (`UI-GRAPH.yaml` release `1.0.1`); DS pinned at s02a. |

## 2. Architecture constraints

1. **Same-origin static only.** The UI is embedded from `web/index.html`,
   `web/app.js`, `web/app.css`; no CDN, new origin, CORS, framework, or bundler.
   `fetch` uses `credentials: "same-origin"`; unknown paths stay `404`.
2. **Owner-scoped only.** `q` may narrow the result but must never widen it.
   Missing and foreign notes stay indistinguishable; `UserID` remains `json:"-"`.
3. **`q` cap.** A decoded `q` longer than 512 bytes returns
   `400 {"error":"query too long"}` before any note scan; exactly 512 bytes is
   accepted (`main.go:541-544`). The cap is bytes, not runes.
   Absent/empty/whitespace `q` (≤512) returns all own notes.
4. **No new dependencies.** `go.mod` unchanged (`module
   github.com/ukituki-ps/notebook`, `go 1.23`); vanilla JS/CSS; Playwright stays
   1.64.1 as a test-only dependency; `package.json`/lock are not rolled back.
5. **No title field.** `Note` is `{id, text}` (`main.go:67-71`); search is
   text-only. `noteSearchText()` tolerates a future `title`, but this feature
   must not add, emit, or require one.
6. **Frozen auth/storage/lifecycle.** No auth/session/persistence change;
   create, delete, and reload keep working. Order stays auth → method → query
   handling.
7. **UI contract.** Stable testids `notes-search`, `notes-search-clear`,
   `notes-search-count`, `notes-search-empty`, `notes-empty`; labelled
   `type="search"` with `aria-controls="notes-list"`; clear restores the full
   list; search-empty is only for a non-empty query that filters a non-empty
   collection to zero; base `notes-empty` wins when there are no notes at all.
8. **Ephemeral query.** The active query is not persisted across reload or in
   URL/hash; it is cleared on login/logout/401 and on a missing token. Reload
   restores the full list. This matches `invariants.json` ("Do not persist the
   query across reload or in the URL/hash").
9. **Scope guard.** No unrelated refactors; production/main/stage and canary are
   out; `f-v3-auth-notes`, `E4312`, `E1320` are untouched.

## 3. Verified base surface

Confirmed at base `9e7fae3` (`s01` made no code change):

- `handleNotes` (`main.go:530`): auth → `q` cap (`main.go:541-544`) →
  `ListNotes(session.UserID)` (`main.go:547`) → case-insensitive substring
  filter (`main.go:548-556`) → `writeJSON(200, notes)`.
- `ListNotes` (`main.go:195`) returns a non-nil `[]Note`; no match therefore
  serialises as `[]`.
- `web/app.js`: `filterNotes()` (`:443`) and `renderNotes()` (`:454`) implement
  trim + lowercase filtering and re-apply; clear/count/empty precedence
  (`:475-480`); `notebook.search` is only removed (`:177`, `:487`, `:596`,
  `:607`, `:733`, `:792`), never written.
- `web/index.html:79-106`: `role="search"` region, `<label for="notes-search">`,
  `type="search"`, `aria-controls="notes-list"`, clear/count/empty testids.
- `web_ui_test.go:53-55,175-189`: static assertions for the same contract.
- `web/e2e/notes-search.spec.js`: 14 scenarios covering find/not-found/case,
  clear, create/delete under an active query, whitespace, no-token cleanup,
  count, zero notes, loading, error/retry, offline, offline-zero.
- `ds-pin.json`: Notebook DS `1.0.1`, digest `sha256:4e0ef105…c85e`, screen
  `note-search`, approved by team-lead. `UI-GRAPH.yaml` release `1.0.1`.
- `invariants.json`: `change_class = "plain"`.

## 4. Potential conflicts

| Conflict | Evidence | Risk | Mitigation |
|---|---|---|---|
| Client-side filter vs server `q` | UI never sends `?q`; the API implements and tests it | Matching drift (Go `ToLower` vs JS `toLowerCase`, trim rules) and duplicate logic | UI filter is authoritative for the screen; server `q` is the API contract for clients; share acceptance vectors; no per-keystroke requests. |
| State duplication | `searchQuery`, input value, and `notes[]` coexist | Stale/hidden query after reload, user switch, create/delete | `searchQuery` is the single source; always sync the input; reload yields empty query; cover reload and user-B in E2E. |
| Legacy storage key | `notebook.search` is removed but never written (`web/app.js:177`, `:487`, `:596`, `:607`, `:733`, `:792`) | Reader may assume persistence or a restore path that does not exist | Document as cleanup-only; do not add a writer at s03; s22a checks for no persistence. |
| DS tokens vs current CSS | DS `1.0.1` tokens are extracted from `app.css`; CSS still uses off-scale px values and `.notes-search-empty` is dead (the element uses `.muted`) | False "token-compliant" claim and visual drift | Pin DS 1.0.1 by manifest at s02a; s03 maps states to existing tokens; s22a audits rendered CSS. |
| Release snapshot | DS 1.0.1 manifest `code.sha256` is the release snapshot; current `web/` has feature edits | Manifest misread as a live hash of current code | Pin tag/digest; do not claim current `web/` equals release code; re-release only if DS changes. |

## 5. Design recommendations (s02a / s03)

- **Pin Notebook DS `1.0.1`** from `design/releases/1.0.1/manifest.json`
  (digest `sha256:4e0ef1052a1401a928588445f921f7d231b7c0e7c9b10c181fdbbb439108c85e`),
  matching `ds-pin.json`; use `design/tokens.json` and `design/registry.json`.
  No new DS release if existing tokens cover search.
- **One screen only:** the notes screen gains search above the list; login and
  register are unchanged.
- **States to specify:** idle (empty query, list), loading (`notes-loading`),
  results (query + matches), search-empty (`notes-search-empty`), base-empty
  (`notes-empty` + search disabled), error (`notes-error`/`notes-retry`), and
  offline (`notes-offline`/`notes-offline-check`, offline-zero).
- **Breakpoints:** 390px mobile (search row stacked, full-width 44px controls, no
  horizontal scroll) and 1200px desktop (centered column/card, inline search +
  clear). Current CSS has a 640px column and one `max-width: 640px` query;
  frames must map onto it, not invent a second system.
- **Accessibility:** visible label "Поиск заметок", `type="search"`,
  `aria-controls="notes-list"`, clear `aria-label`, `role="status"` +
  `aria-live="polite"` on the search empty state, 3px focus ring.
- **Copy:** "Поиск заметок", "Поиск по тексту...", "Ничего не найдено.", clear
  "Очистить"; text-only, no title.
- **No extra controls/states:** keep create and delete untouched; do not add
  pagination, ranking, highlighting, or a title field.

## 6. Open decisions

| ID | Decision | Options | Resolution | Status |
|---|---|---|---|---|
| OD-1 | Whitespace-only `q` | all notes / `400` | All notes (trim → empty → all) | **Closed** by `feature-brief.md`, s01 and `TestNotesSearchWhitespaceQuery`. |
| OD-2 | Zero notes + non-empty `q` | base-empty / search-empty | Base `notes-empty` wins and search is disabled (`invariants.json`, `SEARCH-E2E-10`) | **Closed**. |
| OD-3 | UI filtering source | client-only / debounced server `q` | Client-only: one in-memory owner-scoped list, no per-keystroke requests; server `q` stays the API contract | **Closed** for this feature. |
| OD-4 | Query persistence across reload | restore / reset | Reset: `searchQuery` is in-memory; `notebook.search` is cleanup-only; reload shows the full list | **Closed** by `invariants.json` and base code. |
| OD-5 | DS empty-state drift | add `.notes-search-empty` / rely on `.muted` | Normalize at s03/s22a; do not add a token for one state | Open for s03/s22a. |
| OD-6 | Unicode case-fold parity | accept Go/JS differences / define normalization | Accept and document: no locale-specific collation; test ASCII, Cyrillic, special characters | **Closed** by `feature-brief.md` and `TestNotesSearchEncoding`. |

No silent decisions: all but OD-5 are closed by the brief/invariants/base code;
OD-5 is a design-system normalisation item, not a product or API decision.

## 7. Scope verdict / handoff

- Change class: **plain**; affected: `notebook-api` (`GET /api/notes?q=`),
  `notebook-web` (search/clear/count/search-empty, client-side filter), tests
  (Go + static UI + Playwright), UI graph (`s21`), `test2` preview.
- Not affected: auth, sessions, storage/persistence, note lifecycle, wire model,
  dependencies, deploy beyond `test2`.
- s02 makes no code/design change. Handoff: **s02a** pins DS `1.0.1`; **s03**
  (prototype) covers the states above; implementation must keep every constraint
  in §2 and the closed decisions in §6.
- Execution-context note: the raw request names `dev/f-v4-note-search`, while
  this execution's work branch is `dev/path10-runner-06`; a process fact, not a
  scope change.

## 8. Trace note

- `TestNotesSearchQueryTooLong` covers the 512-byte cap, but `invariants.json`
  has no corresponding invariant id. Recommend adding `INV-SEARCH-Q-MAX`
  (`400` before scan) at the next invariants refresh; not a blocker for s02.
