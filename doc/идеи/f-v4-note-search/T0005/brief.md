# T0005 — search markup and testids (s16 task brief)

- Unit: `notebook-search-ui`
- Domain: `notebook-web`
- SDE: `sde-frontend`
- Change class: `plain`
- Files: `web/index.html`, `web/app.css`

## Scope

1. Add a labelled search input on the notes screen: `data-testid="notes-search"`,
   `id="notes-search"`, `type="search"`, `aria-controls="notes-list"`, visible
   `<label for="notes-search">` (`Поиск заметок`), inside a `role="search"`
   container above `notes-list`.
2. Add a separate clear control `data-testid="notes-search-clear"`,
   `type="button"`, accessible name (`aria-label="Очистить поиск"`), hidden
   while the raw query is empty.
3. Add a search empty state `data-testid="notes-search-empty"`,
   `role="status"`, `aria-live="polite"`, hidden by default, copy
   `Ничего не найдено.`; keep the base `notes-empty` element separate.
4. Place the search controls above the list and add CSS for the search row,
   clear control, and search empty state (flex row, full-width input, touch
   target, wrapping at narrow widths).
5. Markup/style only; filtering and show/hide behaviour belong to T0006.

## Acceptance oracles

- `go test -count=1 -run TestUISemantics ./...` (testids, label, `type=search`,
  `aria-controls`, default-hidden states).
- Existing auth/notes markup and loading/error/401 elements unchanged.
- Browser rendering exercised by T0006 and `SEARCH-E2E-1..6` at s20c.

## Forbidden

Changing `notes-empty` semantics for a genuinely empty server list; hardcoded
notes; adding JS behaviour in this task; frameworks/builders/runtime npm UI;
changing existing f-v3 auth markup or testids.
