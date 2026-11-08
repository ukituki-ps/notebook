# M01 — Search end-to-end (milestone brief, s15)

- Execution: **E0809** · step **s15.brief_milestone** · role **planner**
- Branch: `dev/f-v4-note-search-e2e` · base `e6aeb44e`
- Process: `path-1.feature` 4.0.0 · platform `web` · profile `full`
- DS: Notebook DS 1.0.0 (`ds/v1.0.0`, digest `02f027a8…da3d`, `=1.0.0`)
- Specs: [core.md](../spec/core.md) · [contract-matrix.md](../spec/contract-matrix.md)
- Status: briefs only; no code/`web/`/`design/` edit at s15/s16, no commit.

## Milestone scope

Owner-scoped search over the existing notes API and notes web view:
`GET /api/notes?q=` (trim; empty/whitespace → all own; case-insensitive
substring; owner predicate before text predicate; 512-byte cap; `[]` not
`null`; `401` before query) plus the search UI (input/filter/clear, count,
retry, offline/offline-zero, zero-note disable, localized Delete), proven by Go
tests and 20 Playwright scenarios on `test2`. Auth, storage, note lifecycle and
the `{id,text}` wire model are unchanged.

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
`dev/f-v4-note-search-e2e` → `s20b` preview deploy `test2` only → `s20c` API
smoke + Playwright 20 scenarios + screenshots/`pngdiff` → `s21` actualize
`UI-GRAPH.yaml` from `web/` → `s22a` UI audit / `s22e` UX audit / `s22b`
red-team / `s22c` adversarial review → `s23` refinement → `s24` owner approval
(signed Nexus request via `orc_wait`). Platform and DS frozen until s24; s45/s46
skipped.

## DS 1.0.0 constraints (all units)

- Notebook DS 1.0.0 only (`ds/v1.0.0`, digest `02f027a8…da3d`, `=1.0.0`);
  12 registry components; **0 local instances and no local CSS**.
- **No Kubiki**, no second design system, no `frontend/src/ui/kit`, no new
  runtime dependency, bundler or CDN.
- Never edit `design/**` or DS files; the pinned digest must not change.
- path6 gaps stay accepted/non-blocking: **GAP-1** (`n-count`, missing count
  pattern), **GAP-3** (`n-delete`, danger delete variant omitted from registry),
  **GAP-2** (`primitives/input` disabled state missing).
- 390px: stacked search row, full-width 44px controls; 1200px: inline search +
  clear; no horizontal overflow.

## Blocker R-1 (U02/T0102 must fix)

`go test ./...` currently fails `TestUISemantics` at `web_ui_test.go:264`:
the oracle expects literal `min-height: 44px`, while `web/app.css` uses
`min-height: var(--control-height)` (`--control-height: 44px`). Align the oracle
to the DS token (or add a DS-compliant 44px height); **no DS edit**. The same
oracle must add `notes-search-count`, `notes-retry`, `notes-offline`,
`notes-offline-check`.

## Acceptance

- T0101: `go build ./...`, `go vet ./...`, `go test -count=1 ./...` green; all
  `TestNotesSearch*` including the exactly-512 accept case.
- T0102: `go test ./...` green incl. `TestUISemantics`; 0 DS violations/local
  instances; 390/1200 verified.
- T0103: 20/20 Playwright scenarios on `test2`, no skips/fixmes; per-scenario
  screenshot + `pngdiff`; API smoke incl. 512-byte `400`.
- Gates: s20a merged; s20b `test2` only; s20c 20/20 with 20/20 evidence; s21
  graph gate; s22a 0 DS violations; s22e/s22b/s22c accept; s24 owner approval +
  `ds-drift` clean.

## Out of scope

Auth/session/token/persistence; pagination/ranking/fuzzy/highlighting;
prod/main/stage/test1/canary; changes to `f-v3-auth-notes`, E4312 or E1320.
