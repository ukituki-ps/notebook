# Task briefs — f-v4-note-search (s16.brief_tasks)

- **Step:** `s16.brief_tasks`
- **Execution:** `E8363`
- **Feature:** `f-v4-note-search`
- **Platform:** `web` (`feature_profile = full`)
- **Branch (this pass):** `dev/f-v4-note-search-validation-zero`
- **Base:** `5935e148` (`5935e148584b5fef28bd77ac4e45b800f10da03b`)
- **Pass type:** fresh E8363 re-validation; briefs added for the planned tasks
  that had none.

## Verdict

**PASS** — every planned task `T0001`–`T0010` now has a brief path, all seven
new briefs (`T0004`–`T0010`) follow the T0001–T0003 format, and file ownership
matches the unit boundaries and the s10/s14 corrections. One non-blocking
legacy-brief caveat is recorded below; it does not affect the plan coverage.

## Counts and coverage

| Item | Count |
|---|---|
| Planned tasks | 10 (`T0001`–`T0010`) |
| Briefs present | 10 (3 pre-existing + 7 created) |
| Missing briefs before this step | 7 (`T0004`–`T0010`) |
| Units | 3 (`U01`, `U02`, `U03`) |

| Task | Unit | Files | Primary oracle | Brief |
|---|---|---|---|---|
| T0001 | U01 `notebook-search-api` | `main.go` | `TestNotesSearchFinds`, `TestNotesSearchCaseInsensitive` | pre-existing (unit-level) |
| T0002 | U01 | `main.go` | `TestNotesSearchEmptyQuery`, `TestNotesSearchWhitespaceQuery` | pre-existing (unit-level) |
| T0003 | U01 | `main.go`, `main_test.go` | `TestNotesSearchIsolation`, `TestNotesSearchAuthRequired` | pre-existing (unit-level) |
| T0004 | U01 | `main_test.go` | `TestNotesSearchNotFound`, `TestNotesSearchEncoding` | created |
| T0005 | U02 `notebook-search-ui` | `web/index.html`, `web/app.css` | `TestUISemantics` | created |
| T0006 | U02 | `web/app.js` | `TestUISemantics`, `SEARCH-E2E-1..6` | created |
| T0007 | U02 | `web_ui_test.go` | `TestUISemantics` | created |
| T0008 | U03 `notebook-search-deploy-e2e` | `web/e2e/notes-search.spec.js` | `SEARCH-E2E-1..6` | created |
| T0009 | U03 | `deploy/path1/e2e-preview.sh`, `path1.project.json` | `E2E_API_ONLY=1` auth/notes smoke | created |
| T0010 | U03 | `doc/идеи/f-v4-note-search/UI-GRAPH.yaml` | s21 graph gate | created |

## Ownership check

- **U01 — T0004 only `main_test.go`:** test-only task; no production edits, real
  HTTP transport, not-found/encoding oracles.
- **U02 — T0005 `web/index.html` + `web/app.css`:** markup/testids and styling
  only. T0006 `web/app.js`: filter/clear/empty/re-render behaviour. T0007
  `web_ui_test.go`: static semantics oracle. No cross-unit file leakage.
- **U03 — T0008 `web/e2e/notes-search.spec.js`:** exactly six search scenarios.
  T0009 `deploy/path1/e2e-preview.sh` + `path1.project.json`: auth/notes-only
  integration smoke and adapter config, no `q=` smoke. T0010 `UI-GRAPH.yaml`:
  code actualization at s21.

## Format conformance and corrections

Each created brief has the T0001–T0003 structure: title, unit, domain, SDE,
change class, files, `## Scope`, `## Acceptance oracles`, `## Forbidden`.

The briefs embed the s10/s14 corrections:

- **T0004** covers not-found (`200 []`, never `null`) and encoding via the real
  transport, matching `INV-SEARCH-NOT-FOUND` / `INV-SEARCH-ENCODING`.
- **T0005/T0006** state the full search-empty guard
  (`hasQuery && !noNotes && visible.length === 0`), keep `notes-empty` separate,
  and label `sessionStorage` restore as OD-6 convenience only.
- **T0008** names the six actual scenarios (find, not-found, case, clear,
  create-active, delete-active) and excludes user-B isolation from this spec.
- **T0009** keeps the integration smoke auth/notes-only and puts search E2E in
  the s20c full Playwright run.
- **T0010** requires a from-code graph at s21, not a design rewrite.

## Legacy-brief caveat (non-blocking)

`T0001`–`T0003/brief.md` are unit-level briefs from the prior 3-unit structure,
not task-scoped briefs for plan tasks T0001–T0003. In particular,
`T0003/brief.md` still carries pre-s10 wording (search find/not-found in the
stand API smoke and user-B isolation in the search spec). Those claims are
superseded by the s10 change definition and the new `T0008`/`T0009` task briefs;
`plan.md` and the new briefs are authoritative for E8363. Per the step
instruction, only the missing `T0004`–`T0010` briefs were created, so the legacy
files were not rewritten.

## Files created

- `doc/идеи/f-v4-note-search/T0004/brief.md`
- `doc/идеи/f-v4-note-search/T0005/brief.md`
- `doc/идеи/f-v4-note-search/T0006/brief.md`
- `doc/идеи/f-v4-note-search/T0007/brief.md`
- `doc/идеи/f-v4-note-search/T0008/brief.md`
- `doc/идеи/f-v4-note-search/T0009/brief.md`
- `doc/идеи/f-v4-note-search/T0010/brief.md`
- `doc/идеи/f-v4-note-search/platform-dev-validation-zero/s16-tasks.md` (this review)

## Limitations

- No git commands were run; verification is against the working tree at this
  head.
- The legacy `T0001`–`T0003` briefs and historical execution IDs elsewhere were
  not re-stamped.
- No source, spec, graph, path-1, auth, or persistence file was modified at s16.

## Acceptance stamp (s16)

Accepted for E8363 on branch dev/f-v4-note-search-validation-zero.
Task briefs T0001-T0010 are complete; unit_briefs for U01/U02/U03 are bound
into the execution context for the s20 fan-out.
