# s10 unit plan — notebook-search-ui

- Unit: `notebook-search-ui`
- Execution: `E8363-s20.sde_5fexecution-u02`
- Feature: `f-v4-note-search`
- Branch: `orc-exec-E8363-s20.sde_5fexecution-u02`
- Base/HEAD at plan time: `9ceafdbd1bede428097d784539093092d0c9156f`
- SDE role: `sde-frontend` (`developer` / `frontend`)
- Change class: `plain`

## Objective

Verify the already-implemented note-search UI against the normative brief,
change definition, spec and T0005/T0006/T0007 task briefs. Do not redesign or
extend scope; only fix a real in-scope defect if verification finds one.

## Inputs (read before verification)

- `doc/идеи/f-v4-note-search/feature-brief.md`
- `doc/идеи/f-v4-note-search/change-definition.md`
- `doc/идеи/f-v4-note-search/spec/core.md`
- `doc/идеи/f-v4-note-search/spec/contract-matrix.md`
- `doc/идеи/f-v4-note-search/T0005/brief.md` (markup/testids)
- `doc/идеи/f-v4-note-search/T0006/brief.md` (filter/clear/empty logic)
- `doc/идеи/f-v4-note-search/T0007/brief.md` (UI semantics oracle)
- `web/index.html`, `web/app.js`, `web/app.css`, `web_ui_test.go`

## Checks planned

1. Search markup: labelled `notes-search` (`type=search`,
   `aria-controls=notes-list`) above the list; separate `notes-search-clear`
   (`type=button`, accessible name, starts hidden); `notes-search-empty`
   (`role=status`, `aria-live=polite`, starts hidden, copy `Ничего не найдено.`);
   `notes-empty` remains a separate base state.
2. Filter logic: one `renderNotes()` path, trimmed/lower-cased case-insensitive
   substring over the loaded owner-scoped array, no per-keystroke request, no
   widening beyond the loaded list.
3. Empty-state separation: search-empty only when trimmed query non-empty AND
   loaded collection non-empty AND zero matches; base `notes-empty` only for a
   genuinely empty server list.
4. Mutation/reload: create, delete and reload re-apply the active query through
   the same render path; clear resets query/input/storage and focuses input.
5. State preservation: loading/error/401 behaviour and control disabling remain
   the f-v3 behaviour; search controls usable once loaded.
6. Accessibility: visible `<label for="notes-search">`, accessible name on the
   clear button, alert/status live regions unchanged.
7. OD-6: `sessionStorage` reload restore is an implementation convenience only;
   not asserted as contract.

## Commands planned

- `go test -count=1 -run TestUISemantics ./...`
- `go test -count=1 ./...`
- Supporting: `node --check web/app.js`, `go build ./...`, `go vet ./...`

## Out of scope

`main.go`, `main_test.go`, deploy scripts, auth/persistence changes, E2E run
against a preview stand (s20c), UI graph actualization (s21), and any framework
or dependency change.

## Exit criteria

Both required Go commands pass, all UI contract rows (`U-01..U-11`) are
accounted for, and the unit artifacts s11–s18 record evidence and a verdict.
