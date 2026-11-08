# Execution report — notebook-search-ui (U02, s11.unit_execution)

- Execution: `E0809-s20.sde_5fexecution-u02`
- Unit: `notebook-search-ui` (domain `notebook-web`, role `sde-frontend`)
- Branch: `orc-exec-E0809-s20.sde_5fexecution-u02`
- Base: `ad51b9f` (`docs(u02): unit plan notebook-search-ui`)
- Change class: plain · brief `T0102/brief.md` · plan `units/notebook-search-ui/plan.md`
- Not committed: coordinator commits.

## Files

| File | Change |
|---|---|
| `web/index.html` | count/retry/offline/offline-check markup; loading `role="status"` + `aria-live`; list `aria-busy`; final Russian copy; visible `Очистить`/`Удалить`; offline banner composed from DS `.note-item` + `.muted` + `primitives/button`. |
| `web/app.js` | single `renderNotes(query)`; in-memory query (no read/write of `sessionStorage["notebook.search"]`, legacy key removed only); count/clear/empty/disabled state; retry wired to `loadNotes`; offline/online listeners, offline-zero text and `Проверить сеть`; `navigator.onLine`-driven search disable; Delete keeps per-row `aria-label`. |
| `web_ui_test.go` | R-1 aligned: oracle now requires `min-height: var(--control-height)` plus `--control-height: 44px` (still exactly 44px); added `notes-search-count`/`notes-retry`/`notes-offline`/`notes-offline-check`; added count/retry/offline/loading/aria-busy/copy/in-memory/disabled assertions. No pre-existing assertion deleted or weakened. |
| `web/app.css` | **Unchanged (inspected).** Existing DS rules cover all new elements (`button` 44px/3px focus, `.note-item`, `.muted`, `.notes-search-row`, `@media (max-width:640px)`); no local CSS added. |

No `design/**`, `main.go`, `main_test.go`, or `web/e2e/**` changes.

## Requirement mapping

1. **Count** — `notes-search-count`, `aria-live="polite"`, text `Найдено N`; hidden when trimmed query empty, zero notes, or loading/error/offline; visible for a non-empty query including `Найдено 0`.
2. **Retry** — `notes-retry` (`Повторить`, `type=button`, hidden by default) shown in the load error state; calls `loadNotes` (loading, 401, active-query re-apply). Error copy `Не удалось загрузить заметки. Попробуйте ещё раз.` in the `role="alert"` region.
3. **Offline** — `notes-offline` (`role="status"`) with `notes-offline-check` (`Проверить сеть`); loaded text `Нет сети — показаны загруженные заметки.`, zero text `Нет сети — нет загруженных заметок.`; listener on `offline`/`online`, check re-reads `navigator.onLine` and runs `loadNotes` when online. No cache/persistence.
4. **Zero notes** — `notes-empty` wins; `notes-search-empty` cannot replace it; search disabled for `notes.length === 0` and in loading/error/offline; clear hidden for an empty trimmed query and disabled while blocked.
5. **Delete** — rendered visible `Удалить`, `aria-label="Удалить заметку #<id>"` (label-in-name); delete works under an active query and re-renders count/empty state. `Add`/`Logout` stay English.
6. **Single render path** — `renderNotes(query)` filters the loaded list and is re-applied after load/create/delete/reload; query is in-memory only, cleared on login/logout/401/reload; whitespace-only query behaves as empty; clear restores the full list.
7. **A11y** — `role="search"` + label `Поиск заметок`, placeholder `Поиск по тексту...`, `aria-controls="notes-list"`, loading `role=status aria-live=polite`, list `aria-busy`; disabled search gets `aria-disabled`/`aria-describedby`; clear returns focus to search; 3px focus ring and 44px targets remain from DS CSS.
8. **R-1** — closed in `web_ui_test.go` (token-aware oracle, no `design/**` edit).
9. **Responsive** — verified at 390px (stacked search row, full-width 44px controls) and 1200px (inline search + clear), no horizontal overflow.

## Commands and results

Run from `/workspace/projects/notebook`:

```
$ gofmt -l .
(no output; exit 0)

$ go build ./...
(no output; exit 0)

$ go vet ./...
(no output; exit 0)

$ go test -count=1 ./...
ok  	github.com/ukituki-ps/notebook	2.798s
(exit 0)

$ node --check web/app.js
(no output; exit 0)
```

Baseline before the change failed exactly at R-1:

```
--- FAIL: TestUISemantics (0.00s)
    web_ui_test.go:264: app.css missing "min-height: 44px"
```

Additional runtime verification (temporary copy of `main.go` on `:9099`, latest embedded assets; workspace untouched) with headless Chromium/Playwright:

- register/login, add 2 notes, delete under query;
- count `Найдено 1` / `Найдено 0`, clear restores list and focuses search, whitespace = empty;
- 390px: search/clear stacked, controls ≥44px, `scrollWidth <= clientWidth`;
- 1200px: search/clear inline, no overflow;
- offline with loaded notes: banner/status text, search disabled, count hidden, check re-checks; back online + check reloads;
- offline-zero: `Нет сети — нет загруженных заметок.`, base empty visible, search empty not shown, search disabled;
- failed GET `/api/notes` → alert copy + `Повторить` → retry loads normally and hides retry.

Result: `VERIFY_UI_OK`.

## Residual risk

- The offline banner intentionally stays visible after an `online` event until `Проверить сеть` is pressed (the control owns the re-check/reload). This keeps the required control reachable; a successful load hides the banner.
- `web/e2e/**` was not edited and was not run here (requires the preview stand, s20c). The unit oracle is `TestUISemantics` plus the isolated Playwright runtime check above.
- A legacy `sessionStorage["notebook.search"]` value from an older build is removed on login/logout/401/boot but never read or written; the query itself remains in memory.
- `ui-audit-check.py` is not applicable at this unit step (feature `ui-audit.json` is produced later at s22a; the tool currently resolves a different feature directory).
