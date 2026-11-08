# s13 unit verify — notebook-search-ui (independent architect)

- Unit: `notebook-search-ui` (domain `notebook-web`, executor role `sde-frontend`)
- Execution: `E0809-s20.sde_5fexecution-u02`
- Worktree: `/workspace/projects/notebook`
- Branch: `orc-exec-E0809-s20.sde_5fexecution-u02`
- Base: `f5943f5` (`docs(f-v4-note-search): s19 test2 stand lease (E0809)`)
- Verified HEAD: `edd0fec8e0887b33d29cf969aa1774733d042726` (`feat(u02): note-search UI count/retry/offline/delete-label + R-1 fix (green)`)
- Origin: `origin/orc-exec-E0809-s20.sde_5fexecution-u02` = `edd0fec`
- Toolchain: `go1.24.4 linux/amd64`, `node v20.19.2`
- Date: 2026-11-08
- Verified by: `architect` (independent of `sde-frontend`; read-only verification, no code/git write)

## Verdict: **pass**

Scope checked: `git diff f5943f5..HEAD -- web/ web_ui_test.go` touches only
`web/app.js`, `web/index.html`, `web_ui_test.go`; `web/app.css` and
`design/**` are byte-identical to the base/DS tag (see §DS-only).

File hashes at the verified HEAD:

```
322312eda21b5b4833d6904bb69621f6289d30eb8739f8ce2eb701bc0cdaef74  web/index.html
ba4580112464fa8f3e7026219189b6c6ae12c7bdb8fd207cf93d9c8277d8d85a  web/app.js
749b9108ccb7dc68b6603afa86b081dacaece382331a0638661a013cd5f53ee2  web/app.css
b429e8b20297e4f90a33fc7b87db73a29531a33df29a4c2923cf361b7db374a4  web_ui_test.go
```

## Criteria and evidence

### 1. Result count — PASS

- `web/index.html:98-99` — `data-testid="notes-search-count"`,
  `aria-live="polite"`, starts `hidden`, text `Найдено 0`.
- `web/app.js:460-463` — `textContent = "Найдено " + visible.length`;
  `hidden = !(hasQuery && !noNotes && !blocked)`, where
  `hasQuery = searchQuery.trim() !== ""` (437-446), `noNotes = notes.length === 0`,
  `blocked = notesBusy || notesFailed || notesOfflineState`.
- Result: visible only for a non-empty trimmed query over a non-empty collection,
  including `Найдено 0`; hidden for an empty/whitespace query, zero notes, and
  loading/error/offline render paths. `aria-live="polite"` present.
- Oracle: `web_ui_test.go:238-249` (`"Найдено "` at 248).

### 2. Retry — PASS

- `web/index.html:67` — `data-testid="notes-retry"`, `type="button"`, starts
  `hidden`, visible label `Повторить`.
- `web/app.js:374` — shown only while `notesFailed`.
- `web/app.js:701-711` — click re-checks `navigator.onLine`, then calls
  `loadNotes()` (normal path: `notesBusy`, 401 handling at 507-510, query
  re-application because `renderNotes()` uses the in-memory `searchQuery` at 526).
- Error copy `LOAD_ERROR` is set in the `role="alert"` region (321, 513, 541).
- Oracle: `web_ui_test.go:253-268`.

### 3. Offline banner / offline-zero / no cache — PASS

- `web/index.html:91-96` — `data-testid="notes-offline"` (`role="status"`,
  starts hidden) with `notes-offline-check` (`type="button"`,
  `aria-label="Проверить сеть"`, visible `Проверить сеть`).
- `web/app.js:321-323` — `OFFLINE_LOADED` / `OFFLINE_EMPTY` copy including the
  offline-zero variant `Нет сети — нет загруженных заметок.`
- `web/app.js:333-339, 376-381` — driven by `navigator.onLine` plus `notes.length`;
  `725-737` — `offline`/`online` listeners; `713-723` — `Проверить сеть`
  re-checks `navigator.onLine` and runs `loadNotes()` when online.
- `web/app.js:528-538` — a failed load while offline keeps already loaded notes
  visible, shows the banner, and does not raise a false error/search-empty.
- No cache/persistence is added; the only storage access for search is
  `removeStorage(sessionStorage, SEARCH_KEY)` cleanup (see criterion 6).
- Oracle: `web_ui_test.go:271-299`.

### 4. Zero-note precedence and search disable — PASS

- `web/app.js:454` — `notesEmpty.hidden = !noNotes`; base empty wins.
- `web/app.js:457-459` — `notes-search-empty` requires `hasQuery && !noNotes`,
  so it cannot replace `notes-empty`.
- `web/app.js:337-339` — `searchBlocked()` = locked | busy | failed | offline |
  `notes.length === 0`; applied at `346-347`. Enabled for a non-empty collection
  after load/create (`522-526`, `654-656`).
- Oracle: `web_ui_test.go:345-351` plus existing `notes.length === 0`/`!noNotes`
  assertions.

### 5. Delete label and aria-label — PASS

- `web/index.html:118-119` — visible `Удалить`.
- `web/app.js:400-415` — per-row `aria-label="Удалить заметку #" + note.id`
  (line 409); `Add`/`Logout` remain English (`web/index.html:63,73`).
- Delete under an active query re-renders count/empty state via
  `deleteNote() → renderNotes()` (`web/app.js:596-601`).
- Oracle: `web_ui_test.go:141-152` (rejects `>Delete<`, requires per-note label).

### 6. Single render path and in-memory query — PASS

- Exactly one definition: `function renderNotes(query)` at `web/app.js:437`;
  one row builder `appendChild(makeNote(` at `450`.
- Call sites: `526` (load), `537` (offline catch), `576` (offline boot), `600`
  (delete), `656` (create), `689` (input), `696` (clear) — all re-apply the
  active query.
- Query is memory-only (`var searchQuery` at 327). No
  `readStorage(sessionStorage, SEARCH_KEY)` / `writeStorage(sessionStorage,
  SEARCH_KEY...`; only legacy cleanup `removeStorage` at 177, 470, 561, 572,
  695, 754. Cleared on login success (177), 401 (472-473), boot/reload
  (570-572), and logout (751-755, full reload).
- Clear restores the full list and focuses search (`693-698`).
- Oracle: `web_ui_test.go:308-312, 328-330, 348-350`.

### 7. XSS — PASS

- `web/app.js:405` writes note text via `textContent`; count/offline text also
  use `textContent` (379, 461). No `innerHTML` in `web/app.js` or
  `web/index.html` (`grep -c innerHTML` → 0 matches).
- `web_ui_test.go` `INV-XSS-ESCAPE` path remains covered by `TestUISemantics`.

### 8. R-1 — PASS

- `web/app.css:14` — `--control-height: 44px`; `73,99` —
  `min-height: var(--control-height)` (file unchanged by the unit).
- `web_ui_test.go:356-366` — oracle now requires
  `min-height: var(--control-height)` and `--control-height: 44px` instead of
  the literal `min-height: 44px`; no `design/**` edit.
- `TestUISemantics` passes (below); R-1 is closed.

### 9. DS-only and 390/1200 — PASS

- `git diff --quiet f5943f5 HEAD -- design` → exit 0; `git rev-parse
  HEAD:design` == `git rev-parse f5943f5:design` ==
  `2f40103b6058c9091329707bc8f240e4ab4848ff`; DS tag `ds/v1.0.0` diff is empty,
  so the pinned digest `sha256:02f027a8…da3d` is unchanged.
- `git diff --quiet f5943f5 HEAD -- web/app.css` → exit 0: no local CSS added.
  New markup reuses DS selectors from `design/registry.json`: `button`,
  `.note-item`, `.note-text`, `.muted`, `.notes-search*`, state testids. No
  Kubiki / `frontend/src/ui/kit` references (`design/releases/1.0.0/provenance.json`
  only states "not Kubiki").
- 390px: `web/app.css:268-286` — inputs/textareas/buttons `width: 100%`,
  `.notes-search-row` becomes `flex-direction: column`, `.note-item` stacks.
- 1200px: `web/app.css:192-201` — inline flex search row with
  `input { flex: 1 1 auto; min-width: 0 }`; `.note-text` uses
  `overflow-wrap: anywhere` (241-246), so long note text cannot force horizontal
  overflow. No new responsive rule was needed; static inspection shows no
  width > viewport and no unbreakable inline content.

## Commands (run from `/workspace/projects/notebook`)

```
$ go test -count=1 ./...
ok  	github.com/ukituki-ps/notebook	2.816s
exit=0

$ go vet ./...
(no output)
exit=0

$ node --check web/app.js
(no output)
exit=0

$ go test -count=1 -run TestUISemantics -v ./...
=== RUN   TestUISemantics
--- PASS: TestUISemantics (0.00s)
PASS
ok  	github.com/ukituki-ps/notebook	0.002s
exit=0
```

Supplementary ORC evidence: `go test -count=1 ./...` via `orc_proof_run`
(`PR-39ca415d9a4f`, exit 0, sha256 `7e213acadd0202e39bbf5884aaa8cdef06d63345947755683797f83a62c1c90e`).

## Residual minors (non-blocking)

1. **Count on an offline transition.** `window "offline"` calls only
   `syncFormState()`/`syncNotesState()` (`web/app.js:725-729`); it does not
   re-run `renderNotes()`. A count that was visible before going offline stays
   visible until the next render. `loadNotes`/error paths do hide it, so the
   report's "count hidden offline" is accurate for those paths; the transition
   case is cosmetic (search is disabled and the offline banner is shown).
2. **Offline banner persists after `online`** until `Проверить сеть` is pressed
   (documented in the code and execution report; matches §3.2's explicit check
   control, not auto-recovery).
3. `notesRetry` and `notesOfflineCheck` click handlers are near-identical
   (`web/app.js:701-723`) — small DRY nit, not a second code path.
4. The template carries the generic fallback `aria-label="Удалить заметку"`;
   the per-row `#N` label is applied by JS for every cloned row.
5. `web/e2e/*` and `tools/ui-audit-check.py` are not unit oracles here
   (e2e deferred to U03; UI audit is produced at s22a).

Result: **PASS** for the unit scope. No code, `design/**`, or commit change
was made by this verification.

- accepted: s13.unit_verify (E0809-s20.sde_5fexecution-u02)
