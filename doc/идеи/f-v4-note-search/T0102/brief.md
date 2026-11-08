---
unit_id: notebook-search-ui
domain: notebook-web
sde: sde-frontend
change_class: plain
scope:
  - "result count: notes-search-count 'Найдено N', aria-live=polite; visible only for a non-empty trimmed query (incl. 0), hidden when empty"
  - "retry: notes-retry 'Повторить' in the error state, wired to loadNotes (normal load path/401/query re-apply)"
  - "offline: notes-offline banner + notes-offline-check 'Проверить сеть' + offline-zero variant; no cache"
  - "zero notes: base notes-empty wins; search disabled at zero and in loading/error/offline"
  - "Delete visible 'Удалить' + aria-label 'Удалить заметку #N'; Add/Logout stay English"
  - "query in-memory only (no sessionStorage); final Russian copy; single renderNotes() re-applies after load/create/delete"
  - "R-1: fix TestUISemantics min-height vs DS token without editing design/**"
  - "DS-only path6 GAP-1/GAP-3/GAP-2; 390/1200 no overflow"
files:
  - web/index.html
  - web/app.js
  - web/app.css
  - web_ui_test.go
---
# T0102 — notebook-search-ui (U02)

## Goal

Finish the notes-search UI deltas on Notebook DS 1.0.0 only: count, retry,
offline/offline-zero, zero-note disable, localized Delete, in-memory query,
390/1200 behaviour; make `TestUISemantics` truthful and green.

## Task list

1. Add `notes-search-count` (`Найдено N`, `aria-live="polite"`): visible only
   for a non-empty trimmed query, including `Найдено 0`; hidden when empty.
2. Add `notes-retry` (`Повторить`) in the error state, wired to `loadNotes`;
   retry shows loading, handles 401 and re-applies the active query.
3. Add `notes-offline` (driven by `navigator.onLine` + loaded notes) with
   `notes-offline-check` (`Проверить сеть`) and an offline-zero variant; no
   false search-empty and no cache/persistence.
4. Zero-notes precedence: `notes-empty` wins, `notes-search-empty` stays hidden,
   search disabled when `notes.length == 0` (also disabled in loading/error/
   offline); enabled for a non-empty collection.
5. Delete: visible `Удалить`, per-row `aria-label="Удалить заметку #N"`;
   `Add`/`Logout` remain English (AOD-6).
6. Query is in-memory only: remove `sessionStorage["notebook.search"]`
   restore/write; clear on login/logout/401/reload (AOD-3); keep one
   `renderNotes()` re-applying the filter after load/create/delete; keep
   `textContent` rendering (no `innerHTML`).
7. Use the final copy: search empty `Ничего не найдено. Сократите запрос или
   очистите поиск.`; clear visible `Очистить`; keep composer-first order.
8. **R-1:** fix `web_ui_test.go:264` expecting literal `min-height: 44px` while
   `web/app.css` uses `min-height: var(--control-height)`. Align the oracle to
   the DS token (or add a DS-compliant 44px height); **do not edit `design/**`**.
   Extend the same oracle with count/retry/offline testids.
9. Verify 390px (stacked search row, full-width 44px controls) and 1200px
   (inline search + clear), no horizontal overflow.

## Oracles

`TestUISemantics` (green), `INV-UI-LABEL`, `INV-UI-A11Y-NAME`,
`INV-XSS-ESCAPE`, `INV-SEARCH-UI-FILTER`, `INV-SEARCH-UI-EMPTY`,
`INV-SEARCH-UI-TESTIDS`; `python3 tools/ui-audit-check.py --platform web`.
## DS constraints
Notebook DS 1.0.0 only (`ds/v1.0.0`): 12 registry components, 0 local instances,
no local CSS, no Kubiki, no `frontend/src/ui/kit`; path6 GAP-1 (`n-count`),
GAP-3 (`n-delete`), GAP-2 (input disabled) accepted/non-blocking; no
`design/**`/DS edit and no fingerprint change.
## Out of scope
`main.go`/`main_test.go`, E2E spec, auth/persistence, new dependency/bundler/CDN,
redesign or layout-order change (AOD-7).
## Acceptance
`go test ./...` green including `TestUISemantics` (R-1 resolved); all UI
invariants hold; 0 DS violations and 0 local instances; 390/1200 no overflow;
no `design/**` change.

## Evidence required

`go test -count=1 ./...` output; `ui-audit-check.py` result (0 violations);
the R-1 fix diff; 390/1200 screenshots or Playwright assertions; `git diff`
limited to the four files; proof `design/**` is untouched.
