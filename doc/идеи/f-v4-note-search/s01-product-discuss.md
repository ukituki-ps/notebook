# s01 — Product discuss: f-v4-note-search

- **Execution:** E4633 (path-10 A/B arm, key `notebook-path10-07`)
- **Process:** `path-1.feature` 4.0.0, entry `default`, platform `web`, profile `full`
- **Base:** `9e7fae353c61e717505dc40019627a1d7ab48820` · **Work branch:** `dev/path10-runner-05`
- **Input:** `feature-request.md` (raw, immutable, 45 items) — nothing beyond the
  request is added.

## Problem

The notes screen lists every note of the signed-in user. As the list grows there
is no way to find a note by text except scanning the whole list, and
`GET /api/notes` has no filter.

## User goal

A signed-in user types a text fragment, sees only their own notes containing it
(case-insensitive), clears the field to restore the full list, and gets a clear
"ничего не найдено" state when nothing matches — with auth, storage, and
create/delete behaviour unchanged.

## Draft feature brief

The draft brief for this execution is `feature-brief.md`. It already carries the
scope, API contract, UX and acceptance criteria derived from the raw request and
is confirmed unchanged by this discussion (see reality check below). This step
does not fork a second brief.

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

## Reality check (product discussion)

The discussion checked the existing worktree against the draft contract; no
divergence was found, so no brief edit is warranted:

- `main.go` (`handleNotes`): reads `q`, rejects more than `maxQueryBytes`
  (512) with `400 "query too long"` before `ListNotes`, trims and lower-cases
  the query, applies the owner-scoped list first and only then the substring
  filter; `writeJSON` emits `[]`, not `null`.
- `web/app.js`: `filterNotes` trims/lower-cases and filters the loaded
  owner-scoped list; `renderNotes` re-applies the query after create/delete/
  reload; clear restores the full list; the count is shown only for a non-empty
  query; the search-empty state is list-only.
- `web/index.html`: `notes-search`, `notes-search-clear`, `notes-search-count`
  and `notes-search-empty` `data-testid`s are present with a visible label and
  `role="search"`.

## Open questions

None blocking. The raw request leaves whitespace-only `q` to the spec; decided
as "all notes" and reflected in the draft brief and API contract. The 512-byte
cap and the text-only model are stated explicitly in the brief.

## Handoff to s02 (architect scope analysis)

Draft scope: notebook-api (`GET /api/notes?q=`), notebooks-web (search input,
client-side filter, clear, search-empty), tests (Go + Playwright), UI graph and
`test2` preview. No auth, persistence, or lifecycle change; `change_class`
stays `plain`.
