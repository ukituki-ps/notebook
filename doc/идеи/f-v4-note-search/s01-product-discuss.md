# s01 — Product discuss: f-v4-note-search (E4138)

- Execution: **E4138** · step **s01.product_discuss** · role **product**
- Process: `path-1.feature@4.0.0`, entry point `default`, platform `web`,
  feature_profile `full`
- Work branch: `dev/path10-runner-12` · base: `9e7fae353c61e717505dc40019627a1d7ab48820`
- Input: `feature-request.md` (raw, immutable — 45 numbered items)
- Output of the step: draft feature brief at `feature-brief.md`

Baseline note: this worktree already carries the brief and implementation of an
earlier execution of the same feature. s01 therefore **confirms** the existing
draft against the raw request instead of re-authoring or regressing it; no
in-scope item is dropped and no out-of-scope item is added.

## Problem

The notes screen lists every note of the signed-in user. As the list grows there
is no way to find a note by text except scanning the whole list, and the notes
API has no text filter.

## User goal

A signed-in user types a text fragment, sees only their own notes containing it
(case-insensitive), clears the field to restore the full list, and gets a clear
"ничего не найдено" state when nothing matches — with auth, storage, and
create/delete behaviour unchanged.

## In scope (mapped to raw request items)

- **U01 backend (items 12–23):** `GET /api/notes?q=<text>`; absent/empty
  `q` → all own notes; non-empty `q` → own notes whose `text` contains it
  case-insensitively; owner scoping always applied; `401` without bearer;
  URL-encoded and special characters handled; tests for find, not-found,
  foreign-note isolation, `401`, encoding.
- **U02 web UI (items 24–30):** labelled search field, list filtering, clear
  restores the full list, "ничего не найдено" empty state, stable `data-testid`s
  for the field and the empty state, create/delete/reload keep working, UI graph
  actualized.
- **U03 deploy/E2E (items 31–40):** preview on `test2`; Playwright 1.64.1 E2E
  for login, create 2 notes, find one, find nothing, clear restores both, user B
  isolation; `pngdiff` OK.
- **Process constraints (items 1–11, 41–45):** keep auth/persistence semantics;
  no unrelated refactors; do not touch `f-v3-auth-notes`, `E4312`, `E1320`;
  prod/main/stage and canary out of scope.

## Product decisions taken at s01

1. **Whitespace-only `q` → all notes** (closes raw request item 18). An
   all-whitespace query is an empty search, not a client error; no second error
   path for the UI to special-case. Absent, empty, and whitespace-only `q` are
   identical.
2. **No title search.** The note model has only `Note.Text`; the step wording
   "title/body" is read as text-only. Adding a title field would be a data-model
   change and is out of scope.
3. **Search narrows, never widens.** The owner predicate is applied first, the
   text predicate second, so a query can never expose another user's notes.
4. **Both halves of the request stand.** The API filter (U01) and the web-view
   filter (U02) are both required; the exact client-vs-server split for the UI
   path is an architecture decision for s02, not a product scope change.
5. **No persistence change.** Notes stay in memory; auth, sessions, and
   create/delete/reload semantics are unchanged (items 41, 27, 28).

## Out of scope

Registration/login/session/token changes; persistence or schema changes;
pagination, sorting, ranking, fuzzy matching, highlighting; cross-user search;
prod/main/stage deploy and canary rollout; reworking `f-v3-auth-notes`, `E4312`,
or `E1320`; changing create/delete/reload behaviour.

## Draft feature brief

- Path: `doc/идеи/f-v4-note-search/feature-brief.md`
- sha256 (at s01 confirmation):
  `5ae2956b3102db43d789db9abb2ccfdf54f306a23736adb4f86781176f7ac801`
- Coverage check: all 45 raw items map to the brief — U01 → "API contract" and
  "Acceptance criteria 1–2"; U02 → "UX" and "Acceptance criteria 3, 5"; U03 →
  "In scope", "Acceptance criteria 4", "Risks"; constraints → "Don't" and
  "Out of scope". Item 18 is closed by decision 1 above.

## Open questions

None blocking. Item 18 (whitespace-only `q`) was the only open point in the raw
request and is decided above ("all notes"); it is already reflected in the brief
and the API contract table.
