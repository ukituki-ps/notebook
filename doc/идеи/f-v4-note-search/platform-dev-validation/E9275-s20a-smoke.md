# E9275 — s20a smoke (dev ORC 7d155eee, gate bundle 6e40186c)

- Date: 2026-11-09T13:35Z
- Process: `path-1.feature@4.0.0`, entry `integrate`
- Dev ORC platform: `7d155eee`
- Base process snapshot at start: `c38bed4`
- Execution: `E9275`
- Session: `ses_e3f7f721bffevF6thh6C495UvW`
- Work branch: `dev/f-v4-note-search-smoke`
- Base SHA: `6620dcb81dce67523a453226f09c75d8ef5d9653`
- Gate base ref: `6620dcb81dce67523a453226f09c75d8ef5d9653`
- `gate_bundle_digest`: `sha256:6e40186c4fe60222cb96e2a02fb136d93b3f266c4d9ff3208270421655adfb93`
- Evidence root: `/app/orc-repos/f41f0adb-67d9-4ddf-8ba9-0efd9c6e50a9/.orc-eval/E9275`
- test2 lease: `8b768200-b026-4930-a56a-a4aece4427e0`, active until `2026-11-09T15:32:09Z`
- E1868 was completed and was not resumed; this is a new execution.

## Smoke scope

s20a → s20b → s20c only. s22b/s24 are out of scope for this decision.

## Integration result

Units from E6177/E1868 are already merged in the base. `integrate` starts at
`s20a.unit_integrate`; no unit fan-out is re-run. This smoke adds only a
platform-validation document, so the integration delta is docs-only.

- Contract parity: 0 drift, no divergent items.
- Model/code delta: 0.
- Go build/vet/unit: pass.
- `gate-l2-integration`: expected PASS-NA — no changed Go files vs base.
- `tools/` and `deploy/` diff vs base: empty.

## Preflight evidence

| id | command | result |
|---|---|---|
| E9275-T1 | `go build ./...` | pass |
| E9275-T2 | `go vet ./...` | pass |
| E9275-T3 | `go test -count=1 ./...` | pass (`ok github.com/ukituki-ps/notebook 2.789s`) |
| E9275-T4 | `bash tools/check-tools-untouched.sh` with `GATE_BASE_REF=6620dcb...` | OK, tools/deploy/.orc-trust unchanged |
| E9275-T5 | `git diff --name-only 6620dcb...HEAD -- tools/` | 0 files |

## Guardrails checked at start

- test2 lease active for E9275 (see lease id above).
- No force, waiver, or `na` used.
- No SQL, container patch, or database operation performed.
- Gate bundle digest is the execution `gate_bundle_digest`; it is not
  substituted with a tools hash. `gate_tools_digest` is verified separately at
  deploy/verify time and must not silently replace it.
- No `main`, `prod`, or `test1` target.
- Eval worktree is created by ORC from the pushed commit; no manual
  `git worktree add` is used for s20b/s20c.

## Next

s20b preview deploy on test2, then s20c E2E on test2.
