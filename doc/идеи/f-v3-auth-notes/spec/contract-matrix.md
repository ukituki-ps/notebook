# F-V3-AUTH-NOTES — contract matrix

Источник: [core.md](./core.md) §1, §10. База — `main.go` на `8e0e949`
(до auth). Тесты — `main_test.go` / `web_ui_test.go` (s20); полный прогон:
`go test -race ./...`.

| endpoint | method | status | envelope | test |
|---|---|---|---|---|
| /api/register | POST | 201 | {"id":N,"username":"..."} | go test -count=1 -run TestRegister ./... |
| /api/register | POST | 400 | {"error":"username and password required"} | go test -count=1 -run TestRegister ./... |
| /api/register | POST | 400 | {"error":"invalid username"} | go test -count=1 -run TestRegister ./... |
| /api/register | POST | 400 | {"error":"invalid password"} | go test -count=1 -run TestRegister ./... |
| /api/register | POST | 400 | {"error":"invalid request body"} | go test -count=1 -run TestRegister ./... |
| /api/register | POST | 409 | {"error":"username taken"} | go test -count=1 -run TestRegister ./... |
| /api/register | POST | 405 | {"error":"method not allowed"} + Allow: POST | go test -count=1 -run TestRegister ./... |
| /api/login | POST | 200 | {"token":"<opaque>"} | go test -count=1 -run TestLogin ./... |
| /api/login | POST | 400 | {"error":"username and password required"} | go test -count=1 -run TestLogin ./... |
| /api/login | POST | 400 | {"error":"invalid request body"} | go test -count=1 -run TestLogin ./... |
| /api/login | POST | 401 | {"error":"unauthorized"} + WWW-Authenticate: Bearer | go test -count=1 -run TestLoginInvalid ./... |
| /api/login | POST | 405 | {"error":"method not allowed"} + Allow: POST | go test -count=1 -run TestLogin ./... |
| /api/notes | GET | 200 | [{"id":N,"text":"..."}] (только свои; [] при пустом) | go test -count=1 -run TestNotesLifecycle ./... |
| /api/notes | GET | 401 | {"error":"unauthorized"} + WWW-Authenticate: Bearer | go test -count=1 -run TestAuthRequired ./... |
| /api/notes | GET | 401 | {"error":"unauthorized"} (истёкший токен) | go test -count=1 -run TestTokenExpiry ./... |
| /api/notes | PUT | 405 | {"error":"method not allowed"} + Allow: GET, POST | go test -count=1 -run TestNotesMethodNotAllowed ./... |
| /api/notes | DELETE | 405 | {"error":"method not allowed"} + Allow: GET, POST | go test -count=1 -run TestNotesMethodNotAllowed ./... |
| /api/notes | POST | 201 | {"id":N,"text":"..."} | go test -count=1 -run TestAddNote ./... |
| /api/notes | POST | 400 | {"error":"text required"} | go test -count=1 -run TestAddNote ./... |
| /api/notes | POST | 400 | {"error":"invalid request body"} | go test -count=1 -run TestAddNote ./... |
| /api/notes | POST | 401 | {"error":"unauthorized"} + WWW-Authenticate: Bearer | go test -count=1 -run TestAuthRequired ./... |
| /api/notes | POST | 405 | {"error":"method not allowed"} + Allow: GET, POST | go test -count=1 -run TestNotesMethodNotAllowed ./... |
| /api/notes/{id} | DELETE | 204 | none | go test -count=1 -run TestDeleteNote ./... |
| /api/notes/{id} | DELETE | 400 | {"error":"invalid id"} | go test -count=1 -run TestDeleteInvalidID ./... |
| /api/notes/{id} | DELETE | 401 | {"error":"unauthorized"} + WWW-Authenticate: Bearer | go test -count=1 -run TestAuthRequired ./... |
| /api/notes/{id} | DELETE | 404 | {"error":"not found"} (нет заметки) | go test -count=1 -run TestDeleteMissing ./... |
| /api/notes/{id} | DELETE | 404 | {"error":"not found"} (чужая заметка) | go test -count=1 -run TestDeleteForeignNote ./... |
| /api/notes/{id} | GET | 405 | {"error":"method not allowed"} + Allow: DELETE | go test -count=1 -run TestNotesMethodNotAllowed ./... |
| /api/notes/{id} | POST | 405 | {"error":"method not allowed"} + Allow: DELETE | go test -count=1 -run TestNotesMethodNotAllowed ./... |
| /api/notes/{id} | PUT | 405 | {"error":"method not allowed"} + Allow: DELETE | go test -count=1 -run TestNotesMethodNotAllowed ./... |
| /api/notes/{id} | PATCH | 405 | {"error":"method not allowed"} + Allow: DELETE | go test -count=1 -run TestNotesMethodNotAllowed ./... |

## Заголовки, лимиты, порядок

- `401` — всегда `WWW-Authenticate: Bearer`.
- `405` — всегда `Allow`: коллекция `GET, POST`; item `DELETE`;
  register/login `POST`.
- Все JSON-тела — `Content-Type: application/json`; `204` без тела и без
  `Content-Type`.
- Лимит тела — 1 MiB (`http.MaxBytesReader`) на register/login/POST notes;
  превышение → `400 invalid request body`.
- Порядок на `/api/notes*`: auth → method → path/id → body. Поэтому
  неавторизованный `PUT /api/notes` и `DELETE /api/notes/abc` дают `401`,
  а не `405/400`.
- Неизвестный `/api/*` → `404 {"error":"not found"}` (JSON, не HTML).
- `500 {"error":"internal error"}` — служебный failure-путь (rand/encode), в
  матрицу не входит: тестом не закрепляется, но envelope обязателен.

## Негативные и краевые кейсы

- `/api/notes*` без заголовка → 401, `go test -count=1 -run TestAuthRequired ./...`
- `/api/notes*` с `Authorization: Basic ...`, `Bearer`, `Bearer a b` → 401, `go test -count=1 -run TestAuthRequired ./...`
- `/api/notes*` с истёкшим токеном → 401, сессия удалена, `go test -count=1 -run TestTokenExpiry ./...`
- login с неверным паролем и с несуществующим username → одинаковые 401, `go test -count=1 -run TestLoginInvalid ./...`
- register с занятым username → 409, второй записи нет, `go test -count=1 -run TestRegister ./...`
- register: username `ab` / `a b` / `юзер` / 33 символа → 400 invalid username, `go test -count=1 -run TestRegister ./...`
- register: `Alice` и `alice` — разные пользователи (case-sensitive), `go test -count=1 -run TestRegister ./...`
- register/login: пустые поля → 400, тело > 1 MiB → 400 invalid request body, `go test -count=1 -run TestRegister ./...`
- GET /api/notes у нового пользователя → `[]`, не `null`, `go test -count=1 -run TestNotesLifecycle ./...`
- GET /api/notes A не содержит заметок B, `go test -count=1 -run TestNotesIsolation ./...`
- DELETE чужой заметки → 404 (не 403/204), `go test -count=1 -run TestDeleteForeignNote ./...`
- DELETE отсутствующей заметки → 404 not found, `go test -count=1 -run TestDeleteMissing ./...`
- повторный DELETE своей заметки → 404, `go test -count=1 -run TestDeleteNote ./...`
- DELETE `abc` → 400 invalid id, `go test -count=1 -run TestDeleteInvalidID ./...`
- DELETE пустой id (`/api/notes/`) → 400 invalid id, `go test -count=1 -run TestNotesPrefixBoundary ./...`
- DELETE overflow id → 400 без паники, `go test -count=1 -run TestDeleteInvalidID ./...`
- DELETE отрицательный id → 400/404 без паники, `go test -count=1 -run TestDeleteInvalidID ./...`
- DELETE `/api/notes/1/extra` → 400, note 1 не удалена, `go test -count=1 -run TestNotesPrefixBoundary ./...`
- POST /api/notes с `""` / `"   "` / `"\n\t"` → 400 text required, `go test -count=1 -run TestAddNote ./...`
- POST /api/notes с text > 4096 байт → 400 text required, `go test -count=1 -run TestAddNote ./...`
- GET после DELETE → удалённой заметки нет, `go test -count=1 -run TestListAfterDelete ./...`
- ответы не содержат `password`/`hash`/`salt`/`user_id`; `token` только login 200, `go test -count=1 -run TestNoSecretLeak ./...`
- wire-ключи ровно `id`/`text`/`token`/`username`/`error`, нижний регистр, `go test -count=1 -run TestWireContract ./...`
- все вызовы — через HTTP-транспорт (`httptest.Server`), не прямые Store, `go test -count=1 -run TestHTTPTransport ./...`
- в `_test.go` нет build-тегов `integration`/`e2e`/`manual`; оракул: `cmd:sh -c "! grep -R -E '^//go:build.*(integration|e2e|manual)' --include='*_test.go' ."`

## Канарейка

`CANARY-DELETE-STATUS` (`sed s/http.StatusNoContent/http.StatusOK/ main.go`)
валидна только если DELETE-обработчик и литерал `http.StatusNoContent`
остаются в `main.go`, а `TestDeleteNote` ассертит ровно `204`:

- `grep -n 'http.StatusNoContent' main.go` — непусто;
- `go test -count=1 -run TestDeleteNote ./...` — зелёный на базе;
- после seed-замены — красный (`200 != 204`).
