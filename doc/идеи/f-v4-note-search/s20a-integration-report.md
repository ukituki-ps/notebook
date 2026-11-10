# s20a — unit integration report (E6636)

- **Execution:** `E6636` · process `path-1.feature@4.0.0` · step `s20a.unit_integrate`
- **Session:** `ses_ci_notebook_path10_15`
- **Work branch:** `dev/path10-runner-13`
- **Base SHA / gate base ref:** `9e7fae353c61e717505dc40019627a1d7ab48820`
- **Integrated HEAD:** `4428f6345388426fc7e0dc50dc36ce0bb2ad9943` (before this report commit)
- **Feature:** `f-v4-note-search` (`doc/идеи/f-v4-note-search`), profile `full`, platform `web`
- **Feature dir:** `doc/идеи/f-v4-note-search`

## Units integrated (s20 fan-out → done 3/3, failed 0, new_findings 0)

| Unit | Domain | SDE | Verdict (s17) | Merge |
|---|---|---|---|---|
| `notebook-search-api` | `notebook-api` | `sde-backend` | clean | `8e26bc9` (u01) |
| `notebook-search-ui` | `notebook-web` | `sde-frontend` | clean | `6789993` (u02, ff) |
| `notebook-search-deploy-e2e` | `notebook-e2e` | `sde-infra` | clean | `80f5aec` (u03) |

- Child executions: `E6636-s20.sde_5fexecution-u01`, `…-u02`, `…-u03` — all `done`.
- Machine merge docs: `4428f63` (u03 on top of `c1e795b`/`80f5aec`).
- Conflicts: none (disjoint changed-file sets).
- All three units had `fixed_confirmed=true`, `crutch_density_grew=false`,
  `new_findings=[]`, `synced=true` (C-14 machine outcome).

## Code delta vs base (`9e7fae3..4428f63`)

Only `main_test.go` changed in product code: **+47 lines / 3 tests** from u01
(`TestNotesSearchTrimsQuery`, `TestNotesSearchEmptyStore`,
`TestNotesSearchDoesNotMatchOtherOwner`). `main.go`, `web/index.html`,
`web/app.js`, `web/app.css`, `web_ui_test.go`, `web/e2e/notes-search.spec.js`,
`deploy/path1/e2e-preview.sh` and `scenarios.json` are byte-identical to base:
at `9e7fae3` the feature is already implemented, so u02/u03 converged
verify-only and u01 added the three missing contract tests. Remaining diff is
process artifacts (`artifacts/units/**`, `doc/идеи/f-v4-note-search/**`,
`arch/frontend/pages/note-search.yaml`).

## Integrated verification (all on the integrated tree)

| Gate | Command | Result | Evidence |
|---|---|---|---|
| L0 build | `GOWORK=off go build ./...` | PASS | `PR-3513fa88d729` |
| L0 vet | `go vet ./...` | PASS | `PR-3513fa88d729` |
| L1 unit (CI-eq) | `go test -count=1 ./...` | `ok github.com/ukituki-ps/notebook 8.819s` | `PR-3513fa88d729` |
| L1 unit gate | `bash tools/gate-l1-unit.sh` | PASS (all tests green) | `PR-404920fec43c` |
| L1 lint | `golangci-lint` | N/A — no `.golangci.y(a)ml` in repo | — |
| L1 typecheck | `tsc --noEmit` | N/A — no `nexus-ui/tsconfig.json` / `frontend/tsconfig.json` | — |
| L1 tools | `bash tools/check-tools-untouched.sh` | OK — `tools/`, `deploy/`, `.orc-trust/` unchanged vs base | `PR-e02794444b43` |
| L1 DS usage | `bash tools/path1-gate.sh ds-usage E6636` | PASS | `PR-b91fdd117994` |
| L1 storybook | `storybook/gate-storybook.mjs` | N/A — no storybook gate in repo | — |
| L2 shared contract | `openapi/common.yaml` | N/A — canon at `doc/спецификация/lead-domain/openapi.yaml` | — |
| L2 integration (stand) | `ORC_BASE_SHA=9e7fae3… bash tools/check-integration-on-stand.sh E6636` | OK — real API smoke against leased **test2** (`https://test2.nexus.ukituki.tech`, build `4347f16`) | `PR-472be5ac6bb2` |

Stand integration smoke (real network, leased stand), all green: unauth GET
`/api/notes` → 401 + `WWW-Authenticate: Bearer`; register/login A; POST note A
→ 201; `GET /api/notes?q=textA` → 200 with the note; `q=no-match` → 200 `[]`;
`q=512 bytes` → 200; `q=513 bytes` → 400 `query too long`; B cannot see A's
note (owner predicate before text predicate); DELETE own → 204, repeat → 404,
`/api/notes/abc` → 400, unauth DELETE → 401. Playwright is deliberately not
run here; UI runtime proof is the s20c obligation.

## Contract parity

`drift_count = 0`, `items = []`. The matrix in
`doc/идеи/f-v4-note-search/spec/contract-matrix.md` has 10 rows + 8 edge
cases + UI contract; every `test` ref resolves to an existing test
(`TestNotesLifecycle`, `TestNotesSearchFinds`, `TestNotesSearchCaseInsensitive`,
`TestNotesSearchTrimsQuery`, `TestNotesSearchEmptyQuery`,
`TestNotesSearchWhitespaceQuery`, `TestNotesSearchQueryTooLong`,
`TestAuthRequired`, `TestNotesSearchAuthRequired`, `TestAddNote`,
`TestDeleteExisting`, `TestDeleteInvalidID`, `TestDeleteMissing`,
`TestNotesSearchIsolation`, `TestNotesSearchDoesNotMatchOtherOwner`,
`TestNotesSearchEncoding`, `TestNotesSearchNotFound`,
`TestNotesSearchEmptyStore`, `TestUISemantics`) and the whole suite is green.
The s16 unit spec-sync drift (`TestNotesList` → `TestNotesLifecycle`) is fixed.
No OpenAPI modules are used by this app repo; no removed/renamed wire field and
no status-code change for existing requests without `q`.

## Model drift

`counts = {baseline: 0, model: 0, code: 0, drifted: 0, delta: 0}`,
`divergent = []`. No model files and no model-bearing code changed since base
(`main.go` untouched; `doc/спецификация/**/openapi.yaml` untouched), so the
ratchet (`max_delta: 0`) holds trivially.

## Invariants

`INV-UI-E2E-PREVIEW` is `proposed` at this base, so
`require_test_ref_for: active` does not demand per-run E2E evidence at s20a.
All `active` invariant test refs are green locally (`TestUISemantics`,
`TestAuthRequired`, `TestNotesSearchIsolation`, `TestNotesSearchEncoding`, …).
`INV-SEARCH-UI-FILTER` / `-EMPTY` / `-TESTIDS` are `active` and their
`test_ref` (`go test -run TestUISemantics`) passes; their runtime confirmation
is s20c.

## Scope truthfulness

- test2 is the only stand touched; prod, `main` and test1 untouched.
- No force, waiver, `na`, step skip, SQL, container or DB patch.
- `main.go`, `web/**`, `deploy/**`, `design/**`, `tools/**` unchanged vs base.
- Runtime UI evidence (20/20 Playwright, screenshots, pngdiff) is **not**
  claimed here — it is the s20c obligation on the deployed preview.

## Next

`s20b.preview_deploy` on test2, then `s20c.preview_verify` (Playwright 20/20 +
scenario evidence).

## History (previous executions, unchanged)

### E6177

- Base `74d6cec`, branch `dev/f-v4-note-search-fix`; same three units.
- Verification: `go test ./...` ok; 30/30 Playwright local; `ds-token-drift` PASS.
- Regression fixed in u03: `deploy/path1/e2e-preview.sh` gained search smoke.

### E6469

- Gate base corrected to `74d6cec`; tools diff empty; test2 lease `8371bd14…`.

### E2727

- Rerun on deploy `905993c2`; test2 lease `f2f58b83…`.

### E1868

- Gate base = context.base_sha `865fd23`; tools unchanged vs `9b972e6`.
