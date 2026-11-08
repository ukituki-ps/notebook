# F-V4-NOTE-SEARCH — contract matrix

Source: [core.md](./core.md) §1, §3. Base: `main.go` at `e6aeb44e`.
Process: `path-1.feature` 4.0.0. DS: Notebook DS 1.0.0 (`ds/v1.0.0`,
`02f027a8…da3d`).
Tests: backend Go tests exist at base; the exactly-512 accept case and the
UI count/retry/offline/loading-role/delete-label cases are added at s20 per plan
T0003/T0007. Full run: `go test -count=1 ./...` + Playwright.

| endpoint | method | status | envelope | test |
|---|---|---|---|---|
| /api/notes | GET | 200 | [{"id":N,"text":"..."}] all own notes when q absent | go test -count=1 -run TestNotesSearchFinds ./... |
| /api/notes?q=milk | GET | 200 | [{"id":N,"text":"..."}] case-insensitive substring matches only | go test -count=1 -run TestNotesSearchFinds ./... |
| /api/notes?q=MILK | GET | 200 | same as q=milk (case-insensitive) | go test -count=1 -run TestNotesSearchCaseInsensitive ./... |
| /api/notes?q=zzz | GET | 200 | [] (not null) when no match | go test -count=1 -run TestNotesSearchNotFound ./... |
| /api/notes?q= | GET | 200 | all own notes (empty query after trim) | go test -count=1 -run TestNotesSearchEmptyQuery ./... |
| /api/notes?q=%20%20 | GET | 200 | all own notes (whitespace-only query after trim) | go test -count=1 -run TestNotesSearchWhitespaceQuery ./... |
| /api/notes?q=milk | GET | 200 | only current user's notes; owner predicate runs before the text predicate | go test -count=1 -run TestNotesSearchIsolation ./... |
| /api/notes?q=a%26b%2Bc | GET | 200 | URL-encoded/special characters decoded safely | go test -count=1 -run TestNotesSearchEncoding ./... |
| /api/notes?q=x | GET | 401 | {"error":"unauthorized"} + WWW-Authenticate: Bearer; auth before q handling | go test -count=1 -run TestNotesSearchAuthRequired ./... |
| /api/notes?q=<513+ decoded bytes> | GET | 400 | {"error":"query too long"} before any note scan | go test -count=1 -run TestNotesSearchQueryTooLong ./... |
| /api/notes?q=<512 decoded bytes> | GET | 200 | exactly 512 bytes accepted; normal filtered response | go test -count=1 -run TestNotesSearchQueryTooLong ./... |
| /api/notes | GET | 200 | wire unchanged: [{"id":N,"text":"..."}]; UserID is not serialized | go test -count=1 -run TestWireContract ./... |
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
| web /notes | GET | 200 | notes-search: type=search, label "Поиск заметок", placeholder "Поиск по тексту...", aria-controls=notes-list | go test -count=1 -run TestUISemantics ./... |
| web /notes | GET | 200 | notes-search-clear: visible "Очистить", aria-label "Очистить поиск"; clears query, restores full list, returns focus to search | npx playwright test web/e2e/notes-search.spec.js |
| web /notes | GET | 200 | notes-search-count: "Найдено N" only for non-empty trimmed query (incl. 0), aria-live=polite; hidden when empty | npx playwright test web/e2e/notes-search.spec.js |
| web /notes | GET | 200 | notes-search-empty: role=status, aria-live=polite, text "Ничего не найдено. Сократите запрос или очистите поиск."; only non-empty query on non-empty collection | go test -count=1 -run TestUISemantics ./... + npx playwright test web/e2e/notes-search.spec.js |
| web /notes | GET | 200 | zero notes: notes-empty wins; notes-search-empty hidden; search disabled | go test -count=1 -run TestUISemantics ./... + npx playwright test web/e2e/notes-search.spec.js |
| web /notes | GET | 200 | notes-loading: role=status; search disabled while loading | go test -count=1 -run TestUISemantics ./... |
| web /notes | GET | 200 | notes-error: role=alert + aria-live=polite; notes-retry "Повторить" wired to loadNotes | npx playwright test web/e2e/notes-search.spec.js |
| web /notes | GET | 200 | notes-offline: driven by navigator.onLine + loaded notes; notes-offline-check "Проверить сеть"; offline-zero variant; no cache | npx playwright test web/e2e/notes-search.spec.js |
| web /notes | GET | 200 | delete: visible "Удалить", aria-label "Удалить заметку #N"; Add/Logout remain English | go test -count=1 -run TestUISemantics ./... + npx playwright test web/e2e/notes-search.spec.js |
| web /notes | GET | 200 | DS testids: notes-search, notes-search-clear, notes-search-count, notes-search-empty, notes-retry, notes-offline, notes-offline-check, notes-empty, notes-loading, notes-error; Notebook DS 1.0.0, 12 registry components, path6 GAP-1/GAP-2/GAP-3 accepted, 0 local instances, no Kubiki | go test -count=1 -run TestUISemantics ./... + python3 tools/ui-audit-check.py --platform web |
| web /notes | GET | 200 | composer-first AOD-7; 390px and 1200px: no horizontal overflow, stacked/inline search row | npx playwright test web/e2e/notes-search.spec.js |

## Negative and edge cases

- Decoded `q` > 512 bytes → `400 {"error":"query too long"}` before any note scan; exactly 512 bytes accepted: `go test -count=1 -run TestNotesSearchQueryTooLong ./...`
- No/bad/expired bearer + any `q` → `401` before query handling: `go test -count=1 -run TestNotesSearchAuthRequired ./...`
- `q` absent, `q=`, `q=%20%20` (≤512 bytes) → all own notes, no `400`: `go test -count=1 -run 'TestNotesSearchEmptyQuery|TestNotesSearchWhitespaceQuery' ./...`
- Whitespace-only `q` > 512 bytes → `400` because the cap is checked before trim: `go test -count=1 -run TestNotesSearchQueryTooLong ./...`
- `q=zzz` → `200 []`, not `null`, not `404`: `go test -count=1 -run TestNotesSearchNotFound ./...`
- User B's note text matches `q` → not returned for user A; owner predicate first: `go test -count=1 -run TestNotesSearchIsolation ./...`
- `q=a%26b%2Bc`, `q=%E2%9C%93`, `q=%D0%BC%D0%BE%D0%BB%D0%BE%D0%BA%D0%BE` → decoded safely, no panic/500: `go test -count=1 -run TestNotesSearchEncoding ./...`
- `q` with mixed case vs stored text → matches: `go test -count=1 -run TestNotesSearchCaseInsensitive ./...`
- Zero-note collection: `notes-empty` wins and `notes-search-empty` is not shown; search disabled: `npx playwright test web/e2e/notes-search.spec.js`
- Non-empty trimmed query with no matches → `notes-search-empty`; empty query → it is hidden; count hidden on empty query and `Найдено 0` shown for a live query with no matches: `npx playwright test web/e2e/notes-search.spec.js`
- Offline-zero with nothing loaded → offline variant, not `notes-search-empty`: `npx playwright test web/e2e/notes-search.spec.js`
- Delete control has visible `Удалить` and `aria-label="Удалить заметку #N"`: `go test -count=1 -run TestUISemantics ./...`
- After create/delete with an active query, the UI re-applies the filter and does not hide new/remaining notes: `npx playwright test web/e2e/notes-search.spec.js`
