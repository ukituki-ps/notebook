# s15 regression — notebook-search-ui

- Unit: `notebook-search-ui`
- Feature: `f-v4-note-search`
- Execution: `E8363-s20.sde_5fexecution-u02`
- Worktree: `/workspace/projects/notebook-e8363-u02`
- Branch: `orc-exec-E8363-s20.sde_5fexecution-u02`
- HEAD audited: `8ffafe15f251799cf4f927c706ccb9a7c5a4f7e1`
- Auditor: independent (read-only; no git write commands)
- Date: 2026-11-06 (UTC)

## Verdict: PASS — no regression, no out-of-scope source change

## Regression commands and results

Run from the worktree root, toolchain `go1.24.4 linux/amd64`.

| # | Command | Exit | Result |
|---|---|---|---|
| 1 | `go test -count=1 ./...` | `0` | `ok github.com/ukituki-ps/notebook 2.799s` — full suite |
| 2 | `go test -count=1 -run TestUISemantics -v ./...` | `0` | `--- PASS: TestUISemantics (0.00s)` |
| 3 | `go test -count=1 -run '^(TestRegister\|TestLogin\|TestLoginInvalid\|TestAddNote\|TestDeleteNote\|TestDeleteInvalidID\|TestDeleteForeignNote\|TestDeleteMissing\|TestNotesIsolation\|TestAuthRequired\|TestAuthMethodOrder\|TestUnknownAPINotFound)$' -v ./...` | `0` | 12/12 PASS, `ok ... 1.642s` |
| 4 | `go test -count=1 -run '^(TestNotesLifecycle\|TestDeleteExisting\|TestListAfterDelete)$' -v ./...` | `0` | 3/3 PASS, `ok ... 0.142s` |

### Create/delete/login flow check

- **Login/register:** `TestRegister`, `TestLogin`, `TestLoginInvalid`,
  `TestAuthRequired`, `TestAuthMethodOrder` PASS. `web/index.html` auth markup
  and `web/app.js` auth code paths are unchanged by the feature diff.
- **Create:** `TestAddNote`, `TestNotesLifecycle` PASS. `app.js` POST handler
  now pushes the created note into `notes` and calls the single
  `renderNotes()`, so an active query is re-applied; input reset/busy state
  unchanged.
- **Delete:** `TestDeleteNote`, `TestDeleteExisting`,
  `TestDeleteInvalidID`, `TestDeleteForeignNote`, `TestDeleteMissing`,
  `TestListAfterDelete`, `TestNotesLifecycle` PASS. `app.js` DELETE 204 path
  removes by id and calls `renderNotes()`; 404/401/other branches unchanged.
- **Reload/list:** `TestNotesLifecycle`, `TestListAfterDelete` PASS;
  `loadNotes()` still fetches `/api/notes` and renders through `renderNotes()`.
- **UI oracle:** `TestUISemantics` PASS, including the new search testids,
  label, `type=search`, `aria-controls`, default-hidden clear/search-empty,
  single `renderNotes()` path and search-empty guard.

## Out-of-scope check

- Worktree source status vs HEAD: **clean** — only `artifacts/units/**` files
  differ; no `web/**` or `web_ui_test.go` file is dirty.
- Branch delta vs feature base `9ceafdb` (committed):
  `s10-unit-plan.md` (A), `s11-execution.md` (A), `s12-check.md` (M) —
  artifact files only.
- Feature code delta (base `dev/f-v3-auth-notes` → `9ceafdb`/validation-zero)
  for unit u02: `web/index.html`, `web/app.js`, `web/app.css`,
  `web_ui_test.go` — **exactly the allowed scope** (no `main.go`,
  `main_test.go`, deploy, package or E2E-source change).
- `web_ui_test.go` delta is additive assertions (search ids/accessibility/
  single-render/filter primitives), plus the two required id-list extensions;
  no existing assertion was removed or weakened.

## Regression/out-of-scope findings

None. No new findings.

## Residual risk

- Browser-level create/delete/search interaction is proven by static/Go
  semantics and the E2E spec (u03), but the live Playwright run against a stand
  is deliberately deferred to s20c; no local browser run was performed here.
- `sessionStorage` query restore is an OD-6 convenience, not contractual.
