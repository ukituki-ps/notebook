# f-v4-note-search — spec/core (s14)

- Execution: **E0809**, step **s14.spec_generation**
- Branch: `dev/f-v4-note-search-e2e`, base `e6aeb44e`
- Process: `path-1.feature` **4.0.0** (entry `default`, platform `web`, profile `full`)
- Design System: **Notebook DS 1.0.0** — tag `ds/v1.0.0`, digest
  `sha256:02f027a86bbf8993bd1c14bbb91d5c3ba4453f47e886be73487a28d2044dda3d`
  (`02f027a8…da3d`), constraint `=1.0.0`
- Change class: **plain**; `feature_profile=full`; `path1.ui.json.platform=web`
- Normative inputs: [feature-brief.md](../feature-brief.md),
  [change-definition.md](../change-definition.md), [plan.md](../plan.md),
  [scope-report.md](../scope-report.md), [invariants.json](../invariants.json),
  [ds.lock.json](../ds.lock.json), [component-refs.json](../component-refs.json),
  [component-map.yaml](../component-map.yaml), [design-gaps.json](../design-gaps.json),
  `main.go`, `main_test.go`, `web/index.html`, `web/app.js`, `web/app.css`,
  `web_ui_test.go`.
- Matrix: [contract-matrix.md](./contract-matrix.md).
- Step boundary: specs only; no code/`web/`/`design/` change at s14, no commit.
- Base-code note: at `e6aeb44e`, `main.go` already implements the `q` contract in
  §1; the UI in §3 is the E0809 target. The base UI already has
  `notes-search`, `notes-search-clear`, `notes-search-empty`, `notes-empty`,
  `notes-loading`, `notes-error`, and a per-row Delete control, but not the
  count/retry/offline treatments, the `loading` status role, the final Russian
  copy, or the in-memory-only query rule. s20 (U02/T0005–T0008) implements those
  deltas; this spec does not claim they already exist.

## 0. OpenAPI

`openapi/modules/*.yaml` is not used in this app repo (same precedent as
f-dev-v1/f-v3): there is no `openapi/common.yaml`, no generated API code, no
contract-first pipeline. The source of truth is this `core.md` +
`contract-matrix.md` + test names. `specs[].openapi_path = ""`.

## 1. API contract

### 1.1 `GET /api/notes?q=<text>` (existing operation, extended)

Auth: `Authorization: Bearer <opaque>`; missing/invalid/expired → `401` with
`WWW-Authenticate: Bearer` and `{"error":"unauthorized"}`. Auth is checked
before method and query handling: an unauthenticated request with any `q`
returns `401` (never `400`/`200`).

`q` is optional and decoded by `net/http` from the query string
(`r.URL.Query().Get("q")`). Handling order is normative:

1. Auth: missing/bad/expired bearer → `401`.
2. Decode `q`.
3. **512-byte cap on the decoded value:** `len(q) > 512` bytes →
   `400 {"error":"query too long"}` before `ListNotes`/any note scan. Exactly
   512 bytes is accepted. The cap is bytes, not runes. The cap is evaluated
   before trim, so a >512-byte whitespace-only `q` is also `400`.
4. `strings.TrimSpace(q)`: absent, `q=`, and whitespace-only (≤512 bytes) →
   all notes of the current user.
5. Non-empty trimmed `q` → case-insensitive substring over `Note.Text` with
   `strings.ToLower` on both sides. ASCII case-insensitivity is guaranteed;
   Unicode follows Go's `strings.ToLower` and no locale-specific collation is
   promised.
6. **Owner predicate first:** `Store.ListNotes(session.UserID)` returns only the
   session user's notes, then the text predicate filters that slice. `q` can
   narrow, never widen the result.
7. No matches → `200` with `[]` (never `null`).

Response: `200 application/json`, array of `{"id":N,"text":"..."}`; the wire
schema is unchanged, the `id`/`text` keys stay lower-case, and `UserID` is
`json:"-"` and never serialized.

Errors and headers are unchanged from the existing endpoint:

| Situation | Response |
|---|---|
| missing/bad/expired bearer | `401 {"error":"unauthorized"}` + `WWW-Authenticate: Bearer` |
| decoded `q` > 512 bytes | `400 {"error":"query too long"}` before any note scan |
| `PUT`/`DELETE` on `/api/notes` | `405 {"error":"method not allowed"}` + `Allow: GET, POST` |
| invalid request body (POST) | `400 {"error":"invalid request body"}` |
| text validation (POST) | `400 {"error":"text required"}` |
| unknown `/api/*` | `404 {"error":"not found"}` |

Query decoding must remain safe for URL-encoded and special characters
(`%20`, `+`, `%2B`, `&`, emoji, Cyrillic) without panic/`500`.

### 1.2 Unchanged operations

`POST /api/register`, `POST /api/login`, `POST /api/notes`,
`DELETE /api/notes/{id}` keep their existing contract from f-v3. No auth,
storage, or lifecycle semantics change.

## 2. Data model

Unchanged:

```go
type Note struct {
    ID     int
    UserID int    `json:"-"`
    Text   string
}
```

No migration, no new field, no persistence.

## 3. UI contract

### 3.1 Layout order (AOD-7)

The notes screen keeps the composer-first order: header → notes error region →
note composer form → search field → notes list. Search stays above the list.
The s03 search-first ASCII sketch is superseded by AOD-7; the v6 prototype and
Notebook DS place the composer first.

### 3.2 Search controls and copy

- **Search field** `data-testid="notes-search"`: visible `<label
  for="notes-search">` with text **"Поиск заметок"**, placeholder
  **"Поиск по тексту..."**, `type="search"`, `aria-controls="notes-list"`, and
  an accessible name from the label.
- **Clear** `data-testid="notes-search-clear"`: visible label **"Очистить"**,
  `aria-label="Очистить поиск"`, hidden when the trimmed query is empty. It
  clears the query, restores the full list, and returns focus to the search
  field.
- **Result count** `data-testid="notes-search-count"`: text **"Найдено N"**
  (including `Найдено 0`), visible only for a non-empty trimmed query,
  `aria-live="polite"`, hidden when the query is empty (AOD-5).
- **Search empty** `data-testid="notes-search-empty"`: exact copy
  **"Ничего не найдено. Сократите запрос или очистите поиск."**,
  `role="status"`, `aria-live="polite"`, shown only when a non-empty trimmed
  query filters a non-empty note collection down to zero rows.
- **Base empty** `data-testid="notes-empty"`: **"Пока нет заметок. Добавьте
  первую выше."** The base empty state wins when `notes.length == 0`; the
  search empty state is not shown then, and the search field is disabled
  (AOD-1).
- **Loading** `data-testid="notes-loading"` with `role="status"`; search is
  disabled while loading.
- **Error** `data-testid="notes-error"` with `role="alert"` and
  `aria-live="polite"`; a visible **"Повторить"** control
  `data-testid="notes-retry"` is wired to `loadNotes`. Retry reuses the normal
  load path (loading state, 401 handling, and re-application of the active
  query).
- **Offline banner** `data-testid="notes-offline"` is driven by
  `navigator.onLine` plus the loaded notes. With loaded notes it states that
  loaded notes are shown; the offline-zero variant covers the case where no
  notes were loaded and does not render a false "nothing found" state. The
  **"Проверить сеть"** control `data-testid="notes-offline-check"` re-runs
  `loadNotes` when online (AOD-4). There is no cache or persistence.
- **Delete** per row: visible label **"Удалить"** and
  `aria-label="Удалить заметку #N"`. `Add` and `Logout` remain English under
  the DS-term policy (AOD-6).

### 3.3 Filtering and state rules

- The UI filters the already loaded owner-scoped list client-side; it does not
  send `q` per keystroke and does not add a server round-trip for filtering.
- The active query is in-memory only: it is not persisted in a URL/hash or in
  `sessionStorage`/`localStorage`, and it is cleared on login/logout/`401` and
  on reload (AOD-3). Base code currently restores it from
  `sessionStorage["notebook.search"]`; s20 removes that persistence.
- One `renderNotes()` path re-applies the active query after load, create,
  delete, and reload.
- Search is disabled when the collection is empty, while loading, in the error
  state, and offline; it remains enabled for a non-empty collection.
- Note text is rendered with `textContent`, never `innerHTML` (INV-XSS-ESCAPE).
- Clearing restores the full list and focuses the search input.

### 3.4 Breakpoints and accessibility

- **390px:** stacked search row, full-width 44px controls, no horizontal
  scroll.
- **1200px:** centered column/card with an inline search + clear row.
- Visible focus ring, labelled controls, `aria-live` regions for count/search
  empty/error, and `role="status"` for loading.

### 3.5 Design System

- Notebook DS **1.0.0** only (`ds/v1.0.0`, digest `02f027a8…da3d`): **12
  registry components** used, **0 local instances**, no local CSS, no second
  design system, no Kubiki, and no `frontend/src/ui/kit` usage.
- path6 gaps stay accepted and non-blocking: **GAP-1** (`n-count`, missing
  count pattern), **GAP-3** (`n-delete`, registry omission for the danger
  delete variant), **GAP-2** (missing disabled visual state for
  `primitives/input`).
- No `design/` or DS-file edit; the pinned digest does not change.

### 3.6 Base gaps to close at s20

- Base `web/index.html`/`web/app.js` still use visible `Clear`/`Delete`, the
  shorter `Ничего не найдено.` copy, and sessionStorage query persistence; U02
  must align them to §3.2–§3.3.
- Known base blocker **R-1:** `TestUISemantics` currently fails at
  `web_ui_test.go:264` because the oracle expects a literal
  `min-height: 44px` while `web/app.css` uses
  `min-height: var(--control-height)` (`--control-height: 44px`). U02/T0008
  must align the oracle to the DS token (or add a DS-compliant 44px height);
  no DS edit. The same UI oracle must add `notes-search-count`,
  `notes-retry`, `notes-offline`, and `notes-offline-check` references.

## 4. Invariants and oracles

Active invariants from `invariants.json`:

- `INV-AUTH-REQUIRED` — `TestNotesSearchAuthRequired` (401 before query);
- `INV-USER-ISOLATION` / `INV-SEARCH-OWNER-SCOPE` —
  `TestNotesSearchIsolation` (owner predicate before text predicate);
- `INV-SEARCH-CASE-INSENSITIVE` — `TestNotesSearchFinds`,
  `TestNotesSearchCaseInsensitive`;
- `INV-SEARCH-EMPTY-Q` — `TestNotesSearchEmptyQuery`,
  `TestNotesSearchWhitespaceQuery`;
- `INV-SEARCH-NOT-FOUND` — `TestNotesSearchNotFound`;
- `INV-SEARCH-ENCODING` — `TestNotesSearchEncoding`;
- `INV-SEARCH-Q-MAX` — `TestNotesSearchQueryTooLong` (the exactly-512 accept
  case is added at s20 per plan T0003);
- `INV-WIRE-CASING` — `TestWireContract`;
- `INV-REAL-TRANSPORT` — `TestHTTPTransport`, `TestNotesSearchEncoding`;
- `INV-NO-SKIP-TAGS` — no `integration`/`e2e`/`manual` build tags on invariant
  tests;
- `INV-UI-TRUTH`, `INV-UI-LABEL`, `INV-UI-A11Y-NAME`, `INV-XSS-ESCAPE`,
  `INV-SEARCH-UI-FILTER`, `INV-SEARCH-UI-EMPTY`, `INV-SEARCH-UI-TESTIDS` —
  `TestUISemantics` plus `web/e2e/notes-search.spec.js`;
- proposed `INV-UI-ORACLE` and `INV-UI-E2E-PREVIEW` materialize at s22a and
  s20c.

## 5. Contract diff vs base (`e6aeb44e`)

| Surface | Before (base `e6aeb44e`) | After (E0809 target) | Kind |
|---|---|---|---|
| `GET /api/notes?q` | trim, empty/whitespace → all, case-insensitive substring, owner-first, 512-byte cap, `[]` not `null` already in `main.go` | same contract, pinned by this spec and tested | none |
| `GET /api/notes?q` > 512 bytes | `400 {"error":"query too long"}` before scan; 512 accepted | same; exactly-512 oracle added at s20 | none |
| UI search/clear/search-empty | present; clear visible `Clear`, search-empty copy `Ничего не найдено.` | visible `Очистить`, final search-empty copy, count, retry, offline | changed / additive |
| UI states | loading has no `role=status`; no count/retry/offline; base empty wins | loading `role=status`; count/retry/offline/offline-zero; base empty precedence kept | additive / changed |
| UI delete | visible `Delete`; `aria-label` set in `app.js` | visible `Удалить` + `aria-label="Удалить заметку #N"` | changed |
| Query persistence | `sessionStorage["notebook.search"]` restore | in-memory only; cleared on login/logout/401/reload | changed |
| DS | Notebook DS 1.0.0, 12 components, 0 local instances | same; gaps accepted; no DS edit | none |
| data model / persistence | unchanged | unchanged | none |

No removed/renamed wire field and no status-code change for existing requests
without `q`. `contract_parity.drift_count = 0`, `items = []` (no OpenAPI
modules; the API contract matches `main.go` at the base). The UI deltas above
are the planned s20 target, not parity drift in the API contract.

Matrix delta for this revision (relative to the previous E9294 draft):
**added 14, removed 0, changed 6** rows. The added rows are the 512-byte
`400`/accepted cases, the wire row, and the ten `web /notes` UI rows; the six
changed rows refine the existing `q` envelopes (trim, owner-first, auth-before-q,
decoding wording).

## 6. Out of scope

Auth/session/token/persistence, pagination/ranking/fuzzy/highlighting, new
runtime dependencies, prod/main/stage, canary, s45/s46, f-v3/E4312/E1320,
`design/` edits, and Kubiki.
