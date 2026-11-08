# Feature brief — f-v4-note-search (FINAL, s06)

- Execution: **E0809** · step **s06.feature_brief_final**
- Branch: `dev/f-v4-note-search-e2e`
- `change_class`: **plain**
- Machine-readable result fields: `invariants[]`, `do[]`, `dont[]`,
  `out_of_scope[]`, `change_class` (`invariants.json`; this file carries the
  human-readable Do/Don't/Out-of-scope sections).

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

## Do

- Implement `GET /api/notes?q=<text>` as an optional filter on the existing
  owner-scoped notes endpoint.
- Match note text as a case-insensitive substring (`strings.ToLower` on both
  sides), trimming the decoded query first.
- Return only the current user's notes; apply the owner predicate before the
  text predicate so `q` can narrow but never widen the result.
- Cap the decoded query at 512 bytes and return
  `400 {"error":"query too long"}` before scanning.
- Return `200 []` (never `null`) when a non-empty query matches nothing.
- Add a labelled search input (`data-testid="notes-search"`), a clear control
  (`data-testid="notes-search-clear"`), and a search empty state
  (`data-testid="notes-search-empty"`) to the notes screen.
- Filter the already loaded owner-scoped list client-side, with no request per
  keystroke; re-apply the active query after create, delete, and reload.
- Show `Найдено N` only for a non-empty trimmed query, with `aria-live="polite"`;
  hide the count when the query is empty.
- Render note text with `textContent` (no `innerHTML`).
- Cover the backend contract with existing Go tests and the UI behaviour with
  `web/e2e/notes-search.spec.js` on the `test2` preview.

## Don't

- Do not change authentication, sessions, bearer/TTL handling, or the 401 path.
- Do not add persistence, a schema field, a migration, or a cache; notes stay
  in-memory.
- Do not add a title field or search titles; the model remains `{id, text}`.
- Do not add pagination, ranking, fuzzy matching, highlighting, or
  per-keystroke/debounced server search.
- Do not send `q` from the UI: the client-side filter is the feature path and the
  API query is the server contract.
- Do not persist the query across a reload or in the URL/hash; it is cleared on
  login/logout/401.
- Do not show the search empty state for a zero-note collection; the base
  `notes-empty` state wins and search is disabled when `notes.length == 0`.
- Do not invent a second design system, local CSS, a new dependency, a CDN, or a
  bundler; use Notebook DS 1.0.0 and the existing `web/app.css`.
- Do not touch `design/`, code, or `web/` at s06; this step finalizes the brief
  and invariants only.

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
| `q` longer than 512 bytes | `400 {"error":"query too long"}`, before any note scan |
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
- `q` is capped at 512 bytes on the decoded value (`maxQueryBytes`); a longer
  query is rejected with `400` before the notes are scanned. 512 bytes is
  accepted. The cap is a byte limit, not a character limit.
- `q` is decoded by `net/http` from the query string; URL-encoded and special
  characters must work without panics.
- Note text boundaries are unchanged; search does not alter stored text.

## UX

- The notes screen keeps the existing order: note composer above the search
  field, then the list (AOD-7). This matches the current app, the
  `prototypes/v6` export, and the Notebook DS; the search-first s03 ASCII
  wireframe is the earlier reference that deviates from this final order.
- The notes screen gains a labelled search input above the list.
- Typing filters the rendered list client-side against the notes already loaded
  for the signed-in user. Clearing the field restores the full list.
- When the loaded collection has zero notes, the base empty state wins and the
  search input is disabled (AOD-1).
- While the trimmed query is non-empty and has no matches, the list area shows
  the empty state "Ничего не найдено." with
  `data-testid="notes-search-empty"`.
- The search input has `data-testid="notes-search"`; the clear control has
  `data-testid="notes-search-clear"`.
- The result count `Найдено N` (`data-testid="notes-search-count"`) is shown
  only for a non-empty trimmed query, uses `aria-live="polite"`, and is hidden
  when the query is empty (AOD-5).
- The query is in-memory only: it is not restored after a reload and is cleared
  on login/logout/401 (AOD-3). The input and the rendered list are always in
  sync.
- Offline uses only the notes already loaded in memory; there is no cache or
  persistence. An offline banner says that loaded notes are shown, and an
  offline-zero variant covers the case where nothing was loaded (AOD-4).
- Feature copy is Russian. Existing `Add`/`Logout` remain English under the
  documented DS-term policy; the Delete button's visible label becomes
  `Удалить` with `aria-label="Удалить заметку #N"` (AOD-6).
- Create, delete, and reload flows keep working; after create/delete the active
  query is re-applied to the updated list.

## Wireframes (s03, ASCII)

> Historical s03 sketches. The final vertical order is set by **AOD-7**: the
> note composer stays above the search field (current app, `prototypes/v6`
> export, and Notebook DS). The s03 ASCII wireframes below drew search first and
> are superseded by AOD-7; this is the documented layout deviation.

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

The machine-readable list is `invariants.json` (20 invariants: 18 active +
2 proposed). Core search invariants:

- `INV-AUTH-REQUIRED` — no/bad bearer → `401` before method/query handling.
- `INV-USER-ISOLATION` — a user never sees another user's notes.
- `INV-SEARCH-OWNER-SCOPE` — search never returns another user's notes.
- `INV-SEARCH-CASE-INSENSITIVE` — `q` matches text case-insensitively.
- `INV-SEARCH-EMPTY-Q` — absent/empty/whitespace `q` returns all own notes.
- `INV-SEARCH-NOT-FOUND` — a non-matching `q` returns `200 []`.
- `INV-SEARCH-ENCODING` — URL-encoded/special characters are safe.
- `INV-SEARCH-Q-MAX` — `q` > 512 bytes → `400` before scanning.
- `INV-WIRE-CASING` — wire JSON keys stay lower-case; `UserID` is not exposed.
- `INV-REAL-TRANSPORT` — search tests use the real HTTP transport.
- `INV-NO-SKIP-TAGS` — invariant tests are not excluded by build tags.
- `INV-UI-TRUTH` — the UI renders the real API data, not phantom notes.
- `INV-UI-LABEL` — search/clear/delete controls keep labels.
- `INV-UI-A11Y-NAME` — the search field and states have accessible names/roles.
- `INV-XSS-ESCAPE` — note text is rendered via `textContent`, never `innerHTML`.
- `INV-SEARCH-UI-FILTER` — the UI filters the loaded list and clears correctly.
- `INV-SEARCH-UI-EMPTY` — a non-empty query with no matches shows the search
  empty state; a zero-note collection keeps the base empty state.
- `INV-SEARCH-UI-TESTIDS` — `notes-search` and `notes-search-empty` stay stable.
- `INV-UI-ORACLE` (proposed) — every UI-audit criterion has an executable oracle
  and evidence at s22a.
- `INV-UI-E2E-PREVIEW` (proposed) — the search scenarios pass on `test2` at
  s20c with an e2e report/screenshot.

Existing auth/isolation/UI invariants remain active and unchanged.

## Final decisions (s06)

The seven architect open decisions from `expertise-report.md` are closed as
follows. They override earlier recommendations where they differ; s20 implements
them and s22a/s22b/s22c verify them.

### AOD-1 — Zero notes + non-empty query

**Decision:** the base empty state wins; the search input is disabled when
`notes.length == 0`.

**Rationale:** "Ничего не найдено" is misleading when the collection itself is
empty: the user cannot find a note that does not exist yet. The base
`notes-empty` state ("Пока нет заметок. Добавьте первую выше.") points to the
only useful action. A disabled search avoids a control that can never produce a
result and removes an ambiguous second empty state. The invariant
`INV-SEARCH-UI-EMPTY` records the precedence.

### AOD-2 — Client-side filter vs server `q`

**Decision:** the client-side filter is the feature path for the notes screen;
`GET /api/notes?q=` remains the server contract and is tested independently.

**Rationale:** the screen already holds the complete owner-scoped list, so one
in-memory filter gives immediate feedback, no request per keystroke, and keeps
create/delete consistent without a second source of truth. The API query is
still implemented, specified, and covered by existing Go tests so non-UI clients
and future large-list work have a real contract. This matches the feature
request and avoids a per-keystroke/debounced hybrid that would add latency and
failure modes without product value at the current list size.

### AOD-3 — Query persistence across reload

**Decision:** the query is not persisted across reload; it is cleared on
login/logout/401.

**Rationale:** a reload is treated as a fresh view of the notes screen, and a
stale hidden filter must not make notes appear missing. Keeping the query out of
`sessionStorage` and the URL/hash also removes the cross-user and no-token stale
state: after login, logout, or a `401` the search always starts empty. The input
value and `searchQuery` remain a single in-memory source of truth, so create and
delete still re-apply the active query within the session.

### AOD-4 — Offline data source

**Decision:** offline shows only notes already loaded in memory; there is no
persistence or cache. The offline state has a banner ("Нет сети — показаны
загруженные заметки.") and an offline-zero variant when no notes were loaded.

**Rationale:** the app has no service worker or durable cache, so promising
offline persistence would be false. The in-memory list is already owner-scoped
and is the only truthful source. The banner states exactly what is shown, and
the offline-zero variant avoids presenting an empty screen as "nothing found".
Adding a real cache is a separate persistence change and is out of scope.

### AOD-5 — Result count visibility

**Decision:** `Найдено N` is shown only for a non-empty trimmed query, with
`aria-live="polite"`, and is hidden when the query is empty.

**Rationale:** the count is feedback about an active filter. Showing it in the
unfiltered idle state adds noise and can be misread as a total. In the
results/no-results states it explains how many rows the query left, including
`Найдено 0` for a live query with no matches. The polite live region announces
the change without interrupting typing.

### AOD-6 — Language policy

**Decision:** feature copy is Russian. Existing `Add` and `Logout` stay English
under a documented DS-term policy. The Delete button's visible label becomes
`Удалить` with `aria-label="Удалить заметку #N"`.

**Rationale:** the new search surface is user-facing product copy and must be
Russian, consistent with "Поиск заметок", "Ничего не найдено", and the existing
Russian form label. `Add` and `Logout` are retained as documented DS/technical
terms to avoid an unrelated copy churn and because the DS reference uses them.
Delete is a per-row destructive action: a Russian visible label plus a
row-specific accessible name ("Удалить заметку #N") satisfies the label-in-name
rule and makes the action unambiguous for screen-reader users.

### AOD-7 — Layout order (390px and desktop)

**Decision:** keep the current app order (note composer above the search field)
to match the Notebook DS. This is the documented deviation from the earlier
search-first reference (the s03 ASCII wireframe / v6 design-brief layout); the
current `prototypes/v6` export already shows composer-first, so the final layout
is consistent with both the app and the refreshed v6 reference.

**Rationale:** the composer is the primary create action and the current app/DS/v6
place it first; moving search above it would change the screen structure and the
existing tests beyond the feature scope. Search remains above the list, so the
filter and its results stay adjacent. Recording the deviation from the earlier
search-first sketch (and its resolution in the refreshed v6 export) prevents s22a
from "fixing" the order to match a superseded outline.

## Finalization note (s06)

Finalized against `expertise-report.md` (`c1cf18c`). AOD-1..AOD-7 are closed in
"Final decisions (s06)" above. Machine-readable invariants:
**18 active + 2 proposed** (`INV-UI-ORACLE` and `INV-UI-E2E-PREVIEW`, whose
oracles materialize at s22a/s20c). No auth, isolation, or persistence invariant
is relaxed by this feature; `change_class` stays `plain`.

## Risks

- Regressing existing owner isolation while adding a query branch — mitigated by
  an explicit foreign-note test and the existing isolation oracles.
- Divergence between client-side filtering and server-side search — the UI
  filters the already owner-scoped list it received; backend search is tested
  independently.
- Breaking create/delete/reload wiring — covered by the existing Go UI tests and
  the E2E regression scenarios.
