# E0722 — s20a unit integrate (new clean run from 0)

- Date: 2026-11-09
- Execution: **E0722** (new; `E1763` / `E1278` / `E9275` not resumed; `E1868` archived)
- Process: `path-1.feature@4.0.0`, entry `integrate`, `orc_start_from=s20a.unit_integrate`
- Work branch: `dev/f-v4-note-search-clean-v2`
- Base SHA: `9e7fae353c61e717505dc40019627a1d7ab48820`
- Platform dev: `e6599c2f553dd1025cb249d408e8a1a9f4f95fa0`
- Gate bundle: `sha256:663b4a27edb3dde900d9724f62398a6ca3360efab5fd1d3129f5cc6d911f0d91`
- Eval root: `/app/orc-repos/f41f0adb-67d9-4ddf-8ba9-0efd9c6e50a9/.orc-eval/E0722`
- test2 lease: `7206139d-27aa-43fe-8d45-e601c9a07d1c` (active `14:39:47Z → 17:39:47Z`)
- Execution transport: `git`

## Preflight

| check | result |
|---|---|
| ORC dev `e6599c2f` | confirmed (`/version`) |
| gate bundle `663b4a27…` | confirmed (execution status `gate_bundle_digest`) |
| branch tip `9e7fae3` | confirmed (`git rev-parse HEAD`) |
| `INV-UI-E2E-PREVIEW` proposed | confirmed (1 proposed; 19 active) |
| `check-run-artifacts` | PASS |
| tools / deploy / .orc-trust untouched vs `9e7fae3` | PASS |

`gate_tools_digest == gate_bundle_digest` is the expected platform value, not a defect.

## Integration result

- Active invariants: **19/19** `test_ref` executed and green:
  AUTH-REQUIRED, USER-ISOLATION, SEARCH-OWNER-SCOPE, SEARCH-CASE-INSENSITIVE,
  SEARCH-EMPTY-Q, SEARCH-NOT-FOUND, SEARCH-ENCODING, SEARCH-Q-MAX, WIRE-CASING,
  REAL-TRANSPORT, NO-SKIP-TAGS, UI-TRUTH, UI-LABEL, UI-A11Y-NAME, UI-ORACLE,
  XSS-ESCAPE, SEARCH-UI-FILTER, SEARCH-UI-EMPTY, SEARCH-UI-TESTIDS.
- Proposed: `INV-UI-E2E-PREVIEW` only. It is **not** activated in this step.
- `go build ./...`, `go vet ./...`, `go test -count=1 ./...`: green.
- `tools/gate-l1-unit.sh`: PASS.
- Docs-only increment: `gate-l2-integration` is PASS-NA (no `.go` changes vs base).
- No source, invariant, evidence, gate, or design-system edits were made in this step.

## Contract parity

- drift: `0`; divergent: `0`.
- counts: baseline `0`, code `0`, delta `0`, drifted `0`, model `0`.

## Evidence

| id | command | result |
|---|---|---|
| E-S20A-BUILD | `go build ./... && go vet ./... && go test -count=1 ./...` | PASS |
| E-S20A-L1 | `bash tools/gate-l1-unit.sh` | PASS |
| E-S20A-INV | 19 active invariant `test_ref` commands | 19/19 PASS |
| E-S20A-TOOLS | `bash tools/check-tools-untouched.sh` | PASS |
| E-S20A-ART | `bash tools/check-run-artifacts.sh .` | PASS |

Note: the ORC host shared checkout at `/app/orc-repos/<project>` is a platform branch
(`c38bed40`), not the evaluation tree. Canonical gate execution is performed by ORC in
the eval worktree materialized from `9e7fae3` / this commit.

## Verdict

s20a accepted: integration green, 19/19 active invariants enforced, E2E invariant still
`proposed`, per-run artifacts untracked, no force / waiver / `na` / skip used.
