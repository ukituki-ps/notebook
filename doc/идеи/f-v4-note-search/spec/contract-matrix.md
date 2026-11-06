# F-V4-NOTE-SEARCH — contract matrix

- Execution: **E8363**, step **s14.spec_generation**
- Branch: `dev/f-v4-note-search-validation-zero`, base `5935e148`
- Source: [core.md](./core.md) §1, §3; code at this head (`main.go`,
  `main_test.go`, `web/*`, `web_ui_test.go`, `web/e2e/*`).
- Oracles already exist at this head; full run:
  `go build ./... && go vet ./... && go test -count=1 ./...` +
  `npx --no-install playwright test`.
- Contract rows: **30 API** (`C-01..C-30`) + **11 UI** (`U-01..U-11`) = **41**.
  Every row has an executable oracle; `drift_count = 0`.
- `sessionStorage` `notebook.search` reload-restore is **not** a row: OD-6
  implementation convenience, not contract.

## API rows

| id | endpoint | method | status | envelope | test |
|---|---|---|---|---|---|
| C-01 | /api/notes | GET | 200 | all own notes when `q` absent; `[]` not `null` | `go test -count=1 -run TestNotesSearchEmptyQuery ./...` |
| C-02 | /api/notes?q=milk | GET | 200 | case-insensitive substring; only matching own notes | `go test -count=1 -run TestNotesSearchFinds ./...` |
| C-03 | /api/notes?q=HeLLo | GET | 200 | same result as lower-case query (case-insensitive) | `go test -count=1 -run TestNotesSearchCaseInsensitive ./...` |
| C-04 | /api/notes?q=absent | GET | 200 | `[]` (not `null`), never 404 | `go test -count=1 -run TestNotesSearchNotFound ./...` |
| C-05 | /api/notes?q= | GET | 200 | all own notes (empty query) | `go test -count=1 -run TestNotesSearchEmptyQuery ./...` |
| C-06 | /api/notes?q=%20%20%09 | GET | 200 | all own notes (whitespace-only query, OD-1) | `go test -count=1 -run TestNotesSearchWhitespaceQuery ./...` |
| C-07 | /api/notes?q=shared | GET | 200 | owner-scoped; user B's matching note not returned | `go test -count=1 -run TestNotesSearchIsolation ./...` |
| C-08 | /api/notes?q=<encoded> | GET | 200 | URL-encoded `%`, space, `&`, `+` decoded safely, no panic/500 | `go test -count=1 -run TestNotesSearchEncoding ./...` |
| C-09 | /api/notes?q=secret | GET | 401 | `{"error":"unauthorized"}` + `WWW-Authenticate: Bearer` (no/bad token) | `go test -count=1 -run TestNotesSearchAuthRequired ./...` |
| C-10 | /api/notes | PUT | 401 | auth before method: no token → 401 + bearer, not 405 | `go test -count=1 -run TestAuthMethodOrder ./...` |
| C-11 | /api/notes/{id} | DELETE | 401 | auth before id validation: no token → 401 + bearer | `go test -count=1 -run TestAuthRequired ./...` |
| C-12 | /api/notes | PUT | 405 | `{"error":"method not allowed"}` + `Allow: GET, POST` | `go test -count=1 -run TestNotesMethodNotAllowed ./...` |
| C-13 | /api/notes | PATCH | 405 | `{"error":"method not allowed"}` + `Allow: GET, POST` | `go test -count=1 -run TestNotesMethodNotAllowed ./...` |
| C-14 | /api/notes | DELETE | 405 | `{"error":"method not allowed"}` + `Allow: GET, POST` | `go test -count=1 -run TestNotesMethodNotAllowed ./...` |
| C-15 | /api/notes | POST | 201 | `{"id":N,"text":"..."}` unchanged | `go test -count=1 -run TestAddNote ./...` |
| C-16 | /api/notes | POST | 400 | `{"error":"text required"}` for empty/blank/oversized text | `go test -count=1 -run TestAddNote ./...` |
| C-17 | /api/notes | POST | 400 | `{"error":"invalid request body"}` for malformed/oversized JSON | `go test -count=1 -run TestAddNote ./...` |
| C-18 | /api/notes | POST | 401 | no token → `{"error":"unauthorized"}` + `WWW-Authenticate: Bearer` | `go test -count=1 -run TestAuthRequired ./...` |
| C-19 | /api/notes/{id} | DELETE | 204 | own note deleted; empty body, no Content-Type | `go test -count=1 -run TestDeleteNote ./...` |
| C-20 | /api/notes/{id} | DELETE | 400 | `{"error":"invalid id"}` for non-numeric/empty/overflow id | `go test -count=1 -run TestDeleteInvalidID ./...` |
| C-21 | /api/notes/{id} | DELETE | 404 | `{"error":"not found"}` for foreign or missing note | `go test -count=1 -run 'TestDeleteForeignNote|TestDeleteMissing' ./...` |
| C-22 | /api/notes/{id} | GET | 405 | `{"error":"method not allowed"}` + `Allow: DELETE` | `go test -count=1 -run TestNotesMethodNotAllowed ./...` |
| C-23 | /api/notes/{id} | PUT | 405 | `{"error":"method not allowed"}` + `Allow: DELETE` | `go test -count=1 -run TestNotesMethodNotAllowed ./...` |
| C-24 | /api/* unknown | GET | 404 | `{"error":"not found"}` (no SPA/API fallthrough) | `go test -count=1 -run TestUnknownAPINotFound ./...` |
| C-25 | /api/notes | GET | 200 | wire keys exactly `id`/`text`; `UserID` hidden; `[]` not `null` | `go test -count=1 -run TestWireContract ./...` |
| C-26 | /healthz | GET | 200 | `ok` over real HTTP transport | `go test -count=1 -run TestHTTPTransport ./...` |
| C-27 | /api/register | POST | 201 | `{"id":N,"username":"..."}`; no secret leak | `go test -count=1 -run TestRegister ./...` |
| C-28 | /api/register | POST | 409 | `{"error":"username taken"}` for duplicate | `go test -count=1 -run TestRegister ./...` |
| C-29 | /api/login | POST | 200 | `{"token":"<opaque base64url>"}` unchanged | `go test -count=1 -run TestLogin ./...` |
| C-30 | /api/login | POST | 401 | `{"error":"unauthorized"}` + `WWW-Authenticate: Bearer`; wrong password/unknown user indistinguishable | `go test -count=1 -run TestLoginInvalid ./...` |

## UI rows

| id | state / contract | oracle |
|---|---|---|
| U-01 | Notes screen has labelled `data-testid="notes-search"`, `type="search"`, `aria-controls="notes-list"`, above the list | `go test -count=1 -run TestUISemantics ./...` |
| U-02 | `data-testid="notes-search-clear"` is a `type=button` with accessible name, hidden while the raw query is empty | `go test -count=1 -run TestUISemantics ./...` |
| U-03 | Typing filters the already loaded owner-scoped list client-side; no request per keystroke | `go test -count=1 -run TestUISemantics ./...` + `SEARCH-E2E-1` |
| U-04 | UI match is case-insensitive (lower-case query vs upper-case stored text) | `playwright web/e2e/notes-search.spec.js::SEARCH-E2E-3` |
| U-05 | `notes-search-empty` shown only when (trimmed query non-empty) AND (loaded collection non-empty) AND (zero matches); `role=status`, `aria-live=polite`, copy `Ничего не найдено.` | `go test -count=1 -run TestUISemantics ./...` + `SEARCH-E2E-2`; delete-to-empty covered by `SEARCH-E2E-6` |
| U-06 | Genuinely empty server list shows `notes-empty`; `notes-search-empty` stays hidden | `go test -count=1 -run TestUISemantics ./...` + auth `E2E-5` |
| U-07 | Clear restores the full list and hides the search empty state | `playwright web/e2e/notes-search.spec.js::SEARCH-E2E-4` |
| U-08 | Create while a query is active re-applies the filter: matching new note appears, non-matching stays hidden | `playwright web/e2e/notes-search.spec.js::SEARCH-E2E-5` |
| U-09 | Delete while a query is active re-applies the filter; last match removal shows search-empty, not notes-empty | `playwright web/e2e/notes-search.spec.js::SEARCH-E2E-6` |
| U-10 | Login precedes the notes/search flow; user-B isolation remains auth E2E-6, not a search-spec scenario | auth `E2E-6` + `go test -count=1 -run TestNotesSearchIsolation ./...` |
| U-11 | Loading/error/401 regions and redirect handling remain the f-v3 behaviour; search controls disable while loading and stay usable when loaded | `go test -count=1 -run TestUISemantics ./...` + auth `E2E-7` |

## Non-contract note (not counted)

- `sessionStorage` `notebook.search` restore across a full reload is current
  implementation behaviour, but OD-6 is explicitly **not contractual** (s07
  proposal: do not persist). Reload must keep working; query persistence is not
  promised or oracle-checked as a contract row.

## Negative and edge cases

- `q` absent / `q=` / `q=%20%20%09` → all own notes, no 400 (OD-1): `go test -count=1 -run 'TestNotesSearchEmptyQuery|TestNotesSearchWhitespaceQuery' ./...`
- `q=absent` → 200 `[]`, not `null`, not 404: `go test -count=1 -run TestNotesSearchNotFound ./...`
- User B's note text matches `q` → not returned for user A: `go test -count=1 -run TestNotesSearchIsolation ./...`
- No/bad/expired bearer + `q` → 401 before query handling: `go test -count=1 -run TestNotesSearchAuthRequired ./...`
- No bearer + non-GET notes methods → 401 before 405/id validation: `go test -count=1 -run 'TestAuthMethodOrder|TestAuthRequired' ./...`
- `q=100%25`, `q=%26`, `q=a%2Bb`, `q=%20` → decoded safely, no panic/500: `go test -count=1 -run TestNotesSearchEncoding ./...`
- Mixed-case query vs stored text → matches: `playwright web/e2e/notes-search.spec.js::SEARCH-E2E-3`
- Query longer than the note text / empty stored text → no match, 200 `[]`: `go test -count=1 -run 'TestNotesSearchNotFound|TestNotesSearchEmptyQuery' ./...`
- Create/delete with an active query → filter re-applied: `playwright web/e2e/notes-search.spec.js::SEARCH-E2E-5` and `::SEARCH-E2E-6`
- Search empty state guard and separation from `notes-empty`: `playwright web/e2e/notes-search.spec.js::SEARCH-E2E-2` and `go test -count=1 -run TestUISemantics ./...`
- Integration smoke is auth/notes API only (no search `q=`): `cmd:bash deploy/path1/e2e-preview.sh` (E2E_API_ONLY=1)
- Re-delete after 204 → 404, no panic: `go test -count=1 -run TestDeleteMissing ./...`
- Unknown `/api/*` path → 404 JSON, no SPA fallthrough: `go test -count=1 -run TestUnknownAPINotFound ./...`

