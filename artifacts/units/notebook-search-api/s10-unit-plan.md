# s10 unit plan — notebook-search-api

- Feature: `f-v4-note-search`
- Execution: `E8363-s20.sde_5fexecution-u01`
- Unit: `notebook-search-api` (domain `notebook-api`, SDE `sde-backend`)
- Worktree: `/workspace/projects/notebook-e8363-u01`
- Branch: `orc-exec-E8363-s20.sde_5fexecution-u01`
- Base/HEAD at plan time: `9ceafdbd1bede428097d784539093092d0c9156f`
- Change class: `plain`; feature profile `full`
- Inputs: `doc/идеи/f-v4-note-search/feature-brief.md`,
  `change-definition.md`, `spec/core.md`, `spec/contract-matrix.md`,
  `T0001/brief.md`, `T0002/brief.md`, `T0003/brief.md`, `T0004/brief.md`,
  `main.go`, `main_test.go`.

## Objective

Confirm and, only if required, complete the `GET /api/notes?q=` search
implementation in `main.go` and its backend oracles in `main_test.go`, without
touching auth, storage, status codes, envelopes, or note lifecycle.

## Contract to verify

1. `q` is read from the query string (`r.URL.Query().Get("q")`) and trimmed with
   `strings.TrimSpace`.
2. Absent / empty / whitespace-only `q` returns all notes of the authenticated
   user.
3. Non-empty `q` returns only the caller's notes whose `Text` contains `q` as a
   substring, case-insensitively (`strings.ToLower` on both sides).
4. The owner predicate runs first (`ListNotes(session.UserID)`), so the filter
   can only narrow the scope.
5. No matches returns `200` with exactly `[]`, never `null`.
6. Missing/invalid bearer returns `401 {"error":"unauthorized"}` plus
   `WWW-Authenticate: Bearer` before method/query handling.
7. Existing status codes and JSON envelopes for `POST/DELETE/register/login`,
   method-not-allowed, unknown API paths, and wire keys `id`/`text` stay
   unchanged; `UserID` never serializes.

## Planned steps

1. Re-read `main.go` / `main_test.go` at HEAD and map each contract clause to the
   handler code and to a named test.
2. Run `go build ./...`, `go vet ./...`, `go test -count=1 ./...` from the
   worktree. If anything fails, minimally fix within `main.go` / `main_test.go`
   and re-run; no auth/storage/status/envelope changes.
3. Run the focused search suite plus existing guard tests
   (`TestAuthMethodOrder`, `TestAuthRequired`, `TestNotesIsolation`,
   `TestNotesMethodNotAllowed`, `TestWireContract`, `TestHTTPTransport`,
   `TestUISemantics`) with `-v`.
4. Record evidence and stage verdicts under
   `artifacts/units/notebook-search-api/`.

## Evidence plan

- Commands and exit codes: `s12-check.md`, `s11-execution.md`.
- Contract/test mapping: `s16-spec-sync.md`.
- Regression surface: `s15-regression.md`.
- Independent-verification input (HEAD, worktree, commands): `s13-verify-input.md`.
- Final result: `s17-verdict.md`, `s18-unit-report.md`.

## Out of scope

Auth/session/token, persistence, new dependencies or build tags, changes to
`POST/DELETE`, deploy/E2E work owned by other units, and all git write commands
(the coordinator commits).
