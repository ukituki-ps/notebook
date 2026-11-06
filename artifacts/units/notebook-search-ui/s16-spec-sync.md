# s16 spec sync — notebook-search-ui

- Feature: `f-v4-note-search`
- Execution: `E8363-s20.sde_5fexecution-u02`
- Unit: `notebook-search-ui`
- Branch: `orc-exec-E8363-s20.sde_5fexecution-u02`
- HEAD checked: `8ffafe15f251799cf4f927c706ccb9a7c5a4f7e1`
  (branch tip at report time `80e4e2d`, artifacts-only s15 commit; source
  identical to evidence HEAD `9ceafdb`)
- Spec inputs: `spec/core.md` §3; `spec/contract-matrix.md` UI rows
  `U-01..U-11`; `feature-brief.md` UX/wireframes; `T0005`, `T0006`, `T0007`
  briefs.
- `spec_synced: true`, `drift_count: 0`

## UI row → implementation → oracle

| Row | Contract | Code evidence (HEAD) | Oracle | Status |
|---|---|---|---|---|
| U-01 | labelled `notes-search`, `type=search`, `aria-controls=notes-list`, above list | `web/index.html:77-85` (`role=search`, `label for`, input attrs); search block precedes `notes-list` at `:96` | `TestUISemantics` (testid/label/type/aria/ordering) | synced |
| U-02 | `notes-search-clear` is `type=button`, accessible name, hidden while raw query empty | `web/index.html:83-85`; `web/app.js:389` (`hidden = searchQuery === ""`) | `TestUISemantics` (type/aria-label/default-hidden) | synced |
| U-03 | client-side filter of loaded owner-scoped list; no request per keystroke | `web/app.js:362-368` (`filterNotes`), `:559-565` (input handler only renders) | `TestUISemantics` + `SEARCH-E2E-1` (s20c) | synced |
| U-04 | case-insensitive UI match | `web/app.js:363-367` lower-cases query and note text, `indexOf` | `TestUISemantics` primitives + `SEARCH-E2E-3` (s20c) | synced |
| U-05 | search-empty only when trimmed query non-empty AND collection non-empty AND zero matches; `role=status`, `aria-live=polite`, copy | `web/app.js:374-375,385-388`; `web/index.html:92-95` | `TestUISemantics` + `SEARCH-E2E-2` / `-6` (s20c) | synced |
| U-06 | genuinely empty server list shows `notes-empty`, search-empty hidden | `web/app.js:375,383,387` (`notesEmpty.hidden = !noNotes`; guard requires `!noNotes`) | `TestUISemantics` + auth `E2E-5` | synced |
| U-07 | clear restores full list, hides search-empty | `web/app.js:567-575` resets query/input/storage, `renderNotes()`, focuses input | `SEARCH-E2E-4` (s20c) | synced |
| U-08 | create while query active re-applies filter | `web/app.js:526-531` pushes result then `renderNotes()` | `SEARCH-E2E-5` (s20c) | synced |
| U-09 | delete while query active re-applies; last match → search-empty, not notes-empty | `web/app.js:468-474` filters `notes` then `renderNotes()`; guard separates collection emptiness | `SEARCH-E2E-6` (s20c) | synced |
| U-10 | login precedes notes/search; user-B isolation stays auth E2E-6 | login redirect unchanged; filter reads only the loaded owner-scoped array (`web/app.js:313,420`) | auth `E2E-6` + `TestNotesSearchIsolation` | synced |
| U-11 | loading/error/401 unchanged; search controls disabled while loading, usable loaded | `web/app.js:319-326` (`setNotesEnabled`), `:392-401` (disable during load), `:426-429` (enable on success), `:392-401,450-455` (401/error paths) | `TestUISemantics` + auth `E2E-7` | synced |

## Invariant mapping

- `INV-SEARCH-UI-FILTER` → `filterNotes` + single `renderNotes` path;
  `TestUISemantics`; `SEARCH-E2E-1` — synced.
- `INV-SEARCH-UI-EMPTY` → three-condition guard at `web/app.js:385-388`;
  `TestUISemantics`; `SEARCH-E2E-2` / `-6` — synced.
- `INV-SEARCH-UI-TESTIDS` → `web/index.html:77-95`; `TestUISemantics` — synced.
- `INV-UI-LABEL` / `INV-UI-A11Y-NAME` → visible `<label for="notes-search">`,
  clear `aria-label`, polite status region; `TestUISemantics` — synced.
- `INV-UI-TRUTH` → rows are cloned from the API response only
  (`notes = Array.isArray(res.data)...`, `makeNote(note)`), no hardcoded notes;
  `TestUISemantics` — synced.
- `INV-SEARCH-OWNER-SCOPE` (UI side) → filtering reads only `notes` loaded from
  the authenticated `GET /api/notes`; backend oracle is
  `TestNotesSearchIsolation` — synced.

## Non-contract note (OD-6)

`sessionStorage` key `notebook.search` restore (`web/app.js:311,450-451,562`) is
implementation convenience only. It is correctly absent from the contract
matrix and is not asserted as a contract row. Reload works; query persistence is
not promised.

## Drift assessment

- `spec/core.md` §3 and the T0005/T0006/T0007 briefs match the committed HTML,
  JS, CSS, and `TestUISemantics` assertions.
- `notes-empty` and `notes-search-empty` remain distinct in markup, logic, and
  tests.
- No testid or accessible-name drift found.
- All 11 UI rows have an executable oracle; no row is oracle-free.

**Verdict: IN SYNC — `drift_count = 0`, no spec or code change required.**
