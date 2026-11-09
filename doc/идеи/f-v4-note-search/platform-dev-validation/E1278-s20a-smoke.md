# E1278 — s20a smoke (clean retry)

- Date: 2026-11-09T13:50Z
- Process: `path-1.feature@4.0.0`, entry `integrate`
- Execution: `E1278`
- Session: `ses_e3f73c1a8ffeQzwhsgFuFByRxi`
- Work branch: `dev/f-v4-note-search-clean`
- Base SHA: `39d08e40dae262bff2a4ef6c1ff6b1fdd6634dc5`
- Gate base ref: `39d08e40dae262bff2a4ef6c1ff6b1fdd6634dc5`
- `gate_bundle_digest`: `sha256:6e40186c4fe60222cb96e2a02fb136d93b3f266c4d9ff3208270421655adfb93`
- Evidence root: `/app/orc-repos/f41f0adb-67d9-4ddf-8ba9-0efd9c6e50a9/.orc-eval/E1278`
- test2 lease: `d23b925f-e16c-40ae-a4aa-57898fe2acbd`, active until `2026-11-09T15:48:04Z`
- E1868/E9275 were not resumed; this is a new execution.

## Purpose

Clean retry of the s20a → s20c smoke after E9275 stopped at s20b
(`check-run-artifacts` found E1868 per-run evidence tracked in the old
`dev/f-v4-note-search-smoke` branch). The clean branch removes that tracked
evidence and gitignores per-run artifacts; `check-run-artifacts` passes.

## Integration result

Units from E6177/E1868 are already merged in the base. `integrate` starts at
`s20a.unit_integrate`; no unit fan-out is re-run. This smoke adds only a
platform-validation document, so the integration delta is docs-only.

- Contract parity: 0 drift, no divergent items.
- Model/code delta: 0.
- Go build/vet/unit: pass.
- `gate-l2-integration`: expected PASS-NA — no changed Go files vs base.
- `tools/`, `deploy/`, `.orc-trust/` diff vs base: empty.

## Preflight evidence

| id | command | result |
|---|---|---|
| E1278-T1 | `go build ./...` | pass |
| E1278-T2 | `go vet ./...` | pass |
| E1278-T3 | `go test -count=1 ./...` | pass (`ok github.com/ukituki-ps/notebook 2.798s`) |
| E1278-T4 | `GATE_BASE_REF=39d08e4… bash tools/check-tools-untouched.sh` | OK, tools/deploy/.orc-trust unchanged |
| E1278-T5 | `bash tools/check-run-artifacts.sh .` | OK, per-run artifacts not tracked |
| E1278-T6 | `git diff --name-only 39d08e4…HEAD -- '*.go' tools deploy .orc-trust` | 0 files |

## Guardrails checked at start

- test2 lease active for E1278 (lease id above).
- No force, waiver, `na`, or step skip used.
- No SQL, container patch, or database operation performed.
- Gate bundle digest is the execution `gate_bundle_digest`; it is not
  substituted with a tools hash. `gate_tools_digest` is verified separately at
  deploy/verify time.
- No `main`, `prod`, or `test1` target.
- ORC creates the eval worktree from the pushed commit; no manual
  `git worktree add` is used for s20b/s20c.
- Stale ORC worktree registration `.clean-smoke` (path gone, branch
  `dev/f-v4-note-search-clean` still registered) was pruned with
  `git worktree prune`; no worktree or branch content was created or changed.

## Next

s20b preview deploy on test2, then s20c E2E on test2. Stop after s20c.
