# Feature brief — f-v4-note-search (FINAL, s06)

## Problem

The notebook currently lists all of the signed-in user's notes. With more than a
handful of notes there is no way to locate a note by text without scanning the
whole list.

## Goal

Add a small, owner-scoped text search over the existing notes API and the notes
web view, without changing authentication, storage, or note lifecycle semantics.

## In scope

- `GET /api/notes?q=<text>` on the existing notes endpoint.
- Case-insensitive substring search over note text.
- Owner scoping: the result always contains only the current user's notes.
- Web UI search input in the notes view, live list filtering, clear action,
  and a dedicated "ничего не найдено" empty state.
- Tests (Go + Playwright), preview on `test2`, UI graph actualization.

## Out of scope

- Registration/login/session/token changes.
- Persistence changes (notes stay in-memory).
- Create/delete/reload behaviour changes.
- Pagination, sorting, ranking, fuzzy matching, server-side highlighting.
- Production/main/stage deployment and canary rollout.

## API contract

`GET /api/notes?q=<text>`

| Condition | Result |
|---|---|
| No bearer token | `401` |
| No `q` parameter | `200`, all notes of the current user |
| `q=` (empty after trim) | `200`, all notes of the current user |
| `q` contains only whitespace | `200`, all notes of the current user |
| `q` non-empty | `200`, current user's notes whose text contains `q`, case-insensitive |
| No matches | `200`, `[]` (never `null`) |
| Other methods on `/api/notes` | unchanged (`405` with `Allow`) |

Decision on whitespace-only `q`: **treated like empty `q` — return all notes.**
Reason: the UI sends the trimmed input; an all-whitespace query is an empty
search, not a client error. This keeps the endpoint forgiving and avoids a
second error path that the UI would have to special-case. The decision is
recorded as a closed open-decision in `expertise-report.md`.

Search semantics:

- ASCII case-insensitivity is guaranteed with `strings.Contains` on
  `strings.ToLower(text)` / `strings.ToLower(q)`.
- Unicode case-insensitivity follows Go's `strings.ToLower`; no locale-specific
  collation is promised.
- Substring matching, not prefix/token matching.
- `q` is decoded by `net/http` from the query string; URL-encoded and special
  characters must work without panics.
- Note text boundaries are unchanged; search does not alter stored text.

## UX

- The notes screen gains a labelled search input above the list.
- Typing filters the rendered list client-side against the notes already loaded
  for the signed-in user. Clearing the field restores the full list.
- While the query has no matches, the list area shows the empty state
  "ничего не найдено" with `data-testid="notes-search-empty"`.
- The search input has `data-testid="notes-search"`.
- Create, delete, and reload flows keep working; after create/delete the active
  query is re-applied to the updated list.

## Wireframes (s03, ASCII, revalidated for E8363)

All states below are implemented by `web/index.html` + `web/app.js`; testids are
quoted exactly. The notes page is reached from `login`/`register`; a 401 from any
notes call returns the user to `login`.

### Auth screens — login / register (unchanged from f-v3)

```
+------------------------------------------------------+
| Notebook                                             |
+------------------------------------------------------+
|  login card / register card                          |
|  [data-testid="login-form"|"register-form"]          |
|  error line: [data-testid="login-error"|...]         |
|  link: login-link <-> register-link                  |
+------------------------------------------------------+
        login-success -> notes      register-success -> login
```

### Notes screen — idle / list (query empty or whitespace)

```
+------------------------------------------------------+
| Notebook                    user: [user-name] [logout]|
| +--------------------------------------------------+ |
| | [data-testid="note-input"]          [add-note]   | |
| +--------------------------------------------------+ |
| +--------------------------------------------------+ |
| | label: Поиск заметок                             | |
| | [data-testid="notes-search"]                     | |
| | [data-testid="notes-search-clear"] Clear          | |
| | (clear hidden while query is empty)              | |
| +--------------------------------------------------+ |
| [note-item id=1] #1 Buy milk            [delete-note]|
| [note-item id=2] #2 Project plan        [delete-note]|
+------------------------------------------------------+
```

### Notes screen — filtering (trimmed query non-empty)

```
+------------------------------------------------------+
| [notes-search] value="milk"   [notes-search-clear]   |
| matching note-item rows stay visible;                    |
| non-matching rows are hidden; no per-keystroke request   |
+------------------------------------------------------+
```

### Notes screen — search results / search-empty

```
query matches >=1:   notes-list visible with the matching note-item rows
                     notes-search-empty hidden
query matches 0:     [data-testid="notes-search-empty"]
                     role=status aria-live=polite
                     "Ничего не найдено."
                     no note-item visible; notes-empty hidden
```

### Notes screen — genuinely empty server list

```
GET /api/notes -> 200 [] with an empty query
[data-testid="notes-empty"] visible; notes-list hidden;
notes-search-empty hidden (reserved for a non-empty query)
```

### Notes screen — loading

```
notes-loading visible; notes-list / notes-empty / notes-search-empty hidden;
note-form and search controls disabled until the list is loaded
```

### Notes screen — error

```
GET != 200 or network error:
[data-testid="notes-error"] visible with the existing f-v3 message;
POST/DELETE failures use the same error region and keep search usable;
after a failed initial GET the list/search controls stay disabled (existing
f-v3 behaviour) until a successful reload
```

### Notes screen — unauthorized / session expired

```
401 or missing token:
clear notebook.token/user; [data-testid="notes-error"]
"Сессия истекла..." then navigate to /login (unchanged from f-v3)
```

### Search state machine

```
idle --(trimmed q non-empty)--> filtering --> results | search-empty
  ^                                              |
  +----------- clear / empty query --------------+
create/delete/reload while filtering -> re-apply the same filter
```

Interaction and accessibility notes:

- The search input has a visible `<label>` and an accessible name.
- `notes-search-clear` is a separate button, hidden while the query is empty.
- The empty state replaces only the list region; the search input and the
  create form stay usable.
- The loading, error and 401 states of the existing page are unchanged; the
  search controls are disabled while loading and usable in every loaded state.

## Acceptance criteria

1. Backend unit tests cover: find, not found, foreign notes invisible, `401`,
   empty/whitespace query, URL-encoding and special characters.
2. All three units build; `go build`, `go vet`, `go test` are green.
3. UI search filters and clears correctly; empty state appears only when a
   non-empty query has no matches.
4. Playwright E2E on `test2` passes all requested scenarios, including user B
   isolation; `pngdiff` is OK.
5. UI graph (`UI-GRAPH.yaml`) is actualized from code at s21.
6. s22a UI audit, s22b/s22c independent reviews, and s24 owner approval pass.

## Invariants

The machine-readable list is `invariants.json`. Core search invariants:

- `INV-SEARCH-OWNER-SCOPE` — search never returns another user's notes.
- `INV-SEARCH-CASE-INSENSITIVE` — `q` matches text case-insensitively.
- `INV-SEARCH-EMPTY-Q` — absent/empty/whitespace `q` returns all own notes.
- `INV-SEARCH-AUTH-REQUIRED` — no bearer → `401` before any search handling.
- `INV-SEARCH-ENCODING` — URL-encoded/special characters are safe.
- `INV-SEARCH-UI-FILTER` — UI filters the loaded list and clears correctly.
- `INV-SEARCH-UI-EMPTY` — non-empty query with no matches shows the search empty state.
- Existing auth/isolation/UI invariants remain active and unchanged.

## Risks

- Regressing existing owner isolation while adding a query branch — mitigated by
  an explicit foreign-note test and the existing isolation oracles.
- Divergence between client-side filtering and server-side search — the UI
  filters the already owner-scoped list it received; backend search is tested
  independently.
- Breaking create/delete/reload wiring — covered by the existing Go UI tests and
  the E2E regression scenarios.

## Finalization note (s06)

Finalized at **s06** under execution **E8363** as a fresh re-validation on
platform `730d144a` (design revalidated in s01–s05; no platform or path-1
changes). The s03 wireframes are the **10-state** schema — login, register,
idle/list, filtering, search-results, search-empty, genuinely-empty, loading,
error, unauthorized — with the auth, loading, error and 401 states explicitly
unchanged from f-v3.

Machine-readable invariants (`invariants.json`): **16 active + 2 proposed**
(18 total). All 16 active invariants have an executable `test_ref`; the two
proposed ones (`INV-UI-ORACLE`, `INV-UI-E2E-PREVIEW`) remain **proposed** until
their oracles materialize at s22a/s20c. No auth/persistence invariant is
relaxed by this feature.

Open decision **OD-6** (whether the `sessionStorage` query survives a full page
reload) is carried to s08 as needs-human (low); this brief does not make query
persistence part of the contract.

Historical prior finalization: s06/E9294 against `expertise-report.md`
(`c1cf18c`). This pass re-validates that text unchanged and does not re-stamp
prior-run artifacts.
