# s01 — Product discuss: f-v4-note-search

- Execution: **E6588** · step **s01.product_discuss** · role **product**
- Process: `path-1.feature@4.0.0`, entry `default`, platform `web`, profile `full`
- A/B arm: `path-10`, key `notebook-path10-08`
- Base: `9e7fae353c61e717505dc40019627a1d7ab48820` · work branch: `dev/path10-runner-06`
- Feature: `f-v4-note-search` · feature dir: `doc/идеи/f-v4-note-search`
- Source: `feature-request.md` (raw, immutable, 45 items) — nothing beyond the
  request is added.

## Problem

The notes screen lists every note of the signed-in user. As the list grows there
is no way to find a note by text without scanning the whole list, and
`GET /api/notes` has no filter.

## User goal

A signed-in user types a text fragment, sees only their own notes containing it
(case-insensitive), clears the field to restore the full list, and gets a clear
"ничего не найдено" state when nothing matches — with auth, storage, and
create/delete behaviour unchanged.

## Draft feature brief

The draft brief for this step is `feature-brief.md` in this feature directory.
It already carries the scope, API contract, UX and acceptance criteria derived
from the raw request and is confirmed unchanged by this discussion (see the
reality check below). This step does not fork a second brief.

## In scope

- `GET /api/notes?q=<text>`: absent/empty/whitespace `q` → all own notes;
  non-empty `q` → own notes whose `text` contains it, case-insensitive; owner
  scoping always applied; `401` without bearer; `[]` (never `null`) on no match;
  512-byte `q` cap → `400` before scanning.
- Notes view: labelled search input and clear control, client-side filtering of
  the loaded list, search-only empty state with stable `data-testid`s; the
  active query is re-applied after create/delete/reload.
- Go tests, Playwright E2E on `test2`, UI graph actualization, `pngdiff` OK.

## Out of scope

Auth/session/storage changes; pagination, sorting, ranking, fuzzy matching,
highlighting; cross-user search; prod/main/stage deploy and canary; reworking
`f-v3-auth-notes`, `E4312`, `E1320`; title search — the model has only
`Note.Text`, so the step prompt's "title/body" wording is read as text-only.

## Product decisions (closed at s01)

- **Whitespace-only `q` → all notes.** The UI sends the trimmed input; an
  all-whitespace query is an empty search, not a client error. No second error
  path for the UI to special-case.
- **"Title/body" wording → text only.** The model is `Note{ID, UserID, Text}`
  (`main.go:67`); there is no title or body field, so search is over `Text` only.
- **Server `q` and UI filter are two contracts.** The API implements and tests
  `q`; the web view filters the already owner-scoped list client-side so there
  is no request per keystroke and one source of truth.
- **`q` is capped at 512 decoded bytes → `400` before scanning.** A
  multi-megabyte query must not force a full scan; the cap is a byte limit.
- **No match → `200 []`, never `null`.** Stable JSON shape for clients.
- **Query is in-memory only.** Not persisted across reload or in URL/hash;
  cleared on login/logout/401.
- **Empty-state precedence.** When the collection itself has zero notes the
  base `notes-empty` state wins; the search-only empty state is for an active
  query over a non-empty collection.

## Reality check against the base code

Confirmed at base `9e7fae3` (s01 makes no code change; this is a product-to-code
consistency check):

- `GET /api/notes` applies auth first, then owner-scoped `ListNotes`, then the
  case-insensitive substring filter on the owner-scoped slice
  (`main.go:530`, `main.go:547-556`). A query can narrow but never widen the
  scope.
- `maxQueryBytes = 512` is enforced on the decoded `q` before `ListNotes`
  (`main.go:33`, `main.go:541-544`).
- The notes view already exposes `data-testid` hooks: `notes-search`,
  `notes-search-clear`, `notes-search-count`, `notes-empty`,
  `notes-search-empty` (`web/index.html:79-106`; `web/app.js:309-312`).
- UI filtering, clear, empty-state precedence, and re-apply after
  create/delete/reload match the decisions above (`web/app.js:443-480`).

The draft brief `feature-brief.md` is reconciled with the above and with all 45
raw request items; no drift was found. Execution-context note: the raw request
names `dev/f-v4-note-search`, while this execution's work branch is
`dev/path10-runner-06` from the execution context; this is a process/branch fact
and does not change product scope.

## Open questions

None blocking. The raw request leaves whitespace-only `q` to the spec; decided
as "all notes" and reflected in the draft brief and API contract. The 512-byte
cap and the text-only model are stated explicitly.

## Handoff to s02 (architect scope analysis)

Draft scope: notebook-api (`GET /api/notes?q=`), notebooks-web (search input,
client-side filter, clear, search-empty), tests (Go + Playwright), UI graph and
`test2` preview. No auth, persistence, or lifecycle change; `change_class`
stays `plain`. Open questions: none blocking.
