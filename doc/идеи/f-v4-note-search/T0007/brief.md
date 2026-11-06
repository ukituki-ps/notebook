# T0007 — UI semantics tests (s16 task brief)

- Unit: `notebook-search-ui`
- Domain: `notebook-web`
- SDE: `sde-frontend`
- Change class: `plain`
- Files: `web_ui_test.go`

## Scope

1. Extend `TestUISemantics` to assert the search testids `notes-search`,
   `notes-search-clear`, `notes-search-empty`, alongside the existing contract
   ids.
2. Assert the search input has a visible `label for`, `type="search"`,
   `aria-controls="notes-list"`, and appears above the list; the clear control
   is a `type="button"` with an accessible name and starts hidden; the search
   empty state has `role="status"`, `aria-live="polite"`, starts hidden, and
   carries the required copy.
3. Assert `app.js` exposes a single `renderNotes()` path (re-applied after
   load/create/delete), the filter primitives (`toLowerCase`, `filter`,
   `indexOf`, `searchQuery`), the full empty-state guard (`hasQuery`, non-empty
   collection, zero visible), and that the list renders API response data with
   no hardcoded/phantom notes.
4. Preserve the existing auth, loading, error, 401, register-validation and CSS
   assertions; do not weaken the f-v3 oracle.

## Acceptance oracles

- `go test -count=1 -run TestUISemantics ./...`
- `go test -count=1 ./...`
- Invariants: `INV-UI-TRUTH`, `INV-UI-LABEL`, `INV-UI-A11Y-NAME`,
  `INV-SEARCH-UI-FILTER`, `INV-SEARCH-UI-EMPTY`, `INV-SEARCH-UI-TESTIDS`.

## Forbidden

Deleting or relaxing existing auth/UI assertions; asserting a search empty state
for an empty server list; replacing API-driven assertions with hardcoded
fixtures; build tags; testing implementation details that contradict
`spec/core.md`.
