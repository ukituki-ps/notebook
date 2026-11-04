# T0006 — brief

- unit_id: **notebook-web-ui**
- domain: **notebook-web**
- sde: **sde-frontend**
- change_class: **security**
- task: Playwright-конфиг + `web/e2e/auth-notes.spec.js` (7 сценариев)
- files: `playwright.config.js`, `web/e2e/auth-notes.spec.js`
- depends_on: T0005

## Scope

1. **`playwright.config.js`.** `testDir: "web/e2e"`, один проект `chromium`,
   `headless: true`; `use.baseURL = process.env.E2E_BASE_URL ||
   "http://127.0.0.1:9082"`; без retries-маскировки и без skip при отсутствии
   браузеров (fail-close, не «зелёный» E2E). Полный прогон — на s20c после
   merge U01+U02.
2. **`web/e2e/auth-notes.spec.js` — ровно 7 независимых сценариев**
   (порядок не важен, уникальные username на прогон, отдельные
   `browser.newContext()` для A/B):
   - **E2E-1 Регистрация:** `/register` → валидные username/password/confirm →
     201 → переход на `/login`, username предзаполнен (`notebook.prefill`).
   - **E2E-2 Логин и токен:** `/login` → 200 → `localStorage["notebook.token"]`
     непустой → `/notes`.
   - **E2E-3 Создание заметки:** Add → 201, строка `#<id> <text>` в
     `notes-list`, empty state снят.
   - **E2E-4 Reload:** после `page.reload()` на `/notes` заметка видна
     (сессия из localStorage, повторный `GET`).
   - **E2E-5 Удаление:** Delete → 204, строка убрана; после удаления последней
     — `notes-empty`.
   - **E2E-6 A/B изоляция:** два context: B не видит заметку A; DELETE чужой
     заметки из B → 404.
   - **E2E-7 Неавторизованный `GET /api/notes`:** через `APIRequestContext` →
     401 + `WWW-Authenticate: Bearer`.
3. Каждый сценарий самодостаточен (свой register/login), использует
   `data-testid` из T0004/T0005, не полагается на общий in-memory порядок и не
   проверяет app-`/healthz` (на стенде `/healthz` — nginx JSON).
4. Заголовок/имена тестов отражают E2E-1..7 для трассировки в s20c (evidence).

## Acceptance / оракулы

```sh
node --check playwright.config.js
node --check web/e2e/auth-notes.spec.js
npx playwright test --list          # ровно 7 сценариев
grep -q 'E2E_BASE_URL' playwright.config.js
grep -q 'testDir' playwright.config.js
grep -c 'test(' web/e2e/auth-notes.spec.js   # >= 7 (7 независимых сценариев)
```

- `--list` показывает ровно 7 сценариев, все в проекте `chromium`.
- `baseURL` берётся из `E2E_BASE_URL` с дефолтом `http://127.0.0.1:9082`.
- В спеке нет `test.skip`/`fixme` как способа обойти отсутствие браузеров или
  стенда; уникальные username (run-id), A/B — разные context.
- Полный прогон 7/7 — s20c, не локальный шаг; здесь — `--list` + синтаксис.

## Зависимости

- **T0005** (`web/app.js`, селекторы, embed). Реальный прогон требует
  смерженного U01 (auth-API) и стенда test2 (s20b/s20c).

## Что НЕ делать

- Не менять `web/index.html`, `web/app.js`, `web/app.css`, `main.go`,
  `web_ui_test.go` — это T0004/T0005.
- Не добавлять сценарии сверх 7 (дополнительные UI-состояния — s20c/s22a).
- Не использовать `test.skip`/`test.fixme`/условный «зелёный» при отсутствии
  браузеров; не полагаться на порядок сценариев.
- Не проверять app-`/healthz` как JSON; не хардкодить `localhost`/порт вместо
  `E2E_BASE_URL`.
- Не менять `deploy/*`, adapter-файлы, `arch/structure/ui-pages/*.yaml`.
- Не добавлять npm-зависимости в прод-рантайм UI (Playwright — только dev/E2E).
