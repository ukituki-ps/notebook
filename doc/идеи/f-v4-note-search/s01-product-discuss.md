# s01 — Product discuss: f-v4-note-search

Source: `feature-request.md` (raw, immutable). Scope is owner-scoped note search only; nothing beyond the request is added.

Re-validated in execution `E6247` (`s01.product_discuss`, path-10, 2026-11-09) against
all 45 raw request items: the draft brief `feature-brief.md` (Problem, Goal,
In scope, Do/Don't, API contract, UX) still satisfies the request with no scope
change; this note carries the discussion record and the delivery constraints
below.

## Problem

The notes screen lists every note of the signed-in user. As the list grows there is no way to find a note by text except scanning the whole list, and `GET /api/notes` has no filter.

## User goal

A signed-in user types a text fragment, sees only their own notes containing it (case-insensitive), clears the field to restore the full list, and gets a clear "ничего не найдено" state when nothing matches — with auth, storage, and create/delete behaviour unchanged.

## In scope

- `GET /api/notes?q=<text>`: absent/empty/whitespace `q` → all own notes; non-empty `q` → own notes whose `text` contains it, case-insensitive; owner scoping always applied; `401` without bearer; `[]` (never `null`) on no match; 512-byte `q` cap → `400` before scanning.
- Notes view: labelled search input and clear control, client-side filtering of the loaded list, search-only empty state with stable `data-testid`s; the active query is re-applied after create/delete/reload.
- Go tests, Playwright E2E on `test2`, UI graph actualization, `pngdiff` OK.

## Out of scope

Auth/session/storage changes; pagination, sorting, ranking, fuzzy matching, highlighting; cross-user search; prod/main/stage deploy and canary; reworking `f-v3-auth-notes`, `E4312`, `E1320`; title search — the model has only `Note.Text`, so the step prompt's "title/body" wording is read as text-only.

## Delivery constraints (from the raw request)

- Playwright **1.64.1** is used for E2E (not 1.53); `package.json` and
  `package-lock.json` are not rolled back (items 38–39).
- Preview is allowed only on `test2` (items 31, 45); prod/main/stage deploy and
  canary are out of scope. `pngdiff` must be OK (item 40).
- `s45.push_primary` and `s46.post_deploy_verify` are skipped for this feature
  (item 5).
- Auth, sessions and persistence behaviour stay unchanged; create/delete/reload
  on the notes view must keep working (items 28, 41).
- No per-run artifacts are committed; evidence files stay out of the feature
  directory (item 10).

## Open questions

None blocking. The request leaves whitespace-only `q` to the spec; decided as "all notes" and reflected in the brief and API contract.
