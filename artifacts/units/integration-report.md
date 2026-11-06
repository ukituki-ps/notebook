# Integration report — f-v4-note-search (E8895)

- Execution: `E8895` (path-1.feature@3.2.2, entry `unit_batch`)
- Base: `326ae62fce7d6513c2b389750b4f5ebed278d861`
- Work branch: `dev/f-v4-note-search-ae079e5c`
- Integration head before this report commit: `c84bafdb576d3dbf7b98e78905d2faf33551a5e0`
- Platform under test: `ae079e5cadd9398d29457d31213757ae67bdd52d`

## Units merged

| Unit | Unit branch tip | Merge into feature branch |
|---|---|---|
| notebook-search-api | `bc215d97e4185109a5de98f5fd77b495aefe1da1` | `734030dc` |
| notebook-search-ui | `5765aa6e8b0212474d4df6a436645edb40322fa1` | `734030dc` |
| notebook-search-deploy-e2e | `722e55ba5bb51829b31a73b6a76500de689e2cca` | `c84bafd` |

## Verification at integration head (`c84bafd`)

- `GOWORK=off go build ./...` → exit 0
- `GOWORK=off go vet ./...` → exit 0
- `GOWORK=off go test -count=1 ./...` → ok, 32 tests
- Search API: `q` trim, empty/whitespace = all own notes, case-insensitive
  owner-scoped filter, `[]` not null, `UserID` hidden, auth order unchanged.
- Search UI: `notes-search`, `notes-search-clear`, `notes-search-empty`; single
  `renderNotes()` path; create/delete/reload re-apply the query.
- E2E: `web/e2e/notes-search.spec.js` (6 scenarios); `UI-GRAPH.yaml` actualized.

## Contract parity

- drift_count: **0**
- items: []
- divergent: []
- counts: model 0, code 0, drifted 0, baseline 0, delta 0

## Residual notes

- `web/e2e` Playwright live run is deferred to s20c on the deployed stand.
- No deploy scripts, package/lock, auth, storage, or status/envelope changes.
