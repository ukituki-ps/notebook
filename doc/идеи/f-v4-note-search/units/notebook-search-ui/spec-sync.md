# s16 unit spec-sync — notebook-search-ui

- Unit: `notebook-search-ui` · Execution `E0809-s20.sde_5fexecution-u02`
- Verified HEAD: `edd0fec8e0887b33d29cf969aa1774733d042726`
- Spec: `doc/идеи/f-v4-note-search/spec/core.md` (s14, E0809)
- Role: `architect` (independent of `sde-frontend`)

## synced: **true**

No API (`core.md` §1), data-model (§2), auth, persistence, or wire-format
change is introduced by this unit. The unit closes the §3 UI deltas and the
§3.6 base gaps (`Clear`/`Delete` copy, short search-empty copy, sessionStorage
query persistence, R-1). The E2E oracle for §3 remains deferred to U03.

## Spec §3 → implementation mapping

| Spec §3 | Implementation | Status |
|---|---|---|
| §3.1 composer-first order: header → error region → composer → search → list (AOD-7) | `web/index.html:60-109`: header 60-64, error 66, composer 69-74, loading 76-77, search 79-89, offline 91-96, count 98-99, empty states 101-107, list 108-109 | synced |
| §3.2 search field: `notes-search`, label `Поиск заметок`, placeholder `Поиск по тексту...`, `type=search`, `aria-controls="notes-list"` | `web/index.html:79-84`; label/`for` linkage at 80/82; oracle `web_ui_test.go:181-199` | synced |
| §3.2 clear: `notes-search-clear`, visible `Очистить`, `aria-label="Очистить поиск"`, hidden for empty trimmed query, restores list, focuses search | `web/index.html:85-87`; `web/app.js:368-369, 693-698`; oracle `web_ui_test.go:213-215` | synced |
| §3.2 count: `notes-search-count`, `Найдено N` incl. 0, `aria-live="polite"`, visible only for non-empty trimmed query, hidden when query empty | `web/index.html:98-99`; `web/app.js:437-463`; oracle `web_ui_test.go:238-249` | synced |
| §3.2 search empty: `notes-search-empty`, exact copy, `role=status`, `aria-live=polite`, only for non-empty query over non-empty collection filtered to zero | `web/index.html:104-107`; `web/app.js:457-459`; oracle `web_ui_test.go:227-234` | synced |
| §3.2 base empty wins at `notes.length == 0`; search disabled then | `web/app.js:454`; `searchBlocked()` at 337-339; oracle `web_ui_test.go:345-351` | synced |
| §3.2 loading: `notes-loading` `role=status`, search disabled while loading | `web/index.html:76-77`; `web/app.js:373, 492-502`; oracle `web_ui_test.go:164-169` | synced |
| §3.2 error: `notes-error` `role=alert aria-live=polite` + visible `Повторить` wired to `loadNotes` (loading/401/query re-apply) | `web/index.html:66-67`; `web/app.js:321, 374, 486-549, 701-711`; oracle `web_ui_test.go:253-268` | synced |
| §3.2 offline banner: `notes-offline` from `navigator.onLine` + loaded notes; offline-zero variant; `notes-offline-check` `Проверить сеть` re-runs `loadNotes` when online; no cache | `web/index.html:91-96`; `web/app.js:321-323, 333-339, 376-381, 713-737`; oracle `web_ui_test.go:271-299` | synced |
| §3.2 Delete: visible `Удалить`, `aria-label="Удалить заметку #N"`; `Add`/`Logout` English (AOD-6) | `web/index.html:63,73,118-119`; `web/app.js:407-409`; oracle `web_ui_test.go:141-152` | synced |
| §3.3 client-side filter of the loaded owner-scoped list, no per-keystroke `q` | `web/app.js:419-432` (`noteSearchText`/`filterNotes`), no `/api/notes?q=` from UI | synced |
| §3.3 query in-memory only, cleared on login/logout/401/reload (AOD-3) | `web/app.js:177, 327, 467-473, 551-572, 751-755`; no read/write of `SEARCH_KEY`; oracle `web_ui_test.go:348-350` | synced |
| §3.3 one `renderNotes()` re-applies after load/create/delete/reload | `web/app.js:437` single definition; call sites 526, 537, 576, 600, 656, 689, 696 | synced |
| §3.3 search disabled at zero notes/loading/error/offline; enabled for non-empty collection | `web/app.js:337-339, 346-347`; re-enabled after 200/create via 522-526/654-656 | synced |
| §3.3 `textContent` only (INV-XSS-ESCAPE) | `web/app.js:405, 379, 461`; no `innerHTML` | synced |
| §3.3 clear restores full list and focuses search | `web/app.js:693-698` | synced |
| §3.4 390px stacked search row, full-width 44px controls, no horizontal scroll | `web/app.css:268-286`; `--control-height: 44px` at 14, `min-height` at 73/99 | synced (static CSS inspection) |
| §3.4 1200px centered column, inline search + clear | `web/app.css:192-201, 241-246`; no horizontal overflow primitives | synced (static CSS inspection) |
| §3.4 visible focus ring, labelled controls, live regions, loading `role=status` | DS `:focus-visible`; `aria-live` on count/search-empty/error; `role=status` on loading/offline; oracle assertions | synced |
| §3.5 Notebook DS 1.0.0 only, 0 local instances/CSS, no Kubiki/`frontend/src/ui/kit`, no `design/**` edit | `design` tree identical to base and `ds/v1.0.0` (`2f40103b…`), `web/app.css` unchanged; new markup reuses registry selectors (`button`, `.note-item`, `.note-text`, `.muted`, `.notes-search*`, state testids) | synced |
| §3.5 path6 GAP-1 (`n-count`), GAP-3 (`n-delete`), GAP-2 (input disabled) accepted/non-blocking | count/delete reuse DS `button`/`.muted`; disabled input relies on native disabled + `aria-disabled` (GAP-2 remains accepted) | accepted gaps, unchanged |
| §3.6 R-1: oracle vs `min-height` token without `design/**` edit | `web_ui_test.go:356-366` now checks `min-height: var(--control-height)` + `--control-height: 44px`; `TestUISemantics` green | closed |
| §3.6 visible `Clear`/`Delete`, short search-empty copy, sessionStorage query persistence | `Очистить`/`Удалить`; final copy `Ничего не найдено. Сократите запрос или очистите поиск.`; SEARCH_KEY read/write removed | closed |

## Contracts and invariants

- UI contract ids used by implementation and oracle agree:
  `notes-search`, `notes-search-clear`, `notes-search-count`,
  `notes-search-empty`, `notes-empty`, `notes-loading`, `notes-error`,
  `notes-retry`, `notes-offline`, `notes-offline-check`, `notes-list`,
  `delete-note`.
- Active invariants covered by this unit's oracle: `INV-UI-LABEL`,
  `INV-UI-A11Y-NAME`, `INV-XSS-ESCAPE`, `INV-SEARCH-UI-FILTER`,
  `INV-SEARCH-UI-EMPTY`, `INV-SEARCH-UI-TESTIDS`; `TestUISemantics` green.
- No stale reference or contradictory contract is introduced by the unit.
  One pre-existing spec wording nit: §3.5 says "12 registry components" while
  the `ds/v1.0.0` `design/registry.json` has 14 selectors (11
  primitives/patterns + 3 `states/*` entries). This is present in the DS tag
  itself, not caused by U02; `design/**` is untouched, so the pinned digest is
  unchanged. It is a documentation wording nit for the spec owner, not an
  implementation divergence.

## E2E deferral

`web/e2e/notes-search.spec.js` and the test2 preview run are **not** part of
this unit and are deferred to **U03** (`notebook-search-deploy-e2e`, s20c). The
unit oracle remains `TestUISemantics` plus the static checks in `verify.md`.
`INV-UI-E2E-PREVIEW` / `INV-UI-TRUTH` runtime coverage stays with U03.

## Verdict

**synced = true** for the U02 UI scope; no API/data contract drift.

- accepted: s16.unit_spec_sync (E0809-u02); synced true
