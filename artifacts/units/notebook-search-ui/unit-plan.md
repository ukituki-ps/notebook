# Unit plan — notebook-search-ui (U02, E6636 s10)

- **Unit:** `notebook-search-ui` · domain `notebook-web` · `sde-frontend` · `plain`
- **Execution:** `E6636-s20.sde_5fexecution-u02` · branch `orc-exec-E6636-s20.sde_5fexecution-u02`
- **Base:** `1722a1e51b3734284c6a9103a4ed2e5ab5793386`
- **Brief:** `doc/идеи/f-v4-note-search/T0102/brief.md`
- **Files (4):** `web/index.html`, `web/app.js`, `web/app.css`, `web_ui_test.go`
- **DS:** Notebook DS **1.0.1** (`ds/v1.0.1`, digest `4e0ef105…c85e`),
  12 registry components, 0 local instances, no local CSS
- **Mode:** verify against `spec/core.md` §3.2–§3.5 and fix drift only — at base
  the UI already carries the search elements; no redesign, no DS edit.

## Goal

Keep the notes-search UI on Notebook DS 1.0.1 truthful: count, retry,
offline/offline-zero, zero-note disable, localized Delete, in-memory query,
single `renderNotes()` path, 390/1200 behaviour; keep `TestUISemantics` green
(R-1 stays closed at base).

## Scope (8)

1. count `Найдено N` (`notes-search-count`, `aria-live="polite"`) only for a
   non-empty query.
2. retry `Повторить` (`notes-retry`) wired to `loadNotes`.
3. offline banner + check + offline-zero.
4. zero notes: base `notes-empty` wins, search disabled.
5. Delete `Удалить` + `aria-label="Удалить заметку #N"`; Add/Logout English.
6. query in-memory only, single `renderNotes()` re-apply.
7. R-1 stays fixed on the `--control-height` token.
8. DS 1.0.1 only, GAP-1..GAP-4, 390/1200.

## Tasks (order)

1. **T0005 — markup, testids, labels, order** (`web/index.html`, `web/app.css`).
   Search field `notes-search` (`type="search"`, label «Поиск заметок»,
   placeholder «Поиск по тексту...», `aria-controls="notes-list"`) inside
   `role="search"`; clear `notes-search-clear` visible «Очистить»,
   `aria-label="Очистить поиск"`, hidden on an empty trimmed query; count
   `notes-search-count`; search-empty exact copy «Ничего не найдено. Сократите
   запрос или очистите поиск.» (`role="status"`, `aria-live="polite"`); base
   `notes-empty` «Пока нет заметок. Добавьте первую выше.»; delete row
   `delete-note` visible «Удалить» (Add/Logout English); composer → search →
   list order (AOD-7). No phantom `note-item` rows.
   Oracle: `TestUISemantics`, `INV-UI-LABEL`, `INV-UI-A11Y-NAME`,
   `INV-SEARCH-UI-TESTIDS`.

2. **T0006 — filter / single render path** (`web/app.js`). Client-side filter
   over the loaded owner-scoped list, no per-keystroke request, no `q`
   round-trip; one `renderNotes()` re-applies the active query after load,
   create, delete and reload; query in-memory only (no `sessionStorage`
   restore/write; `SEARCH_KEY` only removed on login/logout/401/clear); clear
   on reload; `textContent` only (no `innerHTML`); count/clear driven from that
   render; zero-notes precedence (`notes-empty` wins, `notes-search-empty`
   hidden).
   Oracle: `TestUISemantics`, `INV-SEARCH-UI-FILTER`, `INV-SEARCH-UI-EMPTY`,
   `INV-XSS-ESCAPE`.

3. **T0007 — count / retry / offline / delete** (`web/index.html`,
   `web/app.js`, `web/app.css`). Count visible only for a non-empty trimmed
   query (incl. `Найдено 0`) and hidden when empty; retry `notes-retry`
   «Повторить» wired to `loadNotes` (normal load path, 401 handling, active-query
   re-apply); offline `notes-offline` driven by `navigator.onLine` + loaded
   notes, `notes-offline-check` «Проверить сеть» re-runs `loadNotes`, offline-zero
   is distinct from search-empty (no cache/false search-empty); search disabled
   at zero notes, in loading, error and offline, enabled for a non-empty
   collection (`aria-disabled` + `aria-describedby` on the live node); per-row
   Delete `aria-label="Удалить заметку #N"`; 390 stacked / 1200 inline, no
   horizontal overflow.
   Oracle: `TestUISemantics`, `INV-UI-LABEL`, `INV-UI-A11Y-NAME`,
   `INV-SEARCH-UI-EMPTY`.

4. **T0008 — R-1 / DS token + oracle** (`web/app.css`, `web_ui_test.go`).
   Keep `--control-height: 44px` (`web/app.css:14`) and `min-height:
   var(--control-height)`; `TestUISemantics` asserts the token form, not a
   literal-only `min-height: 44px`; oracle already covers
   `notes-search-count`, `notes-retry`, `notes-offline`,
   `notes-offline-check`. No `design/**` edit, pinned digest unchanged; accept
   additive test extensions only where a clause above is not yet pinned.
   Oracle: `go test -count=1 ./...` green incl. `TestUISemantics`;
   `python3 tools/ui-audit-check.py --platform web` 0 DS violations.

## Oracles

`TestUISemantics` (green) and `INV-UI-TRUTH`, `INV-UI-LABEL`,
`INV-UI-A11Y-NAME`, `INV-XSS-ESCAPE`, `INV-SEARCH-UI-FILTER`,
`INV-SEARCH-UI-EMPTY`, `INV-SEARCH-UI-TESTIDS`;
`python3 tools/ui-audit-check.py --platform web`.

## Order

T0005 → T0006 → T0007 → T0008: markup/testids, then the single filter/render
path, then count/retry/offline/delete, then the R-1/DS-token oracle check.

## DoD

- `GOWORK=off go build ./...` and `go test -count=1 ./...` green including
  `TestUISemantics`; R-1 stays closed (token form, no literal-only oracle).
- DS-only: Notebook DS 1.0.1, 12 registry components, 0 local instances, no
  local CSS; path6 GAP-1 (`n-count`), GAP-3 (`n-delete`), GAP-2 (input disabled
  state), GAP-4 (utility-class registry) accepted/non-blocking; no `design/**`
  edit and no fingerprint change.
- 390/1200 no horizontal overflow; `git diff` limited to the four files.

## Out of scope

`main.go`/`main_test.go`, `web/e2e/*.spec.js`, deploy/scenarios, auth/session/
persistence, new dependency/bundler/CDN, redesign or layout-order change
(AOD-7), `design/**`.

## Context

- Source: `orc_ctx` (planner profile, `token_budget` 20000, estimate ≈5780).
- Grounding: `spec/core.md` §3.2–§3.6, `T0102/brief.md`, `plan.md` §U02,
  `units/note-search/state-matrix.md` (8 renderable states).
