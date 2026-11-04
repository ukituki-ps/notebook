# f-v3-auth-notes — change-definition

- Execution: **E4312**, шаг **s10.change_definition**
- Repo: `/workspace/projects/notebook`, ветка `dev/f-v3-auth-notes`, база `8e0e949`
- Источник: `feature-brief.md` (FINAL), `invariants.json`, `scope-report.md`,
  `expertise-report.md`, `intent-brief.md`, `intent-trace.json`,
  `arch/structure/ui-pages/*.yaml`, `main.go`, `main_test.go`,
  `path1.project.json`, `path1.ui.json`, `deploy/Dockerfile`,
  `deploy/path1/e2e-preview.sh`, `deploy/path1/preview-deploy.sh`.
- Границы шага: **только этот документ**. Код, адаптеры, Dockerfile, скрипты
  деплоя и UI-граф на s10 не меняются.

## Домены и поверхности

| Домен | Поверхность | Что входит |
|---|---|---|
| `notebook-api` | HTTP + in-memory store | `main.go`: маршруты `/api/register`, `/api/login`, `/api/notes*`, `/healthz`; `Store` (users/sessions/notes); PBKDF2; bearer-сессии; JSON-envelope ошибок |
| `notebook-web` | статический UI | `web/index.html`, `web/app.js`, `web/app.css`; маршруты `/login`, `/register`, `/notes`; `localStorage`; `go:embed`; same-origin `/api/*` |
| `notebook-tests` | Go + Playwright | `main_test.go` (миграция под auth, сохранение имён canary/audit-тестов); `web/e2e/auth-notes.spec.js` (7 сценариев) |
| `notebook-deploy` | Dockerfile / embed / e2e | `deploy/Dockerfile` (build-stage с `web/`), `deploy/path1/e2e-preview.sh` (auth-smoke + Playwright); `deploy/path1/preview-deploy.sh` **не меняется** |
| `path1-adapter` | adapter + UI-граф | `path1.project.json`, `path1.ui.json`, `arch/structure/ui-pages/{login,register,notes}.yaml` (на s21 — `status: implemented` по коду) |

Внешний контракт `notebook-api` — ровно пять эндпоинтов; всё остальное
(`/healthz`, статика) вспомогательное и не входит в auth-контракт.

## Изменения

### C1. Store: users/sessions/notes, PBKDF2, bearer-сессии

- **До:** `Store{mu sync.Mutex, next int, notes []Note}`, `Note{ID,Text}`;
  глобальные `List()`, `Add(text)`, `Delete(id)`; users/sessions отсутствуют.
- **После:** один `Store` на процесс:
  - `User{ID int, Username string, PasswordHash []byte, Salt []byte}` —
    `PasswordHash`/`Salt` с `json:"-"`, наружу отдаётся только response-структура
    `{id,username}`;
  - `Session{Token string, UserID int, ExpiresAt time.Time}` — `map[token]*Session`;
  - `Note{ID int, UserID int, Text string}` — `UserID` с `json:"-"`, id заметок
    глобально монотонные, не переиспользуются;
  - `Store{mu sync.Mutex, regMu sync.Mutex, now func() time.Time, nextUser,
    nextNote int, usersByID map[int]*User, usersByName map[string]*User,
    sessions map[string]*Session, notes map[int]Note}`.
- **Пароли:** PBKDF2-HMAC-SHA256 на stdlib (`crypto/hmac` + `crypto/sha256` +
  `encoding/binary`; `crypto/pbkdf2` в Go 1.23 нет): соль 16B `crypto/rand`,
  итерации 210 000 (package-level `var`, тесты могут понизить), ключ 32B,
  сравнение `crypto/subtle.ConstantTimeCompare`. Пароль не хранится открыто,
  не логируется. Хэширование/проверка — **вне `Store.mu`**; `regMu`
  сериализует «проверить username → hash → вставить» (TOCTOU).
- **Токен:** 32 случайных байта `crypto/rand`, `base64.RawURLEncoding`
  (~43 символа), непрозрачный (не JWT). TTL **24h fixed** от логина, без
  refresh/sliding; истёкшая сессия удаляется лениво при lookup и даёт 401.
  `crypto/rand` failure → 500 JSON, без предсказуемой деградации.
- **Owner-scoped:** `List(userID)` возвращает не-nil `[]` только своих заметок;
  `Add(userID,text)`; `Delete(userID,noteID)` → `false`, если заметки нет **или**
  `note.UserID != userID` (наружу не различаем).
- **Файлы:** `main.go` (единственный Go-файл; DELETE-обработчик остаётся в нём —
  см. C5/canary).

### C2. `POST /api/register`

- **До:** эндпоинта нет.
- **После:** публичный (без Bearer), JSON-тело `{"username":"...","password":"..."}`:
  - `201` `{"id":N,"username":"..."}` — пользователь создан, без auto-login;
  - `400` `{"error":"..."}` — пустые/битые/невалидные поля (username trim,
    `[A-Za-z0-9_-]{3,32}`, case-sensitive; password 8–128; тело ≤ 1 MiB через
    `http.MaxBytesReader`);
  - `409` `{"error":"username taken"}` — username занят, вторая запись не
    создаётся;
  - `405` + `Allow: POST` — неизвестный метод.
- **Файлы:** `main.go`. **Контракт:** регистрация не выдаёт токен; вход —
  отдельным C3.

### C3. `POST /api/login`

- **До:** эндпоинта нет.
- **После:** публичный, тело `{"username":"...","password":"..."}`:
  - `200` `{"token":"<opaque>"}` — создана сессия TTL 24h;
  - `400` — пустые/битые поля / тело > 1 MiB;
  - `401` `{"error":"unauthorized"}` — неверная пара; **одинаковый** ответ для
    «нет пользователя» и «неверный пароль», для отсутствующего username
    выполняется dummy-PBKDF2 (анти-enumeration по времени);
  - `405` + `Allow: POST`.
- **Файлы:** `main.go`.

### C4. `GET/POST /api/notes` — breaking: обязателен Bearer

- **До:** без авторизации; `GET` отдаёт все заметки, `POST` создаёт глобальную;
  ошибки `http.Error` (`text/plain`).
- **После:** guard на `/api/notes` и `/api/notes/`; порядок проверок
  **auth → method → path/id → body**:
  - нет/битый/истёкший токен → `401` + `WWW-Authenticate: Bearer` +
    `{"error":"unauthorized"}` (в том числе для `PUT`, `DELETE /api/notes/abc`);
  - `GET` → `200` JSON-массив **только своих** заметок, `[]` при пустом списке
    (не `null`); поле `UserID` не сериализуется;
  - `POST` → `201` `{"id":N,"text":"..."}` — владелец из токена; пустой/слишком
    длинный `text` → `400` `{"error":"text required"}` (лимит 1–4096);
  - `405` + `Allow: GET, POST` — неверный метод на коллекции.
- **Файлы:** `main.go`. **Контракт:** `Content-Type: application/json`; единый
  envelope `{"error":"..."}` вместо `http.Error`.

### C5. `DELETE /api/notes/{id}` — Bearer, owner-scoped

- **До:** без авторизации; `204` любая существующая заметка; `400` нечисловой
  id; `404` отсутствующая; `405` не-DELETE; ошибки `text/plain`.
- **После:** auth **раньше** method/id:
  - `204` без тела — удалена своя заметка;
  - `400` `{"error":"invalid id"}` — нечисловой/пустой/overflow id;
  - `401` `{"error":"unauthorized"}` — нет/битый/истёкший токен (до 400/404/405);
  - `404` `{"error":"not found"}` — заметки нет **или** она чужая (не 403);
  - `405` + `Allow: DELETE` — неверный метод (для авторизованного запроса);
  - `Note.UserID` не сериализуется.
- **Canary:** литерал `http.StatusNoContent` остаётся в `main.go`; обработчик
  DELETE не переносится в другой файл — иначе `CANARY-DELETE-STATUS`
  (`sed s/http.StatusNoContent/http.StatusOK/ main.go`) станет ложно-зелёным.
- **Файлы:** `main.go`.

### C6. UI: `web/index.html` + `web/app.js` + `web/app.css`

- **До:** `web/` отсутствует; приложение отдаёт только API.
- **После:** статический UI без фреймворков/сборки, same-origin к `/api/*`:
  - `web/index.html` — единый HTML-вход; клиентские маршруты/экраны
    `/login`, `/register`, `/notes`; `/` → `302 /login`;
  - `web/app.js` — формы login/register/notes, fetch с
    `Authorization: Bearer`, обработка кодов, guard по токену, рендер списка;
  - `web/app.css` — вёрстка (колонка ≤640px, mobile <640px, full-width
    кнопки, touch ≥44px);
  - **login:** `POST /api/login`; `200` → токен в `localStorage["notebook.token"]`,
    username в `localStorage["notebook.user"]`, `location.replace("/notes")`;
    `400/401` → inline `role="alert"` + `aria-live="polite"`;
  - **register:** confirm-password только клиентски; `POST /api/register`;
    `201` → `/login` с предзаполненным username; `400/409` → inline-ошибки;
  - **notes:** нет токена → `/login` без запроса; иначе `GET /api/notes`
    (`loading`/`empty`/`list`), `POST` (Add), `DELETE` (Delete); любой `401` →
    очистка `notebook.token`/`notebook.user` и `location.replace("/login")`;
    `400` — рядом с формой; `404` при удалении → сообщение + повторный `GET`;
  - empty state — `data-testid="notes-empty"`; ошибки — одна видимая область
    `[role="alert"]`; submit-кнопки `Login`/`Register`/`Add`/`Delete`;
  - Logout — **только клиентский** (удаление localStorage), `POST /api/logout`
    не вызывается;
  - раздача — `go:embed` с **явными** паттернами
    (`web/index.html web/app.js web/app.css`), не `web/` целиком (иначе
    `web/e2e`/`node_modules` попадут в бинарь); HTML — `Cache-Control: no-store`;
    статика — корректный `Content-Type`.
- **Файлы:** `web/index.html`, `web/app.js`, `web/app.css` (+ embed-директивы в
  `main.go`).

### C7. Тесты: Go под auth + Playwright 7 сценариев

- **До:** `main_test.go` закрепляет безавторизационный контракт; Playwright-спеки
  нет.
- **После:** `main_test.go` переписан под auth:
  - сохранить **имена** `TestDeleteNote`, `TestDeleteErrorEnvelope`,
    `TestNotesMethodNotAllowed` (их используют `canaries`/`audit.oracles`);
  - helper-ы `seedUser(t,h) (username, token)` (register+login, уникальный
    username) и `authedRequest(t,h,method,path,body,token)`; `mustSeedNote`
    получает токен;
  - новые: `TestAuthRequired` (все методы `/api/notes*` без/битый/истёкший
    токен → 401 до 405/400), `TestRegister` (201/400/409/405),
    `TestLoginInvalid` (401 одинаков для нет/неверного пользователя),
    `TestNotesIsolation` (A не видит/не удаляет B; DELETE B → 404),
    `TestDeleteForeignNote`, `TestNoSecretLeak` (`password`/`hash`/`salt` нет в
    JSON; token только в login 200), `TestPasswordHashed` (PBKDF2,
    constant-time, разные соли), `TestTokenExpiry` (инъекция `now`),
    `TestWireContract` (ключи ровно `id/text/token/username/error`, нижний
    регистр), `TestHTTPTransport` (httptest.Server, не прямые вызовы Store),
    `TestNotesPrefixBoundary`, `TestAuthMethodOrder`, `TestUISemantics`
    (embed-ресурсы, `data-testid`, `role="alert"`, `aria-live`, labels,
    empty state, отсутствие фантомных заметок);
  - без build-тегов `integration/e2e/manual`; локальный DoD —
    `go test -race ./...`, `go vet ./...`.
- **E2E:** `web/e2e/auth-notes.spec.js` — 7 сценариев: (1) регистрация,
  (2) логин + токен в localStorage, (3) создание заметки, (4) reload — заметка
  видна, (5) удаление, (6) user B не видит заметку A (два browser context),
  (7) неавторизованный `GET /api/notes` → 401. Уникальные username на прогон,
  независимость от порядка, `baseURL` из `E2E_BASE_URL`.
- **Файлы:** `main_test.go`, `web/e2e/auth-notes.spec.js`
  (+ `playwright.config.js` при необходимости).

### C8. Adapter и deploy

`path1.project.json` — целевое состояние (часть полей уже совпадает):

| Поле | Целевое значение | Комментарий |
|---|---|---|
| `graph.source_roots` | `["web"]` | источник UI-графа |
| `graph.artifact_globs` | `arch/structure/ui-pages/*.yaml`, `*.yml`, `doc/идеи/*/UI-GRAPH.yaml` | один источник — `ui-pages/*` |
| `e2e.frontend_dir` | `"web"` | UI-каталог |
| `e2e.command` | `bash deploy/path1/e2e-preview.sh` | строку не менять; меняется тело скрипта |
| `audit.mode` | `"app"` | без БД |
| `audit.database` | `false` | |
| `canaries.require_dsn` | `false` | |
| `deploy.stand_command` | `bash deploy/path1/preview-deploy.sh {stand} {ref}` | **не менять** (path10 adapter) |

- `path1.ui.json`: `{"platform":"web", ...}` — UI-пробы включены.
- `deploy/Dockerfile`: в **build stage** добавить `COPY web/ ./web/` **до**
  `go build` (embed не соберётся без каталога); при появлении новых `.go` —
  `COPY *.go ./`; runtime-stage и `ENTRYPOINT` не меняются; `.dockerignore` —
  `web/e2e/`, `web/node_modules/`.
- `deploy/path1/e2e-preview.sh`: сохранить `E2E_BASE_URL`/health-проверку
  (на стенде `/healthz` — **nginx JSON**, не app-`ok`), затем
  register/login → authed `GET/POST/DELETE /api/notes` → проверка 401 без
  токена и изоляции A/B → запуск Playwright (`chromium`). Нет браузеров/docker
  на runner — **fail-close** с явной ошибкой, не skip.
- `arch/structure/ui-pages/{login,register,notes}.yaml`: на s21 `status`
  `planned → implemented`, `source_files`/`selectors`/`routes`/`api_calls`
  сверяются с фактическим кодом (`web/index.html` и `data-testid`); второй граф
  (`arch/frontend/pages/*`, `UI-GRAPH.yaml`) не создаётся.
- `deploy/path1/preview-deploy.sh` не редактируется; `preview-deploy.json` со
  `stand.sha` (выкаченный ref) материализуется на s20b для s22a.

## Ломающие изменения и миграция

- **Контракт:** все `/api/notes*` становятся auth-required. Безавторизационные
  `GET/POST/DELETE` теперь дают `401` **до** проверки метода/id/тела: нечисловой
  id и неверный метод без токена — тоже `401`, а не `400/405`.
- **Тесты:** текущий `main_test.go` целиком падает (401 вместо 200/201/204/
  400/404/405). Миграция: `seedUser` + `authedRequest`, переписать все
  существующие тесты, сохранив имена `TestDeleteNote`,
  `TestDeleteErrorEnvelope`, `TestNotesMethodNotAllowed` и проверяемые
  литералы `invalid id`/`not found`/`method not allowed`.
- **Canary:** `CANARY-DELETE-STATUS` (`sed s/http.StatusNoContent/http.StatusOK/`
  по `main.go`) сохраняется: DELETE-обработчик и литерал `http.StatusNoContent`
  остаются в `main.go`. Перенос обработчика/литерала без синхронной правки
  `seed`/`detect` запрещён.
- **E2E/deploy:** старый `e2e-preview.sh` с безавторизационными запросами даст
  401 → gate `e2e-preview` красный; скрипт обновляется в этом же прогоне.
  Dockerfile без `COPY web/` ломает embed-сборку.
- **Adapter/UI-граф:** `path1.project.json` уже в целевом состоянии по
  перечисленным полям; `arch/structure/ui-pages/*.yaml` остаются `planned` до
  s21 — gate `graph-actualized` требует актуализации этим прогоном.

## Вне scope

- БД/персистентность, DSN, миграции; рестарт = очистка users/sessions/notes.
- Prod-деплой, canary rollout, `s45.push_primary`, `s46.post_deploy_verify`,
  push в `main`/`stage`/primary.
- `POST /api/logout`, refresh/sliding TTL, password reset/change, remember-me,
  email; logout — только клиентская очистка localStorage.
- Rate limiting, lockout, CAPTCHA.
- Фреймворки, сборщики, npm-рантайм для UI; multi-tenant роли/admin/sharing.

## Риски

| ID | Риск | Влияние | Митигация | Шаг |
|---|---|---|---|---|
| R1 | Утечка `password`/`hash`/`salt`/`token` в JSON или логи | security-блокер | отдельные response-структуры, `json:"-"`, запрет логов кредов, `TestNoSecretLeak` | s20 |
| R2 | Enumeration/timing: разный ответ/время для «нет пользователя» и «неверный пароль» | раскрытие списка users | одинаковый `401`, dummy-PBKDF2, `TestLoginInvalid`; `409` на register принят (OD-06) | s20/s22b |
| R3 | Гонки/TOCTOU: параллельный register, порча users/sessions/notes | 500/дубли/потеря данных | один `Store.mu` + `regMu`, hash вне lock, `go test -race` | s20 |
| R4 | На preview нет docker/сети/Playwright/браузеров | s20c/e2e не зелёный или ложно-зелёный | API-smoke всегда; Playwright обязателен для web, браузеры ставит runner; fail-close без skip | s19/s20c |
| R5 | UI-граф не актуализирован или разъехался с кодом (`source_files`, `data-testid`) | gate `graph-actualized` (s21/s24) красный | s21: `status: implemented`, сверка с фактическим `web/index.html`/селекторами; один источник `ui-pages/*` | s21 |
| R6 | Canary `CANARY-DELETE-STATUS` sed не попадает в литерал | ложно-зелёная канарейка | оставить DELETE и `http.StatusNoContent` в `main.go`; не переносить без правки canary | s20/s22b |
| R7 | Пароль/PBKDF2 под `Store.mu` или 210k итераций в тестах | деградация/зависание тестов | hash вне lock; `pbkdf2Iterations` — `var`, понижать в тестах с восстановлением | s20 |
| R8 | `GET /api/notes` возвращает `null` или `UserID` в JSON | дрейф wire-контракта/утечка владельца | не-nil срез, `Note.UserID json:"-"`, `TestWireContract` | s20 |
| R9 | `http.Error` остаётся где-то → `text/plain`/`\n` | ломает envelope/аудит-оракулы | `writeJSON`/`writeErr` для всех кодов, стабильные литералы | s20 |
| R10 | Dockerfile без `web/` или новые `.go` не скопированы | embed-сборка/образ падает | `COPY web/` (и `COPY *.go`) в build stage, локальный `docker build` | s20/s20b |
| R11 | localStorage + HTTP на стенде (XSS/перехват) | компрометация сессии | dev-only допущение, TTL 24h, пароль не хранится, `Cache-Control: no-store` | s20 |
| R12 | `/healthz` стенда — nginx JSON, app — `ok`; E2E путает | ложный E2E-фейл/успех | e2e проверяет UI/API; health-контракт nginx сохраняется | s20c |

---
Nexus artifact: `f-v3-auth-notes/change-definition` (draft, project f41f0adb-67d9-4ddf-8ba9-0efd9c6e50a9).
