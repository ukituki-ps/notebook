# F-V4-NOTE-SEARCH — contract matrix

Source: [core.md](./core.md) §1, §3. Base: `main.go` at `406fa965`.
Tests are added at s20; full run: `go test -count=1 ./...` + Playwright.

| endpoint | method | status | envelope | test |
|---|---|---|---|---|
| /api/notes | GET | 200 | [{"id":N,"text":"..."}] all own notes when q absent | go test -count=1 -run TestNotesSearchFinds ./... |
| /api/notes?q=milk | GET | 200 | [{"id":N,"text":"..."}] case-insensitive matches only | go test -count=1 -run TestNotesSearchFinds ./... |
| /api/notes?q=MILK | GET | 200 | same as q=milk (case-insensitive) | go test -count=1 -run TestNotesSearchCaseInsensitive ./... |
| /api/notes?q=zzz | GET | 200 | [] (not null) when no match | go test -count=1 -run TestNotesSearchNotFound ./... |
| /api/notes?q= | GET | 200 | all own notes (empty query) | go test -count=1 -run TestNotesSearchEmptyQuery ./... |
| /api/notes?q=%20%20 | GET | 200 | all own notes (whitespace-only query) | go test -count=1 -run TestNotesSearchWhitespaceQuery ./... |
| /api/notes?q=milk | GET | 200 | only current user's notes (owner scope) | go test -count=1 -run TestNotesSearchIsolation ./... |
| /api/notes?q=a%26b%2Bc | GET | 200 | URL-encoded/special characters handled safely | go test -count=1 -run TestNotesSearchEncoding ./... |
| /api/notes?q=x | GET | 401 | {"error":"unauthorized"} + WWW-Authenticate: Bearer | go test -count=1 -run TestNotesSearchAuthRequired ./... |
| /api/notes | PUT | 405 | {"error":"method not allowed"} + Allow: GET, POST | go test -count=1 -run TestNotesMethodNotAllowed ./... |
| /api/notes | DELETE | 405 | {"error":"method not allowed"} + Allow: GET, POST | go test -count=1 -run TestNotesMethodNotAllowed ./... |
| /api/notes | POST | 201 | {"id":N,"text":"..."} unchanged | go test -count=1 -run TestAddNote ./... |
| /api/notes | POST | 400 | {"error":"text required"} unchanged | go test -count=1 -run TestAddNote ./... |
| /api/notes | POST | 401 | {"error":"unauthorized"} + WWW-Authenticate: Bearer | go test -count=1 -run TestAuthRequired ./... |
| /api/notes/{id} | DELETE | 204 | none (own note) unchanged | go test -count=1 -run TestDeleteNote ./... |
| /api/notes/{id} | DELETE | 400 | {"error":"invalid id"} unchanged | go test -count=1 -run TestDeleteInvalidID ./... |
| /api/notes/{id} | DELETE | 404 | {"error":"not found"} foreign/missing unchanged | go test -count=1 -run TestDeleteForeignNote ./... |
| /api/notes/{id} | GET | 405 | {"error":"method not allowed"} + Allow: DELETE | go test -count=1 -run TestNotesMethodNotAllowed ./... |
| /api/notes/{id} | PUT | 405 | {"error":"method not allowed"} + Allow: DELETE | go test -count=1 -run TestNotesMethodNotAllowed ./... |

## Negative and edge cases

- `q` absent, `q=`, `q=%20%20` → all own notes; no 400 (OD-1): `go test -count=1 -run 'TestNotesSearchEmptyQuery|TestNotesSearchWhitespaceQuery' ./...`
- `q=zzz` → 200 `[]`, not `null`, not 404: `go test -count=1 -run TestNotesSearchNotFound ./...`
- User B's note text matches `q` → not returned for user A: `go test -count=1 -run TestNotesSearchIsolation ./...`
- No/bad/expired bearer + `q` → 401 before query handling: `go test -count=1 -run TestNotesSearchAuthRequired ./...`
- `q=a%26b%2Bc`, `q=%E2%9C%93`, `q=%D0%BC%D0%BE%D0%BB%D0%BE%D0%BA%D0%BE` → decoded safely, no panic/500: `go test -count=1 -run TestNotesSearchEncoding ./...`
- `q` with mixed case vs stored text → matches: `go test -count=1 -run TestNotesSearchCaseInsensitive ./...`
- `q` longer than the note text / empty stored text → no match, 200 `[]`: `go test -count=1 -run TestNotesSearchNotFound ./...`
- After create/delete with an active query, the UI re-applies the filter and does not hide new/remaining notes: `playwright test web/e2e/notes-search.spec.js`
- Search empty state appears only for a non-empty query with no matches; `notes-empty` remains for an empty server list: `go test -count=1 -run TestUISemantics ./...`
