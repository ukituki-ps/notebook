# Unit plan — notebook-search-ui (f-v4-note-search)

Scope: `web/index.html`, `web/app.js`, `web/app.css`, `web_ui_test.go`.
No API/backend/deploy/e2e changes, no new dependencies.

1. **HTML** — add a labeled search field (`data-testid="notes-search"`,
   `type="search"`, `aria-controls="notes-list"`) above the notes list, a
   `notes-search-clear` button (aria-label, starts hidden), and a
   `notes-search-empty` status region (`role="status"`, `aria-live="polite"`,
   hidden by default).
2. **JS** — keep the loaded collection in `notes` and the active query in
   `searchQuery`. One `renderNotes()` filters case-insensitively over
   title/text, rebuilds the list, and toggles `notes-empty` (collection empty)
   vs `notes-search-empty` (non-empty query filtered everything out).
   Load, create, delete and reload all call `renderNotes()`; the query is
   persisted in sessionStorage so a browser reload restores it.
3. **CSS** — search row and clear button styling consistent with existing
   controls; stack full-width at the existing 640px breakpoint.
4. **Tests** — extend `TestUISemantics` with testids, label/aria, DOM ordering,
   empty-state semantics, single-render, and API-data assertions; keep every
   pre-existing assertion.
5. **Verification** — `go build ./...`, `go vet ./...`,
   `go test -count=1 ./...` from the worktree root.
