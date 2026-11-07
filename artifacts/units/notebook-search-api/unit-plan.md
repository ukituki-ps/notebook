# Unit plan — notebook-search-api (E1546 s20, u01)

- **Unit:** notebook-search-api (domain notebook-api, sde-backend, change_class plain)
- **Base:** 11b752cd32ba34e15ffd7f1a4d93a6d612614528
- **Files:** main.go, main_test.go

## Scope

`GET /api/notes?q=` — optional, trimmed, case-insensitive substring over note
text, owner-scoped (`Note.UserID == session.UserID`), `[]` not `null`,
401 before query handling. No auth/storage changes.

## Tasks / oracles

| # | Task | Oracle |
|---|---|---|
| 1 | Store/List search helper | TestNotesSearchFinds, TestNotesSearchCaseInsensitive |
| 2 | GET handler q parsing/trim | TestNotesSearchEmptyQuery, TestNotesSearchWhitespaceQuery |
| 3 | owner scope + auth order | TestNotesSearchIsolation, TestNotesSearchAuthRequired |
| 4 | tests find/not-found/encoding | TestNotesSearchNotFound, TestNotesSearchEncoding |

## Verify

`go build ./...`, `go vet ./...`, `go test -count=1 ./...` (search invariants).
The implementation already exists at the unit base; the unit verifies it and
records evidence without changing auth/persistence.
