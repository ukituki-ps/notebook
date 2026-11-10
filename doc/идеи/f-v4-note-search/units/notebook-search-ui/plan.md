# Unit plan — notebook-search-ui (U02)

- unit_id: notebook-search-ui · domain: notebook-web · sde: sde-frontend
- change_class: plain · brief: T0102/brief.md · parent: `E6636-s20.sde_5fexecution-u02` (historical origin: E0809 s20 U02)
- files (4): web/index.html, web/app.js, web/app.css, web_ui_test.go
- base: `1722a1e51b3734284c6a9103a4ed2e5ab5793386`; branch `orc-exec-E6636-s20.sde_5fexecution-u02`

## Goal

Keep the notes-search UI on Notebook DS 1.0.1 only and keep
`TestUISemantics` truthful and green (R-1 closed). At this base the UI is
already present, so the unit is **verify-only** (fix drift only).

## Tasks (порядок)

1. **T0005** — `web/index.html`, `web/app.css`: search markup/testids/labels;
   `notes-search-count` ("Найдено N", `aria-live="polite"`, hidden for an empty
   query); `notes-search-clear` visible "Очистить" + aria-label; final
   `notes-search-empty` copy; `notes-loading` `role="status"`; composer →
   search → list order kept.
2. **T0006** — `web/app.js`: single `renderNotes()` re-applies the filter after
   load/create/delete; count/clear driven from that render; `notes-empty` wins
   at zero notes; query in-memory only (drop `sessionStorage`, clear on
   login/logout/401/reload); `textContent` only (no `innerHTML`).
3. **T0007** — `web/index.html`, `web/app.js`, `web/app.css`: count; retry
   `notes-retry` "Повторить" wired to `loadNotes` (loading/401/query re-apply);
   offline `notes-offline` + `notes-offline-check` "Проверить сеть" +
   offline-zero (no cache/false search-empty); search disabled at zero notes
   and in loading/error/offline; Delete visible "Удалить" + per-row
   `aria-label="Удалить заметку #N"` (Add/Logout English); 390 stacked /
   1200 inline, no horizontal overflow.
4. **T0008** — R-1 / DS token in `web/app.css`, `web_ui_test.go`: the base
   already uses `min-height: var(--control-height)` (44px) and the oracle
   asserts the token form (`web_ui_test.go:359-372`); keep it that way without
   editing `design/**`; oracle already covers count/retry/offline testids.

## Oracles

`TestUISemantics` (green) and `INV-UI-LABEL`, `INV-UI-A11Y-NAME`,
`INV-XSS-ESCAPE`, `INV-SEARCH-UI-FILTER`, `INV-SEARCH-UI-EMPTY`,
`INV-SEARCH-UI-TESTIDS`; `python3 tools/ui-audit-check.py --platform web`.

## Order

T0005 → T0006 → T0007 → T0008: markup/testids, then the single filter/render
path, then count/retry/offline states, then the R-1 oracle alignment.

## DoD

- `go test -count=1 ./...` green including `TestUISemantics`; R-1 closed.
- DS-only: Notebook DS 1.0.1, 12 registry components, 0 local instances, no
  local CSS; no `design/**` edit, pinned digest unchanged.
- 390/1200 no horizontal overflow; `git diff` limited to the four files for
  code; process artifacts committed per execution.

## Out of scope

`main.go`/`main_test.go`, `web/e2e/*.spec.js`, auth/session/persistence, new
dependency/bundler/CDN, redesign or layout-order change (AOD-7), `design/**`.
