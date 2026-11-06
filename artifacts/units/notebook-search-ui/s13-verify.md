# s13 independent verification — notebook-search-ui

- Feature: `f-v4-note-search`
- Execution: `E8363-s20.sde_5fexecution-u02`
- Unit: `notebook-search-ui`
- Worktree: `/workspace/projects/notebook-e8363-u02`
- Branch: `orc-exec-E8363-s20.sde_5fexecution-u02`
- HEAD tested (commands executed at): `8ffafe15f251799cf4f927c706ccb9a7c5a4f7e1`
- Branch tip at report time: `80e4e2d9d68d64913db0cb3ba4b43508973866e7`
  (`chore(notebook-search-ui): s15 independent regression (E8363)`, artifacts
  only; `git diff 8ffafe1..80e4e2d -- main.go main_test.go web web_ui_test.go`
  is empty)
- Evidence HEAD in `s13-verify-input.md`: `9ceafdbd1bede428097d784539093092d0c9156f`
- Source equivalence: `git diff --stat 9ceafdb..HEAD` contains only
  `artifacts/units/notebook-search-ui/{s10,s11,s12,s15}`; all UI sources are
  byte-identical to the evidence HEAD.
- Verified by: `architect` (independent verifier; read-only source inspection,
  fresh local commands, no git write commands)
- Toolchain: `go1.24.4 linux/amd64`, `node v20.19.2`
- Verdict: **PASS**

## Commands reproduced

| # | Command (cwd = worktree) | Exit | Result |
|---|---|---|---|
| 1 | `go test -count=1 -run TestUISemantics ./...` | `0` | `ok github.com/ukituki-ps/notebook 0.001s` |
| 2 | `go test -count=1 ./...` | `0` | `ok github.com/ukituki-ps/notebook 2.749s` |
| 3 | `node --check web/app.js` | `0` | no output |
| 4 | `go build ./...` (supporting) | `0` | no output |
| 5 | `go vet ./...` (supporting) | `0` | no output |

## Content hashes (independently recomputed, match `s12-check.md`)

```
4976f733804d030089d6c3e136e456338f139d10fba0349205cce2e6fb50dc1c  web/index.html
438a5ba0bd2674c41a0fbe0fcac1107d9ecdbea64b1192705da50194d29a76bf  web/app.js
0f7fe03cfa2b76d54c2a75d860f0e812f912aa2c9b3eb6d0bc11b9d308483b4a  web/app.css
16d670c6fb871f857ba74346309bf40a515910c2255b16e21cb739acf1d71dbb  web_ui_test.go
419dae4b7993761da12207e7354544f9d718ec4be0ed6f74f7ad9cf06cb4afed  main.go
```

## Contract checks (independent inspection)

### `web/index.html`

- `role="search"` container with a visible `<label for="notes-search">Поиск заметок</label>`
  (lines 77-79).
- `data-testid="notes-search"` input: `id="notes-search"`, `type="search"`,
  `aria-controls="notes-list"`, placed above `data-testid="notes-list"`
  (lines 80-85, 96).
- `data-testid="notes-search-clear"`: `type="button"`,
  `aria-label="Очистить поиск"`, starts `hidden` (lines 83-85).
- `data-testid="notes-search-empty"`: `role="status"`, `aria-live="polite"`,
  starts `hidden`, copy `Ничего не найдено.` (lines 92-95).
- `data-testid="notes-empty"` remains a separate base-empty element
  (lines 89-91).
- Existing f-v3 regions (`notes-loading`, `notes-error`, `notes-list`,
  `note-item-template`) are intact.

### `web/app.js`

- `var searchQuery = ""` (line 310) is the single query state.
- `filterNotes()` (lines 362-368) trims and lower-cases the query, builds
  `noteSearchText()` from the loaded note (`text`, optionally `title`) in lower
  case, and uses `notes.filter(... .indexOf(query) !== -1)`.
- `renderNotes()` (lines 372-391) is the only function that appends rows
  (`appendChild(makeNote(` once). It is called from load (`427`), create (`529`),
  delete (`473`), search input (`563`), and clear (`572`).
- Search-empty guard is exactly
  `notesSearchEmpty.hidden = !(hasQuery && !noNotes && visible.length === 0)`
  with `hasQuery = searchQuery.trim() !== ""` and
  `noNotes = notes.length === 0` (lines 374-375, 385-388).
- Base empty state: `notesEmpty.hidden = !noNotes` (line 383) — not replaced by
  the search-empty state.
- Clear button visibility uses the raw query: `notesSearchClear.hidden = searchQuery === ""`
  (line 389), matching U-02.
- Search input handler only mutates state/storage and calls `renderNotes()`
  (lines 559-565); there is no `fetch`/`api()` call per keystroke.
- Clear resets query, input, `sessionStorage`, re-renders, and focuses the input
  (lines 567-575).
- Loading: `loadNotes()` hides list/empty/search-empty and calls
  `setNotesEnabled(false)` before the request (lines 392-401); success calls
  `renderNotes()` then `setNotesEnabled(true)` (lines 426-429). Error paths
  return without re-enabling, matching the f-v3 "controls stay disabled after a
  failed initial GET" behaviour.
- 401 routes through unchanged `handleUnauthorized()` (lines 393-396, 419-422,
  471-474, 540-543).

### 10-state UI contract (feature brief)

The independent read accounts for all states: auth login/register (unchanged),
idle/list, filtering, results, search-empty, genuinely-empty (`notes-empty`),
loading, error, and unauthorized/401. Search transitions
(idle → filtering → results | search-empty → clear → idle; create/delete/reload
re-apply) are all driven by the single `renderNotes()` path.

### `web_ui_test.go::TestUISemantics`

- Asserts the search testids, the `for="notes-search"` label, `type="search"`,
  `aria-controls="notes-list"`, search-before-list ordering, clear-button
  `type=button`/`aria-label`/default-hidden, and search-empty
  `role=status`/`aria-live=polite`/default-hidden (lines 53-54, 109-120,
  157-203).
- Asserts one `renderNotes()` definition, `renderNotes(` count >= 4, exactly one
  `appendChild(makeNote(`, `toLowerCase()`, `notes.filter(`, `.indexOf(`,
  `searchQuery`, and the `notes.length === 0` / `!noNotes` separation
  (lines 229-247).
- Existing auth/loading/error/401/register and CSS assertions remain (file tail).
- `git diff 9ceafdb..HEAD -- web_ui_test.go` is empty: the oracle is the
  committed one, not a local weakening.

## Notes

- No source file was modified; only the verifier's s13/s14/s16 records were
  written.
- Runtime browser behaviour remains the `SEARCH-E2E-1..6` / s20c responsibility;
  this verification is the static + Go-oracle gate.
- No FAIL and no blocking finding.
