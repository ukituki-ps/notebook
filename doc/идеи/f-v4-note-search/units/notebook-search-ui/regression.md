# Unit regression — notebook-search-ui (U02, s15.unit_regression)

- **Unit:** notebook-search-ui (domain `notebook-web`, role `sde-frontend`)
- **Execution:** `E0809-s20.sde_5fexecution-u02`
- **Branch:** `orc-exec-E0809-s20.sde_5fexecution-u02`
- **Audited range:** `f5943f5..edd0fec` (`edd0fec8e0887b33d29cf969aa1774733d042726`, HEAD)
- **Base:** `f5943f5ed87e8bbcaadf48ec23dd005ac2c38f95`
- **Auditor:** `auditor` (independent; no implementation in this step)
- **Auditor session:** `c85a0714-39fe-41b5-959b-3ac8b4841925` (model `deepseek/deepseek-flash`)
- **Date:** 2026-11-08
- **Change class:** plain
- **regression_status: pass**
- **new_findings: []**

## Scope of the audited diff

`git diff --name-only f5943f5..HEAD`:

```
doc/идеи/f-v4-note-search/units/notebook-search-ui/execution-report.md  (added)
doc/идеи/f-v4-note-search/units/notebook-search-ui/plan.md               (added)
web/app.js                                                              (modified)
web/index.html                                                          (modified)
web_ui_test.go                                                          (modified)
```

`git diff --stat f5943f5..HEAD -- design web/app.css web/e2e main.go main_test.go`
is empty (0 lines): no DS/design, CSS, E2E-spec, backend, auth, or wire-schema
change. `web/app.css` is unchanged even though it is in the unit's declared
file list; the new markup reuses existing DS classes (`patterns/note-item`,
`.muted`, `primitives/button`, `patterns/search-field`,
`patterns/search-clear`).

## Contract / scope checks

| Check | Result | Evidence |
|---|---|---|
| No auth/session change | PASS | `web/app.js` auth flow untouched; only adds `removeStorage(sessionStorage, SEARCH_KEY)` on successful login (query is not a session credential). No `main.go` change. |
| No API/wire change | PASS | `main.go`/`main_test.go` unchanged; no request path, method, header, status, or JSON key change in `web/app.js`. |
| No design/DS change | PASS | `design/**` unchanged; `web/app.css` unchanged; `component-map.yaml` already maps `n-offline` to `patterns/note-item` composition, `n-retry`/`n-offline-check` to `primitives/button`, `n-count` to path6 GAP-1. |
| DS-only, no local CSS | PASS | All new nodes use existing registry classes/composition; 0 CSS lines added. |
| No E2E spec change | PASS | `web/e2e/**` unchanged; existing specs select by `data-testid`, not by the localized `Delete` text. |
| No skipped/weakened tests | PASS | No `//go:build` skip tags and no `t.Skip`/`SkipNow` in `*_test.go`. `web_ui_test.go` diff only adds/strengthens assertions; the R-1 change still pins 44px (`--control-height: 44px` + `min-height: var(--control-height)`). |
| Search query in-memory only | PASS | No `readStorage(sessionStorage, SEARCH_KEY)` / `writeStorage(sessionStorage, SEARCH_KEY, ...)` remains; the legacy key is only removed (login/logout/401/boot/clear). |

## Commands and results

Run from `/workspace/projects/notebook` on HEAD `edd0fec` (working tree was
clean apart from this audit note):

| Command | Result |
|---|---|
| `go build ./...` | exit 0, no output |
| `go vet ./...` | exit 0, no output |
| `go test -count=1 ./...` | `ok github.com/ukituki-ps/notebook 2.822s`, exit 0 (includes `TestUISemantics`) |
| `node --check web/app.js` | exit 0, no output |
| `gofmt -l .` | no output, exit 0 |
| `git diff --check f5943f5..HEAD` | no output, exit 0 |
| `python3 tools/ui-audit-check.py --root . --platform web --json` | not applicable here: the tool resolves `doc/идеи/f-v3-auth-notes/ui-audit.json` and fails with "нет doc/идеи/<F>/invariants.json". DS was checked manually (unchanged `design/**`, unchanged `app.css`, composition mapping above). |

## Regression review notes

- **Single render path preserved.** `renderNotes(query)` remains the only
  filter/render funnel; load, create, delete, input, and clear all route
  through it, and the in-memory query is re-applied after create/delete.
- **Base empty state precedence preserved.** `notes-empty` still wins at
  `notes.length === 0`; `notes-search-empty` stays hidden for an empty query and
  in loading/error/offline states.
- **Existing flows preserved.** Login/register, add, delete, 401 redirect,
  reload, and the delete-under-active-query path are unchanged in contract;
  the delete button keeps per-row `aria-label="Удалить заметку #N"` and the
  visible label is now `Удалить` (AC/AOD-6), while `Add`/`Logout` stay English.
- **Error/retry path.** `notes-retry` is hidden by default, shown only on a
  non-200/failed load, and calls the normal `loadNotes` path (loading state,
  401 handling, active-query re-apply).
- **Offline path.** `navigator.onLine` + loaded notes drive
  `notes-offline`/`notes-offline-check`; no cache or persistence is introduced.
  Offline-zero shows the offline copy and does not render a false
  `notes-search-empty`.
- **R-1.** `TestUISemantics` now accepts the DS token and still asserts the
  literal 44px value via `--control-height: 44px`; no `design/**` edit.

## Residual risks (non-blocking, no new finding)

1. After an `online` event the offline banner and disabled search remain until
   the user presses `Проверить сеть`; the control re-reads `navigator.onLine`
   and re-runs `loadNotes`. This is an explicit, documented unit choice and
   keeps the required control reachable; it does not produce a false
   search-empty state.
2. The `offline` event handler updates search/offline/form state but does not
   re-run `renderNotes`, so an already-visible `notes-search-count` /
   `notes-search-empty` is not recomputed at that instant. Their visibility
   still satisfies the spec (count for a non-empty query; search-empty only for
   a non-empty collection filtered to zero), so this is cosmetic state-timing,
   not a contract violation.
3. `web/e2e/**` was not run: it needs the preview stand and is out of scope for
   this unit step (s20c); the unit oracle is `TestUISemantics` plus the Go suite.
4. A legacy `sessionStorage["notebook.search"]` value is removed but never read
   or written by this build; no user data is persisted by the search UI.

## Verdict

`new_findings: []` — no regression, no contract/auth/API/wire/design/E2E change,
no skipped or weakened test, and the unit oracle plus the full Go suite are
green. `regression_status: pass`.

- accepted: s15.unit_regression (E0809-u02); new_findings []
