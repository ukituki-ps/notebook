# T0001 — notebook-search-api (s16 unit brief)

- Unit: `notebook-search-api`
- Domain: `notebook-api`
- SDE: `sde-backend`
- Change class: `plain`
- Files: `main.go`, `main_test.go`

## Scope

1. Extend `GET /api/notes` with optional `q`: `r.URL.Query().Get("q")`,
   `strings.TrimSpace`, empty/whitespace → all own notes.
2. Non-empty `q` → case-insensitive substring filter over the current user's
   notes (`strings.ToLower` on both sides); never widen the owner scope.
3. Keep auth order and all existing status codes/envelopes unchanged; `[]` not
   `null`; `UserID` not serialized.
4. Add tests: find, not-found, case-insensitive, isolation (A/B), 401,
   empty/whitespace, URL-encoding/special characters.

## Acceptance oracles

- `go build ./...`, `go vet ./...`, `go test -count=1 ./...`
- `TestNotesSearchFinds`, `TestNotesSearchNotFound`,
  `TestNotesSearchCaseInsensitive`, `TestNotesSearchIsolation`,
  `TestNotesSearchAuthRequired`, `TestNotesSearchEmptyQuery`,
  `TestNotesSearchWhitespaceQuery`, `TestNotesSearchEncoding`
- Existing `TestAuthRequired`, `TestNotesIsolation`, `TestDeleteNote`,
  `TestNotesMethodNotAllowed`, `TestWireContract` stay green.

## Forbidden

Auth/session/token changes, persistence, new dependencies, build tags,
changing existing status codes/envelopes.
