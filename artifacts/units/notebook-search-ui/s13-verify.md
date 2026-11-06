# s13 verify — notebook-search-ui (independent architect verification)

- Unit: `notebook-search-ui` (f-v4-note-search)
- Execution: `E8895`
- Worktree: `/workspace/projects/notebook-ae079e5c-u02`
- Branch: `orc-exec-E8895-s20.sde_5fexecution-u02`
- Verified HEAD: `24f997de5f5cd669e78a98efd97c007f81ec379a`
- Worktree state before verification: clean vs HEAD (`git status --porcelain` empty, `git diff --quiet HEAD` exit 0)
- Toolchain: `node v20.19.2`, `go version go1.24.4 linux/amd64`
- Date: 2026-11-06
- Verified by: architect (independent verification; no git write commands used)

## Verdict: **pass**

## Criteria and evidence

### 1. `web/index.html` — search controls (PASS)

`web/index.html` sha256 `4976f733804d030089d6c3e136e456338f139d10fba0349205cce2e6fb50dc1c`.

- `notes-search`: `data-testid="notes-search"` with `id="notes-search"` and
  `<label for="notes-search">Поиск заметок</label>` (lines 78–82), `type="search"`,
  `aria-controls="notes-list"`.
- `notes-search-clear`: `data-testid="notes-search-clear"`, `type="button"`,
  `aria-label="Очистить поиск"`, starts `hidden` (lines 83–85).
- `notes-search-empty`: `data-testid="notes-search-empty"`, `role="status"`,
  `aria-live="polite"`, starts `hidden` (lines 92–95).
- Ordering: search block (lines 77–87) and search-empty region (lines 92–95)
  both appear before `data-testid="notes-list"` (line 96); verified statically
  and by the `searchPos < listPos` assertion in `TestUISemantics`.

### 2. `web/app.js` — single filter/render path (PASS)

`web/app.js` sha256 `438a5ba0bd2674c41a0fbe0fcac1107d9ecdbea64b1192705da50194d29a76bf`.

- `function renderNotes(` occurs exactly **1** time (line 372);
  `appendChild(makeNote(` occurs exactly **1** time (line 379), so no second
  row-building path exists.
- `renderNotes()` call sites:
  - line 427 — `loadNotes()` after `GET /api/notes` (also path for reload:
    `initNotes()` restores `searchQuery` from sessionStorage, then `loadNotes()`
    re-applies it);
  - line 473 — `deleteNote()` after `204`;
  - line 529 — note submit handler after `201` create;
  - line 563 — search input event;
  - line 572 — clear button click.
- Case-insensitive title/text filter: `noteSearchText()` joins `title` + `text`,
  lowercases, `filterNotes()` trims/lowercases the query and uses `indexOf`
  (lines 355–368).
- Search-empty gating: `notesSearchEmpty.hidden = !(hasQuery && !noNotes && visible.length === 0)`
  where `hasQuery = searchQuery.trim() !== ""` and `noNotes = notes.length === 0`
  (lines 374–387) — shown only for a non-empty query over a non-empty collection
  filtered to zero rows.
- Base empty state preserved: `notesEmpty.hidden = !noNotes` (line 383); the
  search-empty branch cannot replace it.

### 3. `web_ui_test.go` — `TestUISemantics` contract (PASS)

`web_ui_test.go` sha256 `16d670c6fb871f857ba74346309bf40a515910c2255b16e21cb739acf1d71dbb`.

- Asserts testids `notes-search`, `notes-search-clear`, `notes-search-empty`
  (lines 53–54), label/id linkage including `notes-search` (lines 109–120),
  `type="search"`, `aria-controls="notes-list"`, DOM ordering above
  `notes-list`, clear-button `type=button`/`aria-label`/hidden, and
  search-empty `role=status`/`aria-live=polite`/hidden (lines 157–203).
- Asserts the `renderNotes()` contract: definition present, `renderNotes(`
  count >= 4, exactly one `appendChild(makeNote(`, `toLowerCase()`,
  `notes.filter(`, `.indexOf(`, `searchQuery`, and both `notes.length === 0`
  and `!noNotes` (lines 229–247).
- Existing assertions remain: `git diff ebc2c4e~1 ebc2c4e -- web_ui_test.go`
  (read-only) shows only additions plus the two list extensions
  (`note-input` → `note-input, notes-search`; `delete-note` →
  `delete-note` + search ids). No pre-existing assertion was deleted or
  weakened.

### 4. Commands run (exact results)

All commands run from `/workspace/projects/notebook-ae079e5c-u02`.

```
$ node --check web/app.js
(no output)
exit=0
```

```
$ GOWORK=off go build ./...
(no output)
exit=0
```

```
$ GOWORK=off go vet ./...
(no output)
exit=0
```

```
$ GOWORK=off go test -count=1 -run TestUISemantics -v ./...
=== RUN   TestUISemantics
--- PASS: TestUISemantics (0.00s)
PASS
ok  	github.com/ukituki-ps/notebook	0.002s
exit=0
```

## Notes

- No git write commands were executed; HEAD remained
  `24f997de5f5cd669e78a98efd97c007f81ec379a` throughout.
- This is static/unit verification. Runtime browser behaviour (focus, live
  announcements, sessionStorage restore on a real reload) remains covered by
  `web/e2e/auth-notes.spec.js`, which is outside this unit's scope.
