# T0002 — brief

- unit_id: **notebook-auth-api**
- domain: **notebook-api**
- sde: **sde-backend**
- change_class: **security**
- task: `POST /api/register`, `POST /api/login`, auth-guard, JSON-envelope
- files: `main.go`, `main_test.go`
- depends_on: T0001

## Scope

1. **JSON-обвязка.** Хелперы `writeJSON(w, code, v)` и `writeErr(w, code, msg)`:
   `Content-Type: application/json` для всех JSON-тел, единый envelope
   `{"error":"<literal>"}`; `http.Error` (`text/plain` + `\n`) больше не
   используется ни в одной ветке. Литералы стабильны: `invalid id`,
   `not found`, `method not allowed`, `text required`, `unauthorized`,
   `username taken`, `username and password required`, `invalid username`,
   `invalid password`, `invalid request body`, `internal error`.
2. **`POST /api/register`** (публичный): порядок method → body → validation.
   - `201 {"id":N,"username":"..."}` — отдельная response-структура, без
     `password`/`hash`/`salt`; без auto-login.
   - `400`: `username and password required` (пусто после trim),
     `invalid username` (username не `[A-Za-z0-9_-]{3,32}` после `TrimSpace`,
     case-sensitive), `invalid password` (8–128 runes, не trim),
     `invalid request body` (битый JSON/неверный тип/тело > 1 MiB через
     `http.MaxBytesReader`).
   - `409 username taken` — только точное совпадение; вторая запись не
     создаётся; проверка дубля и вставка — под `regMu` (TOCTOU).
   - `405 + Allow: POST`.
3. **`POST /api/login`** (публичный): порядок method → body → auth.
   - `200 {"token":"<opaque>"}`; `400` те же литералы, что register (кроме
     `invalid username`/`invalid password` — login формат не валидирует);
   - `401 unauthorized` + `WWW-Authenticate: Bearer` — **одинаковый** ответ и
     сопоставимое время для «нет пользователя» (dummy-PBKDF2) и «неверный
     пароль»; `405 + Allow: POST`.
4. **Auth-guard** на `/api/notes` и `/api/notes/`:
   - разбор `Authorization` ровно как два токена через пробел, схема `Bearer`
     case-insensitive, токен непустой; токен в query/cookie не принимается;
   - нет/битый/истёкший токен → `401 {"error":"unauthorized"}` +
     `WWW-Authenticate: Bearer`;
   - порядок проверок **auth → method → path/id → body**: неавторизованный
     `PUT /api/notes`, `GET/DELETE /api/notes/abc` дают 401, а не 405/400;
   - неизвестный `/api/*` → `404 {"error":"not found"}` (JSON, не HTML);
   - guard встраивается так, чтобы T0003 переиспользовал его для notes-операций.
5. **Тесты** (в `main_test.go`): `TestRegister` (201/400/409/405, case-sensitive
   `Alice`≠`alice`, лимит тела), `TestLogin` (200 `{token}`, 400, 405),
   `TestLoginInvalid` (401 одинаков для нет/неверного пользователя),
   `TestAuthRequired` (все методы `/api/notes*` без/битый/истёкший токен → 401
   до 405/400), `TestNoSecretLeak` (нет `password`/`hash`/`salt`; `token` только
   login 200), `TestWireContract` (ключи ровно `id/text/token/username/error`,
   нижний регистр), `TestAuthMethodOrder` (auth раньше method/id/body),
   `TestHTTPTransport` (httptest.Server, не прямые вызовы Store).
   Helper-ы `seedUser(t,h) (username, token)` и
   `authedRequest(t,h,method,path,body,token)` — здесь и для T0003.

## Acceptance / оракулы

```sh
go build ./...
go vet ./...
go test -count=1 -run 'TestRegister|TestLogin|TestLoginInvalid' ./...
go test -count=1 -run 'TestAuthRequired|TestAuthMethodOrder' ./...
go test -count=1 -run 'TestNoSecretLeak|TestWireContract|TestHTTPTransport' ./...
go test -race ./...
git diff --exit-code go.mod
```

- register 201 отдаёт ровно `{"id":N,"username":"..."}`; `Content-Type`
  `application/json`.
- register 400/409/405 и login 400/401/405 — точные литералы и `Allow`/
  `WWW-Authenticate`.
- 401 на `/api/notes*` при неавторизованном «неправильном» методе/id.
- Ни один ответ register/login не содержит `password`/`hash`/`salt`;
  `token` — только в 200 login.
- `go test -race ./...` и `go vet ./...` зелёные.

## Зависимости

- **T0001** (Store, PBKDF2, сессии, `now`). T0003 использует созданные здесь
  guard и хелперы.

## Что НЕ делать

- Не реализовывать notes-операции и их owner-scope — это T0003.
- Не добавлять `POST /api/logout`, refresh/sliding TTL, rate limiting,
  lockout/CAPTCHA.
- Не добавлять зависимости в `go.mod`; не логировать креды/токены.
- Не менять `web/*`, `deploy/*`, adapter-файлы.
- Не переносить DELETE-обработчик и литерал `http.StatusNoContent` из `main.go`.
- Не использовать `http.Error` для ошибок контракта.
- Не добавлять build-теги `integration/e2e/manual`.
- Не трогать E1320 и артефакты других исполнений.
