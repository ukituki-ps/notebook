# f-v4-note-search — spec/core (s14)

- Execution: **E8363**, step **s14.spec_generation**
- Branch: `dev/f-v4-note-search-validation-zero`, base
  `5935e148` (`5935e148584b5fef28bd77ac4e45b800f10da03b`)
- Change class: **plain**; `feature_profile=full`; `path1.ui.json.platform=web`
- Pass: fresh E8363 re-validation of the existing spec at this head; only the
  spec/metadata is re-stamped, no platform/path-1/auth/persistence change.
- Normative inputs: [feature-brief.md](../feature-brief.md),
  [change-definition.md](../change-definition.md), [plan.md](../plan.md),
  [scope-report.md](../scope-report.md), [expertise-report.md](../expertise-report.md),
  [intent-brief.md](../intent-brief.md), [invariants.json](../invariants.json),
  [s10-change-definition.md](../platform-dev-validation-zero/s10-change-definition.md),
  [s11-plan.md](../platform-dev-validation-zero/s11-plan.md),
  `main.go`, `main_test.go`, `web/*`, `web_ui_test.go`, `web/e2e/*`.
- Matrix: [contract-matrix.md](./contract-matrix.md).
- Step boundary: specs only; no code/adapter/UI/deploy changes at s14.

## 0. Contract source and parity

`openapi/modules/*.yaml` is not used in this app repo (same precedent as
f-dev-v1/f-v3): there is no `openapi/common.yaml`, no generated API code, and no
contract-first/generated pipeline. The source of truth is this `core.md` +
`contract-matrix.md` + the executable test/E2E names. `specs[].openapi_path = ""`.

Because there is no generated contract to diff, contract parity is measured
against the checked contract rows in `contract-matrix.md` (30 API rows
`C-01..C-30` + 11 UI rows `U-01..U-11` = **41 rows**):

- every row has an executable Go/Playwright oracle at this head;
- no row is missing an oracle;
- `contract_parity.drift_count = 0` for this app repo (no openapi/generated
  pipeline, no un-oracled contract item).

The s14 row-by-row parity record is
[../platform-dev-validation-zero/s14-spec.md](../platform-dev-validation-zero/s14-spec.md).

## 1. API contract

### 1.1 `GET /api/notes` (existing operation, extended)

Auth: `Authorization: Bearer <opaque>`; missing/invalid/expired → `401`
with `WWW-Authenticate: Bearer` and `{"error":"unauthorized"}`. Auth is checked
before method/query handling.

Implementation shape (s10 C1 / s11 T0001): the handler calls
`ListNotes(session.UserID)` to obtain the owner-scoped snapshot, then applies the
`q` filter in the handler over that snapshot. There is no Store search helper.
The owner predicate therefore runs first and `q` can only narrow, never widen.

Query parameter `q` (optional, UTF-8 string):

- absent → all notes of the current user;
- present but empty (`q=`) → all notes of the current user;
- whitespace-only after `strings.TrimSpace(q)` → all notes of the current user
  (closed decision OD-1);
- non-empty after trim → only the current user's notes whose `Text` contains
  `q` as a substring, case-insensitive via `strings.ToLower` on both sides;
- no matches → `200` with `[]` (never `null`).

Owner scope: the result set is always a subset of the notes whose
`Note.UserID == session.UserID`.

Response: `200 application/json`, array of `{"id":N,"text":"..."}`; `UserID` is
not serialized. Response schema is unchanged.

Errors and headers are unchanged from the existing endpoint:

| Situation | Response |
|---|---|
| missing/bad/expired bearer (any method/path) | `401 {"error":"unauthorized"}` + `WWW-Authenticate: Bearer`; auth precedes method/query/id |
| `PUT`/`PATCH`/`DELETE` on `/api/notes` | `405 {"error":"method not allowed"}` + `Allow: GET, POST` |
| `GET`/`PUT`/`PATCH`/`POST` on `/api/notes/{id}` | `405 {"error":"method not allowed"}` + `Allow: DELETE` |
| invalid request body (POST) | `400 {"error":"invalid request body"}` |
| text validation (POST) | `400 {"error":"text required"}` |
| invalid id (DELETE) | `400 {"error":"invalid id"}` |
| foreign/missing note (DELETE) | `404 {"error":"not found"}` |
| unknown `/api/*` | `404 {"error":"not found"}` |

Query decoding: `r.URL.Query().Get("q")` (net/http). URL-encoded and special
characters (`%20`, `+`, `%2B`, `&`, emoji, Cyrillic) must be handled without
panic/500.

### 1.2 Unchanged operations

`POST /api/register`, `POST /api/login`, `POST /api/notes`,
`DELETE /api/notes/{id}` keep their existing contract from f-v3. No auth,
storage, or lifecycle semantics change. Their status/envelope rows are still
checked in the matrix (`C-15..C-30`) so the search change cannot silently drift
them.

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

Notes screen (`/notes`) gains:

- a labelled search input with `data-testid="notes-search"`, `type="search"`,
  `aria-controls="notes-list"`, placed above the list;
- a separate clear control (`data-testid="notes-search-clear"`, button with an
  accessible name) that clears the query and restores the full list; it is
  hidden while the raw query is empty;
- live filtering of the already loaded owner-scoped notes list (client-side,
  no request per keystroke);
- an empty state `"Ничего не найдено."` with
  `data-testid="notes-search-empty"`, `role="status"`, `aria-live="polite"`,
  shown **only** when all three hold:
  1. the trimmed query is non-empty;
  2. the loaded collection is non-empty (`!noNotes`);
  3. zero loaded notes match the query.
- create/delete/reload keep working; after a mutation the active query is
  re-applied through the same filter/render function.

The existing `notes-empty` state remains for a genuinely empty server list and
is not replaced by `notes-search-empty`.

`sessionStorage` key `notebook.search` and its reload-restore are an
implementation convenience **only** — not part of this contract (OD-6,
needs-human, s07 proposal "do not persist"). Reload must keep working, but the
query surviving a full page reload is not promised or tested as a contract item.

Loading/error/401 handling is unchanged. The six search E2E scenarios are
`SEARCH-E2E-1` find, `-2` not found/search-empty, `-3` case-insensitive,
`-4` clear restores full list, `-5` create while query active, `-6` delete while
query active. Login is a precondition in each; user-B isolation remains auth
E2E-6 plus `TestNotesSearchIsolation`, not a search-spec scenario.

Integration smoke is auth/notes API only (`E2E_API_ONLY=1 bash
deploy/path1/e2e-preview.sh`); it has no search `q=` assertion. Search E2E runs
through Playwright at s20c, auto-discovered by `playwright.config.js`
(`testDir: "web/e2e"`).

## 4. Invariants and oracles

Active invariants from `invariants.json`:

- `INV-SEARCH-OWNER-SCOPE` — `TestNotesSearchIsolation`;
- `INV-SEARCH-CASE-INSENSITIVE` — `TestNotesSearchFinds`,
  `TestNotesSearchCaseInsensitive`;
- `INV-SEARCH-EMPTY-Q` — `TestNotesSearchEmptyQuery`,
  `TestNotesSearchWhitespaceQuery`;
- `INV-SEARCH-NOT-FOUND` — `TestNotesSearchNotFound`;
- `INV-SEARCH-AUTH-REQUIRED` — `TestNotesSearchAuthRequired`;
- `INV-SEARCH-ENCODING` — `TestNotesSearchEncoding`;
- `INV-SEARCH-UI-FILTER` / `INV-SEARCH-UI-EMPTY` / `INV-SEARCH-UI-TESTIDS` —
  `TestUISemantics` + `SEARCH-E2E-1..6`;
- `INV-AUTH-REQUIRED` / `INV-USER-ISOLATION` — `TestAuthRequired`,
  `TestAuthMethodOrder`, `TestLoginInvalid`, `TestNotesIsolation`,
  `TestNotesSearchIsolation`, auth E2E-6/7;
- `INV-WIRE-CASING` / `INV-REAL-TRANSPORT` — `TestWireContract`,
  `TestHTTPTransport`;
- `INV-UI-TRUTH` / `INV-UI-LABEL` / `INV-UI-A11Y-NAME` — `TestUISemantics`;
- `INV-UI-ORACLE` / `INV-UI-E2E-PREVIEW` remain **proposed** until s22a/s20c
  materialize their evidence.

Every contract row in [contract-matrix.md](./contract-matrix.md) maps to one of
these oracles; no contract row is oracle-free.

## 5. Contract diff vs base (`5935e148`)

| Operation | Before | After | Kind |
|---|---|---|---|
| `GET /api/notes` | no query | optional `q`, trimmed, case-insensitive substring, owner-scoped, handler-level over `ListNotes` | additive |
| `GET /api/notes` no-match | n/a | `200 []` | additive |
| `POST/DELETE/register/login` | unchanged | unchanged | none |
| UI notes screen | no search | search/filter/clear/search-empty | additive |
| data model / persistence | unchanged | unchanged | none |
| integration smoke | auth/notes API | auth/notes API only (no search `q=`) | none |
| E2E | 7 auth scenarios | 7 auth + 6 search scenarios | additive |

No removed/renamed field, no status-code change for existing requests without
`q`. `contract_parity.drift_count = 0`.

## 6. Out of scope

Auth/session/token/persistence, pagination/ranking/fuzzy/highlighting, new
runtime dependencies, prod/main/stage, canary, s45/s46, f-v3/E4312/E1320,
contractual `sessionStorage` query persistence (OD-6).
