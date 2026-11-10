# M01 — Search end-to-end (milestone brief, s15)

- Execution: **E6636** · step **s15.brief_milestone** · role **planner**
- Branch: `dev/path10-runner-13` · base `9e7fae353c61e717505dc40019627a1d7ab48820`
- Process: `path-1.feature` 4.0.0 · platform `web` · profile `full`
- DS: Notebook DS **1.0.1** (`ds/v1.0.1`, digest
  `sha256:4e0ef1052a1401a928588445f921f7d231b7c0e7c9b10c181fdbbb439108c85e`,
  `=1.0.1`)
- Inputs: [plan.md](../plan.md) (s13 saved, model v2 approved),
  [change-definition.md](../change-definition.md) (s10 model v2 approved),
  [spec/core.md](../spec/core.md), [contract-matrix.md](../spec/contract-matrix.md),
  [UI-GRAPH.planned.yaml](../UI-GRAPH.planned.yaml).
- Status: briefs only; no code/`web/`/`design/` edit at s15/s16.

## Milestone scope

Owner-scoped search over the existing notes API and notes web view:
`GET /api/notes?q=` (trim; empty/whitespace → all own; case-insensitive
substring; owner predicate before text predicate; 512-byte cap; `[]` not
`null`; `401` before query) plus the search UI (input/filter/clear, count,
retry, offline/offline-zero, zero-note disable, localized Delete), proven by Go
tests and 20 Playwright scenarios (+ CR-01..CR-03 regressions) on `test2`.
Auth, storage, note lifecycle and the `{id,text}` wire model are unchanged.

At base `9e7fae35` the API and UI surface already carry this contract; the
units below re-verify it against the spec, fix drift only, and produce the
required evidence.

## Units (s20 fan-out = exactly 3 child executions)

| Unit | Task | Domain | SDE | Class | Files |
|---|---|---|---|---|---|
| `notebook-search-api` | T0101 | notebook-api | sde-backend | plain | `main.go`, `main_test.go` |
| `notebook-search-ui` | T0102 | notebook-web | sde-frontend | plain | `web/index.html`, `web/app.js`, `web/app.css`, `web_ui_test.go` |
| `notebook-search-deploy-e2e` | T0103 | notebook-e2e | sde-infra | plain | `web/e2e/notes-search.spec.js`, `deploy/path1/e2e-preview.sh`, `scenarios.json`, `scenario-evidence.json` |

Each child gets a distinct `session_id`; the parent receives only
summary/diff/verdict. Unit briefs T0101–T0103 are ≤80 lines each.

## Dependencies / execution order

`s19` lease `test2` → `s20` 3 units (T0101/T0102/T0103) → `s20a` integrate on
`dev/path10-runner-13` → `s20b` preview deploy `test2` only → `s20c` API
smoke + Playwright 20 scenarios + screenshots/`pngdiff` → `s21` actualize
`UI-GRAPH.yaml` from `web/` → `s22a` UI audit / `s22e` UX audit / `s22b`
red-team / `s22c` adversarial review → `s23` refinement → `s24` owner approval
(signed Nexus request via `orc_wait`). Platform and DS frozen until s24; s45/s46
skipped.

## DS 1.0.1 constraints (all units)

- Notebook DS **1.0.1** only (`ds/v1.0.1`, digest `4e0ef105…c85e`, `=1.0.1`);
  12 registry components; **0 local instances and no local CSS**.
- **No Kubiki**, no second design system, no `frontend/src/ui/kit`, no new
  runtime dependency, bundler or CDN.
- Never edit `design/**` or DS files; the pinned digest must not change.
- path6 gaps stay accepted/non-blocking: **GAP-1** (`n-count`, missing count
  pattern), **GAP-3** (`n-delete`, danger delete variant omitted from registry),
  **GAP-2** (`primitives/input` disabled state missing), **GAP-4**
  (utility-class registry omissions).
- 390px: stacked search row, full-width 44px controls; 1200px: inline search +
  clear; no horizontal overflow.

## R-1 status (closed at base)

`TestUISemantics` now asserts the DS token `min-height: var(--control-height)`
and `--control-height: 44px` (`web_ui_test.go:360-365`, `web/app.css:14`).
U02/T0102 keeps the token form and must not reintroduce a literal
`min-height: 44px` oracle; **no DS edit**. The oracle already references
`notes-search-count`, `notes-retry`, `notes-offline`, `notes-offline-check`.

## Acceptance

- T0101: `go build ./...`, `go vet ./...`, `go test -count=1 ./...` green; all
  `TestNotesSearch*` including the exactly-512 accept case.
- T0102: `go test ./...` green incl. `TestUISemantics`; 0 DS violations/local
  instances; 390/1200 verified.
- T0103: 20/20 Playwright scenarios + CR-01..CR-03 on `test2`, no
  skips/fixmes; per-scenario screenshot + `pngdiff`; API smoke incl. 512-byte
  `400`.
- Gates: s20a merged; s20b `test2` only; s20c 20/20 with 20/20 evidence; s21
  graph gate; s22a 0 DS violations; s22e/s22b/s22c accept; s24 owner approval +
  `ds-drift` clean.

## Out of scope

Auth/session/token/persistence; pagination/ranking/fuzzy/highlighting;
prod/main/stage/test1/canary; changes to `f-v3-auth-notes`, E4312 or E1320.
