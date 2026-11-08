# F-V4-NOTE-SEARCH — contract matrix

| endpoint | method | status | envelope | test |
|---|---|---|---|---|
| /api/notes | GET | 200 | `[]Note` (never null) | `go test ./... -run TestNotesList` |
| /api/notes?q= | GET | 200 | `[]Note` filtered by owner + case-insensitive substring | `go test ./... -run 'TestNotesSearchFinds|TestNotesSearchCaseInsensitive'` |
| /api/notes?q=<513+ bytes> | GET | 400 | `{"error":"query too long"}` | `go test ./... -run TestNotesSearchQueryTooLong` |
| /api/notes | GET (no bearer) | 401 | `{"error":"unauthorized"}` | `go test ./... -run 'TestAuthRequired|TestNotesSearchAuthRequired'` |
| /api/notes | POST | 201 | `Note` | `go test ./... -run TestAddNote` |
| /api/notes/{id} | DELETE | 204 | none | `go test ./... -run TestDeleteExisting` |
| /api/notes/{id} | DELETE (bad id) | 400 | `{"error":"invalid id"}` | `go test ./... -run TestDeleteInvalidID` |
| /api/notes/{id} | DELETE (missing) | 404 | `{"error":"not found"}` | `go test ./... -run TestDeleteMissing` |

## Edge cases

- Other users' notes are never returned (`TestNotesSearchIsolation`).
- Empty/whitespace q returns all own notes (`TestNotesSearchEmptyQuery`, `TestNotesSearchWhitespaceQuery`).
- URL-encoded/special chars decode safely (`TestNotesSearchEncoding`).
- Non-matching q returns 200 + `[]` (`TestNotesSearchNotFound`).
- Exactly 512 bytes is accepted; 513 bytes is 400.

## UI contract

- `notes-search`, `notes-search-clear`, `notes-search-count`, `notes-empty`, `notes-search-empty`, `notes-list`, `note-item`, `notes-loading`, `notes-error`, `notes-retry`, `notes-offline`, `notes-offline-check`.
- States: idle/results/no-results/empty/loading/error/offline/offline-zero.
- CR-01: stale GET after DELETE cannot resurrect; CR-02: 401 never references hidden notes-empty; CR-03: clear works offline.
