# f-v4-note-search — spec/core (s14)

- Execution: **E9294**, step **s14.spec_generation**
- Branch: `dev/f-v4-note-search`, base `406fa965`
- Change class: **plain**; `feature_profile=full`; `path1.ui.json.platform=web`
- Normative inputs: [feature-brief.md](../feature-brief.md),
  [change-definition.md](../change-definition.md), [plan.md](../plan.md),
  [scope-report.md](../scope-report.md), [expertise-report.md](../expertise-report.md),
  [intent-brief.md](../intent-brief.md), [invariants.json](../invariants.json),
  `main.go`, `main_test.go`, `web/*`.
- Matrix: [contract-matrix.md](./contract-matrix.md).
- Step boundary: specs only; no code/adapter/UI changes at s14.

## 0. OpenAPI

`openapi/modules/*.yaml` is not used in this app repo (same precedent as
f-dev-v1/f-v3): there is no `openapi/common.yaml`, no generated API code, no
contract-first pipeline. The source of truth is this `core.md` +
`contract-matrix.md` + test names. `specs[].openapi_path = ""`.

## 1. API contract

### 1.1 `GET /api/notes` (existing operation, extended)

Auth: `Authorization: Bearer <opaque>`; missing/invalid/expired → `401`
with `WWW-Authenticate: Bearer` and `{"error":"unauthorized"}`. Auth is checked
before method/query handling.

Query parameter `q` (optional, UTF-8 string):

- absent → all notes of the current user;
- present but empty (`q=`) → all notes of the current user;
- whitespace-only after `strings.TrimSpace(q)` → all notes of the current user
  (closed decision OD-1);
- non-empty after trim → only the current user's notes whose `Text` contains
  `q` as a substring, case-insensitive via `strings.ToLower` on both sides;
- no matches → `200` with `[]` (never `null`).

Owner scope: the result set is always a subset of the notes whose
`Note.UserID == session.UserID`. `q` can only narrow, never widen.

Response: `200 application/json`, array of `{"id":N,"text":"..."}`; `UserID` is
not serialized. Response schema is unchanged.

Errors and headers are unchanged from the existing endpoint:

| Situation | Response |
|---|---|
| missing/bad/expired bearer | `401 {"error":"unauthorized"}` + `WWW-Authenticate: Bearer` |
| `PUT`/`DELETE` on `/api/notes` | `405 {"error":"method not allowed"}` + `Allow: GET, POST` |
| invalid request body (POST) | `400 {"error":"invalid request body"}` |
| text validation (POST) | `400 {"error":"text required"}` |
| unknown `/api/*` | `404 {"error":"not found"}` |

Query decoding: `r.URL.Query().Get("q")` (net/http). URL-encoded and special
characters (`%20`, `+`, `%2B`, `&`, emoji, Cyrillic) must be handled without
panic/500.

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

Notes screen (`/notes`) gains:

- a labelled search input with `data-testid="notes-search"`;
- a clear control (button with accessible name) that clears the query and
  restores the full list;
- live filtering of the already loaded owner-scoped notes list (client-side,
  no request per keystroke);
- an empty state `"ничего не найдено"` with
  `data-testid="notes-search-empty"`, shown only when the trimmed query is
  non-empty and the filtered list is empty;
- create/delete/reload keep working; after a mutation the active query is
  re-applied through the same filter function.

The existing `notes-empty` state remains for a genuinely empty server list.
Loading/error/401 handling is unchanged.

## 4. Invariants and oracles

Active invariants from `invariants.json`:

- `INV-SEARCH-OWNER-SCOPE` — `TestNotesSearchIsolation`;
- `INV-SEARCH-CASE-INSENSITIVE` — `TestNotesSearchCaseInsensitive`;
- `INV-SEARCH-EMPTY-Q` — `TestNotesSearchEmptyQuery`,
  `TestNotesSearchWhitespaceQuery`;
- `INV-SEARCH-NOT-FOUND` — `TestNotesSearchNotFound`;
- `INV-SEARCH-AUTH-REQUIRED` — `TestNotesSearchAuthRequired`;
- `INV-SEARCH-ENCODING` — `TestNotesSearchEncoding`;
- `INV-SEARCH-UI-FILTER` / `INV-SEARCH-UI-EMPTY` / `INV-SEARCH-UI-TESTIDS` —
  `TestUISemantics`;
- existing wire/auth/isolation invariants remain active.

## 5. Contract diff vs base (`406fa965`)

| Operation | Before | After | Kind |
|---|---|---|---|
| `GET /api/notes` | no query | optional `q`, trimmed, case-insensitive substring, owner-scoped | additive |
| `GET /api/notes` no-match | n/a | `200 []` | additive |
| `POST/DELETE/register/login` | unchanged | unchanged | none |
| UI notes screen | no search | search/filter/clear/empty | additive |
| data model / persistence | unchanged | unchanged | none |

No removed/renamed field, no status-code change for existing requests without
`q`. `contract_parity.drift_count = 0`.

## 6. Out of scope

Auth/session/token/persistence, pagination/ranking/fuzzy/highlighting, new
runtime dependencies, prod/main/stage, canary, s45/s46, f-v3/E4312/E1320.
