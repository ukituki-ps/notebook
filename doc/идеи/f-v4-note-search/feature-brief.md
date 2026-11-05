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

## Wireframes (s03, ASCII)

### Notes screen — default

```
+------------------------------------------------------+
| Notebook                                  [logout]   |
+------------------------------------------------------+
| Notes                                                |
| +--------------------------------------------------+ |
| | Search notes                          [ x ]      | |
| +--------------------------------------------------+ |
| +--------------------------------------------------+ |
| | Buy milk                                         | |
| |                                                  | |
| | [delete]                                         | |
| +--------------------------------------------------+ |
| +--------------------------------------------------+ |
| | Project plan                                     | |
| |                                                  | |
| | [delete]                                         | |
| +--------------------------------------------------+ |
| +--------------------------------------------------+ |
| | New note text...                     [add note]  | |
| +--------------------------------------------------+ |
+------------------------------------------------------+
```

### Notes screen — query matches one note

```
+------------------------------------------------------+
| Notes                                                |
| +--------------------------------------------------+ |
| | milk                                     [ x ]   | |
| +--------------------------------------------------+ |
| +--------------------------------------------------+ |
| | Buy milk                                         | |
| |                                                  | |
| | [delete]                                         | |
| +--------------------------------------------------+ |
+------------------------------------------------------+
```

### Notes screen — query matches nothing

```
+------------------------------------------------------+
| Notes                                                |
| +--------------------------------------------------+ |
| | zzzz                                     [ x ]   | |
| +--------------------------------------------------+ |
|                                                      |
|              ничего не найдено                       |
|           data-testid="notes-search-empty"           |
|                                                      |
+------------------------------------------------------+
```

Interaction and accessibility notes:

- The search input has a visible `<label>` and an accessible name (s03).
- The `[ x ]` clear control clears the input and restores the full list.
- The empty state replaces only the list region; the search input and the
  create form stay usable.
- The loading and error states of the existing page are unchanged.

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
