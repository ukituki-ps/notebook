# T0005 — brief

- unit_id: **notebook-web-ui**
- domain: **notebook-web**
- sde: **sde-frontend**
- change_class: **security**
- task: `web/app.js` (fetch/Bearer/localStorage/состояния) + embed/static-хук в `main.go` + `web_ui_test.go`
- files: `web/app.js`, `web_ui_test.go`, `main.go` (только `go:embed` + static handler)
- depends_on: T0004

## Scope

1. **`web/app.js` — login.** `POST /api/login` с `username` (trim) и `password`;
   `200` → `localStorage["notebook.token"] = token`,
   `localStorage["notebook.user"] = username` из формы,
   `location.replace("/notes")`; `400` → inline-ошибка, ввод сохраняется;
   `401` → inline-ошибка, пароль очищается, фокус в Password. `submitting`
   блокирует кнопку/поля (double-submit невозможен), Enter отправляет форму;
   `sessionStorage["notebook.prefill"]` предзаполняет username (после register),
   ключ удаляется.
2. **`web/app.js` — register.** Confirm-password проверяется **только
   клиентски** (пусто/не совпало → ошибка, запрос не отправляется);
   `POST /api/register`; `201` → «аккаунт создан», prefill + переход на
   `/login`; `400` → строка по литералу (`username and password required` /
   `invalid username` / `invalid password` / `invalid request body`), форма не
   очищается; `409` → «username занят», фокус в Username.
3. **`web/app.js` — notes.** Нет токена → `location.replace("/login")` **без**
   запроса; есть токен → `GET /api/notes` с `Authorization: Bearer <token>`,
   состояния `loading` / `empty` (`[]` → `notes-empty`) / `list`; `POST`
   (Add) добавляет строку из ответа, очищает поле и снимает empty; `DELETE
   /api/notes/{id}` (pending: строка приглушена, Delete disabled) → `204`
   убирает строку из DOM; `404` при удалении → сообщение + повторный `GET`;
   `400` → inline-ошибка без удаления строки; любой `401` на
   GET/POST/DELETE → очистка `notebook.token` и `notebook.user` +
   `location.replace("/login")`. Logout — **только клиентский** (удаление
   ключей), `POST /api/logout` не вызывается. Одна видимая ошибка
   `[role="alert"]`; без фантомных/захардкоженных заметок; рендер только из
   ответа API.
4. **`main.go` — только integration-хук.** `//go:embed` с **явными**
   паттернами `web/index.html web/app.js web/app.css` (не `web/` целиком);
   маршруты `/` → `302 /login`, `/login`, `/register`, `/notes` → `index.html`
   с `Cache-Control: no-store`; `/app.js`, `/app.css` — статика с корректным
   `Content-Type`; API-маршруты не перекрываются. Auth/Store/notes из U01 не
   менять. При merge (s20a) хунк вливается **после** U01.
5. **`web_ui_test.go` (package main) — `TestUISemantics`.** Проверяет:
   embed-ресурсы существуют и непусты; все `data-testid` из
   `arch/structure/ui-pages/*.yaml`; видимые labels и тексты
   `Login`/`Register`/`Add`/`Delete`; `role="alert"` + `aria-live="polite"`;
   `notes-empty`/`notes-loading`; отсутствие захардкоженных заметок. Тест
   вынесен из `main_test.go`, чтобы не конфликтовать с U01.

## Acceptance / оракулы

```sh
node --check web/app.js
go build ./...
go test -count=1 -run 'TestUISemantics' ./...
go test -race ./...
go vet ./...
grep -q 'Authorization' web/app.js
grep -q 'notebook.token' web/app.js
grep -q 'notebook.user' web/app.js
grep -q 'location.replace' web/app.js
grep -q 'go:embed web/index.html web/app.js web/app.css' main.go
```

- `node --check` — синтаксис `app.js` валиден.
- `TestUISemantics` зелёный; embed-ресурсы собираются в бинарь.
- `/`, `/login`, `/register`, `/notes`, `/app.js`, `/app.css` отдаются
  приложением; `/` → 302 `/login`; HTML с `Cache-Control: no-store`.
- `401` в UI очищает `notebook.token`/`notebook.user` и уводит на `/login`.
- Нет `POST /api/logout` и нет фантомных заметок.

## Зависимости

- **T0004** (разметка/селекторы/CSS). Полный Playwright-прогон — T0006/s20c
  после merge U01 (auth-API).

## Что НЕ делать

- Не менять auth/Store/notes-логику U01 в `main.go`; хунк — только
  embed/static; при конфликте embed **после** API.
- Не использовать `web/` как embed-паттерн целиком (затянет `web/e2e`,
  `node_modules`).
- Не вводить фреймворки/сборщики/npm-рантайм, CORS/отдельный frontend-сервер,
  `alert()`, хранение пароля в storage.
- Не реализовывать `POST /api/logout`, refresh TTL, rate limiting.
- Не менять `web/e2e/*`, `playwright.config.js`, `deploy/*`, adapter-файлы,
  `arch/structure/ui-pages/*.yaml`.
- Не добавлять build-теги `integration/e2e/manual`.
