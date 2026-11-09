# Feature brief (DRAFT) — f-v4-note-search

- Execution: **E0942** · step **s01.product_discuss** · agent **product**
- Status: **DRAFT** — finalised later at `s06.feature_brief_final`
- Process: `path-1.feature@4.0.0`, entry point `default`, platform `web`,
  feature_profile `full`
- Base: `9e7fae3` · work branch: `dev/path10-runner-11`
- Source of truth: [feature-request.md](./feature-request.md) (immutable, 45
  items); this draft adds no scope beyond it
- Tentative `change_class`: **plain**

## 1. Problem

The notes screen lists every note of the signed-in user. As the list grows there
is no way to find a note by text except scanning the whole list, and
`GET /api/notes` has no filter.

## 2. Goal and users

Give a signed-in user a way to narrow their own notes to those containing a text
fragment, without changing authentication, storage, or note lifecycle.

- **Signed-in user** — types a text fragment, sees only their own notes whose
  text contains it (case-insensitive), clears the field to restore the full
  list, and gets a clear "ничего не найдено" state when nothing matches.
- **Unauthenticated caller** — any request to `/api/notes*` without a valid
  bearer still returns `401`; search does not open a new path around auth.
- **Other user** — never sees another user's notes, with or without `q`.

Data stays in memory as today; this feature does not add persistence.

## 3. In scope (draft)

Backend (U01) — existing notes endpoint gains an optional filter:

- `GET /api/notes?q=<text>`.
- Absent / empty / whitespace-only `q` → all notes of the current user.
- Non-empty `q` → only the current user's notes whose `text` contains `q`,
  case-insensitive.
- Owner scoping is always applied first; `q` narrows, never widens.
- `401` without a valid bearer token.
- `200 []` (never `null`) when a non-empty query matches nothing.
- `q` longer than 512 bytes → `400` before scanning notes.

Web UI (U02) — notes view:

- Labelled search input, clear control, client-side filtering of the loaded
  list, and a search-only empty state "Ничего не найдено".
- Stable `data-testid`s for the search field and the empty state.
- The active query is re-applied after create, delete, and reload.
- Create/delete/reload behaviour is not broken.

Deploy / E2E (U03):

- Preview deploy on `test2`.
- Playwright E2E: login, create two notes, search finds one, search finds
  nothing, clearing restores both, user B does not see user A's notes.
- Playwright 1.64.1; package/lock files are not rolled back.
- `pngdiff` OK.

## 4. Out of scope

- Auth, session, token, and storage changes; notes stay in-memory.
- Pagination, sorting, ranking, fuzzy matching, highlighting.
- Cross-user or global search.
- Title search: the model exposes only `Note.Text`, so the raw request's
  "title/body" wording is read as text-only.
- Reworking `f-v3-auth-notes`, `E4312`, or `E1320`.
- Production/main/stage deploy and canary rollout.
- Unrelated refactors and new dependencies.

## 5. Product decisions recorded at s01

These are the product-side decisions from this discussion. They are inputs to
`s02.architect_scope_analysis` and `s05/s06`; the final wording and any
remaining trade-offs are closed there.

1. **Whitespace-only `q` = all notes.** The request leaves it to the spec; an
   all-whitespace query is an empty search, not a client error. The UI sends a
   trimmed value, so the endpoint stays forgiving and needs no second error path.
2. **Text-only search.** No title field is introduced; search operates on
   `Note.Text`.
3. **Feature copy is Russian.** Existing `Add`/`Logout` may stay as documented
   DS terms; the new search surface ("Поиск заметок", "Ничего не найдено") is
   Russian.
4. **Stable test hooks.** The request names `data-testid` for the search field
   and the empty state; the draft fixes `notes-search` and `notes-search-empty`
   and adds `notes-search-clear` for the clear control.
5. **No `q` from the UI in the feature path (proposal).** The screen already
   holds the full owner-scoped list, so the UI filters it in memory; the
   `GET /api/notes?q=` contract is implemented and tested independently for
   non-UI clients. Architect to confirm at s02/s05.
6. **Search empty state vs zero notes (open).** Distinguish "no match for a
   query" from "the user has no notes"; the exact precedence is left to
   s05/s06.

## 6. Draft API contract

`GET /api/notes?q=<text>`

| Condition | Result |
|---|---|
| No / invalid bearer token | `401` |
| No `q` parameter | `200`, all notes of the current user |
| `q=` (empty after trim) | `200`, all notes of the current user |
| `q` contains only whitespace | `200`, all notes of the current user |
| `q` non-empty | `200`, current user's notes whose `text` contains `q`, case-insensitive |
| `q` longer than 512 bytes | `400 {"error":"query too long"}`, before any note scan |
| No matches | `200 []` (never `null`) |
| Other methods on `/api/notes` | unchanged (`405` with `Allow`) |

Search semantics (draft):

- Case-insensitive substring match over note text.
- Owner predicate is applied before the text predicate.
- `q` is decoded by `net/http`; URL-encoded and special characters must work
  without panics.
- The 512-byte cap is a byte limit on the decoded value, before scanning.
- Stored note text is not modified.

## 7. UX requirements (draft)

- The notes screen gains a labelled search input above the list.
- Typing filters the rendered list client-side against the notes already loaded
  for the signed-in user; clearing restores the full list.
- When the trimmed query is non-empty and has no matches, the list region shows
  "Ничего не найдено" with `data-testid="notes-search-empty"`.
- Search input `data-testid="notes-search"`; clear control
  `data-testid="notes-search-clear"`.
- The search empty state replaces only the list region; the input and the
  create form stay usable.
- Note text is rendered with `textContent`, never `innerHTML`.
- The query is in-memory only for the draft; whether it survives reload, and how
  it behaves offline, are open decisions for s05/s06.
- Layout order (search vs composer) follows the current app and DS; the exact
  order is confirmed in design (`s03`).

## 8. Acceptance criteria (draft)

1. Backend tests cover: find, not found, foreign notes invisible, `401`,
   empty/whitespace `q`, over-long `q`, URL-encoding and special characters.
2. `GOWORK=off go build ./...`, `go vet ./...`, `go test ./...` are green from
   the repository root (single Go module).
3. UI search filters and clears correctly; the search empty state appears only
   for a non-empty query with no matches.
4. Playwright E2E on `test2` passes all requested scenarios, including user B
   isolation; `pngdiff` is OK.
5. UI graph is actualised from code at `s21`.
6. `s22a` UI audit, `s22b`/`s22c` independent reviews, and `s24` owner approval
   pass.

## 9. Assumptions and open questions (for s02/s05/s06)

- **Zero notes + non-empty query:** base "no notes" state wins, or show the
  search empty state? (product preference: base empty state wins).
- **Query persistence across reload:** not persisted by default; confirm.
- **Offline:** show only notes already loaded in memory; confirm the exact
  banner/copy.
- **Result count:** show "Найдено N" only for an active query, or always?
- **Layout order:** search above the list, but composer vs search order follows
  the current app/DS.
- **Client-side filter vs server `q`:** proposal in §5.5; architect to confirm.

## 10. Traceability to the raw request

- Items 1–11 (process/constraints) → execution settings: entry `default`,
  platform `web`, profile `full`, branch `dev/path10-runner-11`, skips
  `s45`/`s46`, no prod/main/stage, no rework of `f-v3-auth-notes`/`E4312`/
  `E1320`.
- Items 12–23 (backend) → §3 U01 and §6 draft API contract.
- Items 24–30 (web UI) → §3 U02 and §7 UX requirements.
- Items 31–40 (deploy/E2E) → §3 U03 and §8 acceptance criteria.
- Items 41–45 (constraints) → §4 out of scope.

All 45 items are accounted for; none is dropped or widened.

## 11. Handoff to s02.architect_scope_analysis

Architect input: this draft brief plus the immutable request. Please confirm or
revise the §5 proposals and close the §9 open questions in the scope report and
`expertise-report.md`; the final brief is produced at `s06`.
