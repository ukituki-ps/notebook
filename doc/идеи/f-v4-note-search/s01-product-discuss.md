# s01 — Product discuss & draft feature brief: f-v4-note-search

- Execution: **E5716** · step **s01.product_discuss** (role `product`)
- Process: `path-1.feature` **4.0.0** (entry `default`, platform `web`, profile `full`)
- Feature: `f-v4-note-search` · dir `doc/идеи/f-v4-note-search`
- Base SHA: `9e7fae353c61e717505dc40019627a1d7ab48820` · work branch `dev/path10-runner-10`
- Idea source: `feature-request.md` (raw, immutable, 45 items). Scope is owner-scoped
  note search only; nothing beyond the request is added.

This is the **draft feature brief** produced by the s01 product discussion. It
seeds `feature-brief.md`, which is finalized later at s06.

## Problem

The notes screen lists every note of the signed-in user. As the list grows there
is no way to find a note by text except scanning the whole list, and
`GET /api/notes` has no filter.

## Users and goal

A signed-in user types a text fragment, sees only their own notes containing it
(case-insensitive), clears the field to restore the full list, and gets a clear
"ничего не найдено" state when nothing matches — with auth, storage, and
create/delete behaviour unchanged.

## In scope

- `GET /api/notes?q=<text>`: absent/empty/whitespace `q` → all own notes;
  non-empty `q` → own notes whose `text` contains it, case-insensitive; owner
  scoping always applied; `401` without bearer; `[]` (never `null`) on no match;
  512-byte `q` cap → `400` before scanning.
- Notes view: labelled search input and clear control, client-side filtering of
  the loaded list, search-only empty state with stable `data-testid`s; the active
  query is re-applied after create/delete/reload.
- Go tests, Playwright E2E on `test2`, UI graph actualization, `pngdiff` OK.

## Draft API contract

| case | `q` | result |
|---|---|---|
| no filter | absent / empty / whitespace-only | `200` — all notes of the caller |
| match | non-empty, substring of note text | `200` — own matching notes, case-insensitive |
| no match | non-empty, no substring | `200 []` (`[]`, never `null`) |
| too long | decoded length > 512 bytes | `400 {"error":"query too long"}` before scanning |
| unauthenticated | any | `401` before query handling |

Owner predicate is applied before the text predicate: `q` narrows, never widens,
the result set. Wire shape stays `{id, text}`; `UserID` is never exposed.

## Draft UI contract

- Search input `data-testid="notes-search"` with a label and a clear control
  `data-testid="notes-search-clear"`.
- Client-side filtering of the already loaded owner-scoped list (no request per
  keystroke); clearing restores the full list.
- Search empty state `data-testid="notes-search-empty"` with "ничего не найдено";
  it applies only to a non-empty query over a non-empty collection.
- Create/delete/reload keep working and re-apply the active query.

## Draft acceptance criteria (trace to request items)

- Backend: search finds a note; does not find an absent note; never returns
  another user's notes; `401` without bearer; URL-encoding/special characters
  handled (items 12–23).
- UI: search field, filtering, clearing restores the list, "ничего не найдено",
  create/delete/reload intact, stable `data-testid`s, UI graph actualized
  (items 24–30).
- Deploy/E2E: preview on `test2`; Playwright 1.64.1 scenarios for login, create 2
  notes, find one, find nothing, clear restores both, user-B isolation; `pngdiff`
  OK (items 31–40).

## Out of scope

Auth/session/storage changes; pagination, sorting, ranking, fuzzy matching,
highlighting; cross-user search; prod/main/stage deploy and canary; reworking
`f-v3-auth-notes`, `E4312`, `E1320`; title search — the model has only
`Note.Text`, so the step prompt's "title/body" wording is read as text-only.

## Decisions and open questions

- None blocking. The request leaves whitespace-only `q` to the spec; decided as
  "all notes" and reflected in the brief and API contract.
- Search is text-only (no title field exists); matching is case-insensitive
  substring over note text.
- Preview is allowed only on `test2`; prod/main/stage and canary are out of
  scope.
