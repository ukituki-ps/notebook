# Integration report — f-v4-note-search (E1688)

- Execution: `E1688` (path-1.feature@3.2.2, entry point `integrate`)
- Base (execution): `69d64e9d4e24a6901c469ba4ece34a4d41af2b6f`
- Work branch: `dev/f-v4-note-search-ae079e5c`
- Platform under test: dev `f6a5fcf1`; gate bundle
  `sha256:263c48a44e1abaaedb7378066cfe7fc831faade7bb5dc3418756a4eed15bf1e8`
- Contour: dev only, stand `test2`. Prod/preprod/test1/main untouched.

The `integrate` entry point starts at `s20a` without a new fan-out: the units
from the prior `s20.sde_execution` (E8895) are already merged into the work
branch. This report re-validates joint compatibility on the current base.

The evidence fix (per-scenario 240px colored banner → distinguishable
screenshots) is on the base (`69d64e9`).

## Units (already merged into base 69d64e9)

| Unit | Unit branch tip | State |
|---|---|---|
| notebook-search-api | `bc215d97e4185109a5de98f5fd77b495aefe1da1` | merged |
| notebook-search-ui | `5765aa6e8b0212474d4df6a436645edb40322fa1` | merged |
| notebook-search-deploy-e2e | `722e55ba5bb51829b31a73b6a76500de689e2cca` | merged |

Prior aggregate: `artifacts/units/integration-report.md` (E8895). RT-NEW-1/2/3
residual fixes are present on the base (`e0d41a0`).

## Joint compatibility (base 69d64e9)

- `GOWORK=off go build ./...` → exit 0
- `GOWORK=off go vet ./...` → exit 0
- `GOWORK=off go test -count=1 ./...` → ok

## Contract parity

- drift_count: **0**
- items: []
- divergent: []
- counts: model 0, code 0, drifted 0, baseline 0, delta 0

## Notes

- Deploy and live E2E are validated at `s20b`/`s20c` on `test2` (UI mode).
- No code changes in this step; artifact is the re-validation aggregate.
