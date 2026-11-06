# T0006 — filter, clear, and empty-state logic (s16 task brief)

- Unit: `notebook-search-ui`
- Domain: `notebook-web`
- SDE: `sde-frontend`
- Change class: `plain`
- Files: `web/app.js`

## Scope

1. Implement one `filterNotes()` over the already loaded owner-scoped list:
   trim and lowercase the query, case-insensitive substring match, no request
   per keystroke, and no widening beyond the loaded list.
2. Drive the UI through one `renderNotes()` path so load, create, delete, and
   reload re-apply the active query; only that function appends note rows.
3. Wire the clear control to reset the query and input, restore the full list,
   remove the stored query, and return focus to the search input.
4. Show `notes-search-empty` only when the trimmed query is non-empty, the
   loaded collection is non-empty, and zero notes match; show `notes-empty`
   only for a genuinely empty server list.
5. Keep search controls disabled until the list is loaded; keep search usable
   after create/delete errors; preserve 401 redirect behaviour.
6. Treat `sessionStorage` `notebook.search` restore as an implementation
   convenience only (OD-6); do not make reload persistence contractual.

## Acceptance oracles

- `go test -count=1 -run TestUISemantics ./...`
- `SEARCH-E2E-1..6` at s20c (find, not-found, case, clear, create-active,
  delete-active).
- Existing create/delete/reload flows and auth/loading/error states unchanged.

## Forbidden

Server-side filtering per keystroke; changing `notes-empty` semantics; hiding
the create form or search input in the search-empty state; hardcoded notes;
frameworks/builders; making OD-6 persistence part of the contract.
