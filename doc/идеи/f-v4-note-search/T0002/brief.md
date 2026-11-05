# T0002 — notebook-search-ui (s16 unit brief)

- Unit: `notebook-search-ui`
- Domain: `notebook-web`
- SDE: `sde-frontend`
- Change class: `plain`
- Files: `web/index.html`, `web/app.js`, `web/app.css`, `web_ui_test.go`

## Scope

1. Add a labelled search input `data-testid="notes-search"` on the notes screen.
2. Filter the already loaded owner-scoped notes list client-side (no request per
   keystroke); case-insensitive substring, trimmed query.
3. Add a clear control that restores the full list.
4. Add `data-testid="notes-search-empty"` with text "ничего не найдено", shown
   only when the trimmed query is non-empty and the filtered list is empty.
5. Keep create/delete/reload working; re-apply the active query after mutation.
6. Extend `TestUISemantics` for testids, label/accessibility, empty-state
   condition, no hardcoded notes.

## Acceptance oracles

- `go test -count=1 -run TestUISemantics ./...`
- Playwright search scenarios (s20c) green.
- Existing auth UI semantics unchanged.

## Forbidden

Frameworks/builders/npm UI runtime, auth changes, hardcoded notes, changing
`notes-empty` semantics for a genuinely empty server list.
