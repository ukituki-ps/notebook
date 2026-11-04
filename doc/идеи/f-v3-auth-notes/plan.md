# f-v3-auth-notes — план фичи (s11.planner_high_level)

- Execution: **E4312**, шаг **s11.planner_high_level**
- Repo: `/workspace/projects/notebook`, ветка `dev/f-v3-auth-notes`, база `8e0e949`
- Change class: **security**; `feature_profile: full`; `path1.ui.json.platform: web`; стенд: **test2**
- Источники: `feature-brief.md`, `change-definition.md`, `scope-report.md`,
  `expertise-report.md`, `intent-brief.md`, `invariants.json`,
  `arch/structure/ui-pages/*.yaml`, `main.go`, `main_test.go`,
  `path1.project.json`, `path1.ui.json`, `deploy/*`.
- Границы шага: **только этот план**. Код, адаптеры, Dockerfile, скрипты деплоя
  и UI-граф на s11 не меняются.

---

## 1. Цель, scope, out-of-scope

### 1.1 Цель

Дать нескольким пользователям работать с «Записной книжкой» на одном dev-инстансе
без доступа к чужим заметкам: регистрация/логин → непрозрачный bearer-токен →
owner-scoped CRUD заметок; статический web UI (login/register/notes) поверх
same-origin `/api/*`; всё in-memory, рестарт = очистка.

### 1.2 Scope (входит)

- Backend: `POST /api/register`, `POST /api/login`, auth-guard на `/api/notes*`,
  `GET/POST/DELETE /api/notes`, единый JSON-envelope ошибок.
- Store: users/sessions/notes в одном in-memory `Store`; PBKDF2-HMAC-SHA256;
  bearer-сессии TTL 24h; owner-scoped выборки.
- UI: `web/index.html` + `web/app.js` + `web/app.css`, маршруты `/login`,
  `/register`, `/notes`, `localStorage["notebook.token"]`, состояния
  loading/empty/list/error, a11y (`label`, `role=alert`, `aria-live=polite`).
- Раздача UI через `go:embed` с явными паттернами; `/` → `302 /login`.
- Тесты: миграция `main_test.go` под auth, новые security-негативы,
  `web_ui_test.go` (UI/embed-семантика), Playwright 7 сценариев.
- Deploy: `deploy/Dockerfile` (build-stage `COPY web/` + Go-файлы),
  `deploy/path1/e2e-preview.sh` (auth-smoke + Playwright).
- Adapter: проверка/актуализация `path1.project.json`, `path1.ui.json`;
  `deploy.stand_command` и `preview-deploy.sh` **не меняются**.
- UI-граф: `arch/structure/ui-pages/*.yaml` актуализируется по коду на s21.

### 1.3 Out-of-scope (не входит)

- БД/персистентность, DSN, миграции; рестарт очищает users/sessions/notes — норма.
- Prod-деплой, canary rollout, `s45.push_primary`, `s46.post_deploy_verify`,
  push в `main`/`stage`/primary.
- `POST /api/logout`, refresh/sliding TTL, password reset/change, remember-me, email.
- Rate limiting, lockout, CAPTCHA (принятый dev-риск, OD-16).
- Фреймворки, сборщики, npm-рантайм для UI.
- Multi-tenant роли/права, admin, sharing заметок.
- Второй UI-граф (`arch/frontend/pages/*`, `UI-GRAPH.yaml`).
- Любые force/skip/waiver; direct-код вне ORC-шагов.

---

## 2. Milestone M01

- **ID:** `M01`
- **Название:** «v3 auth+notes: backend+UI+preview test2»
- **Результат:** U01–U03 смержены; `go test -race ./...` и `go vet ./...` зелёные;
  Docker-образ собирается с `web/`; UI и API выкачены на test2; Playwright 7/7
  зелёные на стенде; `preview-deploy.json` соответствует выкаченному ref.
- **Выход из milestone:** s20a (merge + сводный отчёт) → s20b (preview deploy)
  → s20c (preview verify) закрыты; UI-граф готов к актуализации на s21.

---

## 3. Принципы декомпозиции

1. **Правило процесса:** один unit = один endpoint **или** один экран/компонент
   + его тесты; без «мега-юнитов»; ≤ ~8 файлов на unit.
2. **Файловое ограничение репозитория:** backend живёт в одном `main.go` (требование
   change-definition: DELETE-обработчик и литерал `http.StatusNoContent` остаются
   в `main.go` ради canary). Поэтому backend-поверхность — один unit, а внутри
   него задачи (`T0001..T0003`) разбиты по endpoint-группам. Дробление backend на
   параллельные units дало бы конфликт в одном файле и сломало бы сборку пакета.
3. **UI-ограничение:** три экрана реализуются в одном `web/index.html` +
   одном `web/app.js`; дробление по экранам создало бы конфликт в тех же файлах.
   Экранные acceptance-оракулы вынесены в задачи и Playwright-сценарии.
4. **main.go делится только логически:** U01 — API/Store; U02 — только
   `go:embed` + static handler. Хунк U02 узкий и применяется после U01 на s20a.
5. **Один источник UI-контракта:** `arch/structure/ui-pages/*.yaml`
   (`data-testid`, routes, states, api_calls). Второй граф не создаётся.
6. **Один вход E2E:** `e2e.command` остаётся
   `bash deploy/path1/e2e-preview.sh`; меняется только тело скрипта.
7. **Резерв по строгому endpoint-правилу:** если s17 потребует разбить backend
   по одному endpoint на unit, допускается `U01a` (register/login + session) и
   `U01b` (notes CRUD), но только **последовательно в одном worktree**:
   `main.go`/`main_test.go` общие, параллельный fan-out даст конфликт и сломает
   пакет. Без такого требования U01 остаётся единым unit согласно предложенной
   декомпозиции.

---

## 4. Units

### U01 — `notebook-auth-api`

| Поле | Значение |
|---|---|
| `unit_id` | `notebook-auth-api` |
| `domain` | `notebook-api` |
| `sde` | `sde-backend` |
| `change_class` | `security` |
| `files` | `main.go`, `main_test.go` |
| Зависимости | нет; выполняется параллельно с U02/U03 |
| Порядок merge | **первым** на s20a |

**Scope**

- `Store`: `User`, `Session`, `Note` в одном store; `mu` + `regMu`; хэширование
  и PBKDF2 **вне** `Store.mu`; `now func() time.Time` для тестов TTL.
- Пароли: PBKDF2-HMAC-SHA256 на stdlib (`crypto/hmac`, `crypto/sha256`,
  `encoding/binary`), соль 16B `crypto/rand`, 210 000 итераций (package-level
  `var`), ключ 32B, `crypto/subtle.ConstantTimeCompare`.
- Токен: 32B `crypto/rand`, `base64.RawURLEncoding`, непрозрачный; TTL 24h fixed;
  ленивое удаление истёкшей сессии; `crypto/rand` failure → 500 без деградации.
- `POST /api/register`: 201 `{"id","username"}`, 400 (пустые/невалидные поля,
  тело > 1 MiB), 409 `username taken`, 405 + `Allow: POST`.
- `POST /api/login`: 200 `{"token"}`, 400, 401 (одинаковый для «нет пользователя»
  и «неверный пароль», dummy-PBKDF2), 405 + `Allow: POST`.
- Auth-guard на `/api/notes` и `/api/notes/`: порядок **auth → method → path/id →
  body**; 401 + `WWW-Authenticate: Bearer` + `{"error":"unauthorized"}`.
- `GET /api/notes`: 200, только свои, `[]` (не `null`); `UserID` не сериализуется.
- `POST /api/notes`: 201 `{"id","text"}`, владелец из токена, 400 пустой/длинный
  text (1–4096).
- `DELETE /api/notes/{id}`: 204 своя; 400 нечисловой/пустой/overflow id;
  404 нет/чужая; 405 + `Allow: DELETE`; литерал `http.StatusNoContent` и
  обработчик остаются в `main.go`.
- Единый JSON-envelope `{"error":"..."}` для всех кодов; `writeJSON`/`writeErr`;
  стабильные литералы `invalid id`, `not found`, `method not allowed`,
  `text required`; `Content-Type: application/json`; на 405 — `Allow`.
- Тесты: миграция всех существующих под auth; сохранить **имена**
  `TestDeleteNote`, `TestDeleteErrorEnvelope`, `TestNotesMethodNotAllowed`;
  helpers `seedUser(t,h) (username, token)` и
  `authedRequest(t,h,method,path,body,token)`; `mustSeedNote` получает токен.
- Новые/сохранённые тесты: `TestNotesLifecycle`, `TestAddNote`,
  `TestDeleteExisting`, `TestDeleteMissing`, `TestDeleteInvalidID`,
  `TestListAfterDelete`, `TestAuthRequired`, `TestRegister`, `TestLogin`,
  `TestLoginInvalid`, `TestNotesIsolation`, `TestDeleteForeignNote`,
  `TestNoSecretLeak`, `TestPasswordHashed`, `TestTokenExpiry`,
  `TestWireContract`, `TestHTTPTransport`, `TestNotesPrefixBoundary`,
  `TestAuthMethodOrder`.
- Без build-тегов `integration/e2e/manual`; без новых зависимостей `go.mod`.

**Acceptance-оракулы**

```sh
go build ./...
go vet ./...
go test -race ./...
go test -count=1 -run 'TestAuthRequired|TestLoginInvalid|TestNotesIsolation|TestDeleteForeignNote' ./...
go test -count=1 -run 'TestRegister|TestLogin|TestNoSecretLeak|TestPasswordHashed|TestTokenExpiry' ./...
go test -count=1 -run 'TestWireContract|TestHTTPTransport|TestNotesPrefixBoundary|TestAuthMethodOrder' ./...
go test -count=1 -run 'TestDeleteNote|TestDeleteErrorEnvelope|TestNotesMethodNotAllowed' ./...
grep -n 'http.StatusNoContent' main.go          # непусто; DELETE в main.go
git diff --exit-code go.mod                      # без новых зависимостей
sh -c "! grep -R -E '^//go:build.*(integration|e2e|manual)' --include='*_test.go' ."
```

Дополнительно: `GET /api/notes` при пустом списке отдаёт `[]`, не `null`;
`Authorization` проверяется раньше method/id/body (401 на неавторизованный `PUT`
и `DELETE /api/notes/abc`).

---

### U02 — `notebook-web-ui`

| Поле | Значение |
|---|---|
| `unit_id` | `notebook-web-ui` |
| `domain` | `notebook-web` |
| `sde` | `sde-frontend` |
| `change_class` | `security` |
| `files` | `web/index.html`, `web/app.js`, `web/app.css`, `web/e2e/auth-notes.spec.js`, `playwright.config.js`, `web_ui_test.go`, `main.go` (только embed+static) |
| Зависимости | `web/*` — нет; `main.go`-хук — после U01 на s20a |
| Порядок merge | **вторым** на s20a (embed после API) |

**Scope**

- `web/index.html` — единый HTML-вход; клиентские экраны `/login`, `/register`,
  `/notes`; разметка по `arch/structure/ui-pages/*.yaml`: `data-testid`
  (`login-card`, `login-form`, `login-username`, `login-password`, `login-submit`,
  `login-error`, `register-link`, `register-*`, `notes-*`, `note-item`,
  `delete-note`, `notes-empty`, `notes-loading`, `logout`, `user-name`).
- `web/app.css` — колонка ≤640px; breakpoint 640px; mobile <640px в одну колонку;
  full-width кнопки; touch-target ≥44px; `overflow-wrap: anywhere`; читаемый
  контраст; focus-visible.
- `web/app.js` — login/register/notes:
  - login: `POST /api/login`; 200 → `notebook.token`/`notebook.user` +
    `location.replace("/notes")`; 400/401 → inline `[role=alert]`; пароль
    очищается при 401; double-submit заблокирован.
  - register: confirm-password только клиентски; `POST /api/register`;
    201 → `/login` с предзаполненным username; 400/409 → inline-ошибки.
  - notes: нет токена → `/login` без запроса; иначе `GET /api/notes`
    (loading/empty/list), `POST /api/notes`, `DELETE /api/notes/{id}`;
    любой 401 → очистка `notebook.token`/`notebook.user` +
    `location.replace("/login")`; 400 — рядом с формой; 404 при удалении →
    сообщение + повторный GET; empty state `data-testid="notes-empty"`;
    logout — только клиентский; без фантомных/захардкоженных заметок;
    одна видимая ошибка.
- `main.go` (только integration-хук): `//go:embed web/index.html web/app.js
  web/app.css`; статические маршруты `/`, `/login`, `/register`, `/notes`,
  `/app.js`, `/app.css`; `/` → `302 /login`; HTML `Cache-Control: no-store`;
  корректный `Content-Type`; API-маршруты не перекрываются.
- `web_ui_test.go` (package main) — `TestUISemantics`: embed-ресурсы существуют,
  нужные `data-testid`, `label`, `role=alert`, `aria-live=polite`, empty state,
  нет захардкоженных заметок. Вынесен из `main_test.go`, чтобы не конфликтовать
  с U01.
- `web/e2e/auth-notes.spec.js` + `playwright.config.js` — 7 сценариев,
  `baseURL` из `E2E_BASE_URL`, `chromium`, уникальные username на прогон,
  независимость от порядка, отдельные browser context для A/B.

**Acceptance-оракулы**

```sh
node --check web/app.js
go build ./...
go test -race ./...
go test -count=1 -run 'TestUISemantics' ./...
npx playwright test --list          # ровно 7 сценариев
grep -q 'data-testid="notes-empty"' web/index.html
grep -q 'role="alert"' web/index.html
grep -q 'aria-live="polite"' web/index.html
grep -q 'Authorization' web/app.js
grep -q 'notebook.token' web/app.js
grep -q 'COPY web/ ./web/' deploy/Dockerfile   # проверяется в U03, не здесь
```

Full-прогон 7 сценариев — на s20c (после U01): локально U02 проверяет статику,
`TestUISemantics`, `--list` и сборку; Playwright против auth-API требует
смерженного U01.

---

### U03 — `notebook-deploy-e2e`

| Поле | Значение |
|---|---|
| `unit_id` | `notebook-deploy-e2e` |
| `domain` | `notebook-deploy` |
| `sde` | `sde-infra` |
| `change_class` | `security` |
| `files` | `deploy/Dockerfile`, `deploy/path1/e2e-preview.sh`, `path1.project.json`, `path1.ui.json`, `.dockerignore` |
| Зависимости | нет для правок; runtime-проверка — после merge U01+U02 (s20b/s20c) |
| Порядок merge | **третьим** на s20a |

**Scope**

- `deploy/Dockerfile`: в **build stage** добавить `COPY web/ ./web/` **до**
  `go build`; `COPY *.go ./` (или явное копирование всех build-файлов) вместо
  только `main.go`; runtime-stage и `ENTRYPOINT` не меняются.
- `.dockerignore`: `web/e2e/`, `web/node_modules/`, тестовые артефакты.
- `deploy/path1/e2e-preview.sh`:
  - сохранить `E2E_BASE_URL`/`PREVIEW_BASE_URL` и проверку `/healthz` стенда
    (**nginx JSON**, не app-`ok`);
  - register/login двух пользователей (A/B), authed `GET/POST/DELETE /api/notes`;
  - проверить 401 без токена, изоляцию A/B (B не видит note A), 404 на чужую;
  - запустить Playwright (`chromium`) из корня/`web`, `baseURL` из env;
  - при отсутствии браузеров/Playwright — **fail-close** с явной ошибкой,
    не skip и не «зелёный» E2E.
- `path1.project.json`: подтвердить `graph.source_roots=["web"]`,
  `e2e.frontend_dir="web"`, `e2e.command="bash deploy/path1/e2e-preview.sh"`,
  `audit.mode="app"`, `audit.database=false`, `canaries.require_dsn=false`,
  `deploy.stand_command="bash deploy/path1/preview-deploy.sh {stand} {ref}"`;
  при необходимости расширить `audit.oracles` (`SEC-AUTH-REQUIRED`,
  `SEC-USER-ISOLATION`), не ломая существующие имена.
- `path1.ui.json`: `platform: "web"`.
- `deploy/path1/preview-deploy.sh` **не редактируется**.
- `preview-deploy.json` (корень репо) материализуется на s20b из фактического
  деплоя: `stand`, `url`, `sha` = выкаченный ref, `commit`, `image_digest`,
  `build_ref`, `deployed_at`. Не брать локальный HEAD.

**Acceptance-оракулы**

```sh
bash -n deploy/path1/e2e-preview.sh
jq -e '.graph.source_roots == ["web"]
  and .e2e.frontend_dir == "web"
  and .e2e.command == "bash deploy/path1/e2e-preview.sh"
  and .audit.mode == "app"
  and .audit.database == false
  and .canaries.require_dsn == false
  and .deploy.stand_command == "bash deploy/path1/preview-deploy.sh {stand} {ref}"' \
  path1.project.json
jq -e '.platform == "web"' path1.ui.json
git diff --exit-code deploy/path1/preview-deploy.sh
grep -n 'COPY web/ ./web/' deploy/Dockerfile
awk '/COPY web\/ \.\/web\//{w=NR} /go build/{b=NR} END{exit !(w && b && w<b)}' deploy/Dockerfile
```

Full `docker build` + preview deploy — на s20b (нужен смерженный `web/`);
auth-smoke + Playwright — на s20c.

---

## 5. Tasks T0001..T0009

| Task | Unit | Файлы | Oracle (кратко) | Зависит от |
|---|---|---|---|---|
| **T0001** Store + PBKDF2 + sessions | U01 | `main.go`, `main_test.go` | `TestPasswordHashed`, `TestTokenExpiry`; `go test -race`; hash вне lock | — |
| **T0002** register/login + auth-guard + JSON-envelope | U01 | `main.go`, `main_test.go` | `TestRegister`, `TestLogin`, `TestLoginInvalid`, `TestAuthRequired`, `TestNoSecretLeak`, `TestWireContract`, `TestAuthMethodOrder`, `TestHTTPTransport` | T0001 |
| **T0003** notes owner-scoped + миграция тестов + canary | U01 | `main.go`, `main_test.go` | `TestDeleteNote`, `TestDeleteErrorEnvelope`, `TestNotesMethodNotAllowed`, `TestNotesIsolation`, `TestDeleteForeignNote`, `TestDeleteInvalidID`, `TestNotesPrefixBoundary`, `TestAddNote`, `TestListAfterDelete`, `TestNotesLifecycle`; `grep http.StatusNoContent main.go` | T0001, T0002 |
| **T0004** HTML-каркас 3 экранов + CSS | U02 | `web/index.html`, `web/app.css` | статические grep по `data-testid`, `label`, `role=alert`, `aria-live`, empty/loading; breakpoint 640px; touch ≥44px | — |
| **T0005** app.js + embed/static + UI-тесты | U02 | `web/app.js`, `web_ui_test.go`, `main.go` (embed) | `node --check`, `TestUISemantics`, `go build`, статика `/login`/`/notes`/`/app.js` | T0004 |
| **T0006** Playwright 7 сценариев + config | U02 | `web/e2e/auth-notes.spec.js`, `playwright.config.js` | `npx playwright test --list` = 7; уникальные users; отдельные contexts; full run на s20c | T0005 |
| **T0007** Dockerfile + .dockerignore | U03 | `deploy/Dockerfile`, `.dockerignore` | `COPY web/` до `go build`; `COPY *.go`; runtime без изменений; `docker build` на s20b | — |
| **T0008** e2e-preview.sh auth + Playwright | U03 | `deploy/path1/e2e-preview.sh` | `bash -n`; health nginx JSON; register/login → authed GET/POST/DELETE; 401; изоляция A/B; fail-close без браузеров; full на s20c | T0007 |
| **T0009** adapter + oracles | U03 | `path1.project.json`, `path1.ui.json` | `jq`-проверки полей; `preview-deploy.sh` без diff; `audit.oracles` не ломает существующие имена | — |

---

## 6. Порядок исполнения s20

### s20 — fan-out

- 3 unit-ветки/воркtree параллельно (`max_parallel: 3`): U01, U02, U03.
- U01 и U02 пересекаются только в `main.go`; U02 заранее ограничивает хунк
  embed/static, U01 не трогает embed.
- U03 не трогает Go-код; его Docker-проверка отложена до s20b (нужен `web/`).

### s20a — merge + сводный отчёт

1. Merge **U01** → `go test -race ./...`, `go vet ./...`, canary-grep.
2. Merge **U02** → разрешить `main.go`: сохранить auth/Store U01 и добавить
   `//go:embed web/index.html web/app.js web/app.css` + static handler U02.
   При конфликте — **embed U02 после API U01**, не наоборот.
3. Merge **U03** → Dockerfile/adapter/e2e-скрипт.
4. `go build ./...`, `go test -race ./...`, `go vet ./...`,
   `go test -run TestUISemantics`, `git diff --exit-code go.mod`.
5. Сводный `artifacts/units/integration-report.md`; contract parity
   (5 эндпоинтов, envelope, 401-before-method).

### s20b — preview deploy (test2)

1. `docker build` с `COPY web/` (иначе embed-сборка падает).
2. `bash deploy/path1/preview-deploy.sh test2 <ref>` — **без изменений**.
3. Проверить `/healthz` стенда: nginx JSON (`build_ref`, `commit` 40hex).
4. Материализовать `preview-deploy.json` из фактического деплоя
   (`sha` = выкаченный ref, не локальный HEAD).
5. Gate `preview-verified` — зелёный.

### s20c — preview verify (E2E)

1. `E2E_BASE_URL=http://127.0.0.1:9082 bash deploy/path1/e2e-preview.sh`.
2. Health (nginx JSON) → curl auth-smoke (401 → register/login A/B → authed
   GET/POST/DELETE → изоляция A/B) → Playwright 7/7 (`chromium`).
3. Нет браузеров/Playwright — fail-close с явной ошибкой, не skip.
4. Evidence: `e2e-report`, screenshots ключевых состояний; привязать к SHA
   стенда из `preview-deploy.json`.
5. `INV-UI-E2E-PREVIEW` остаётся `proposed` до этого шага; evidence закрывает
   его на s20c.

---

## 7. Тест-план

### 7.1 Go

Базовый прогон:

```sh
go build ./...
go vet ./...
go test -race ./...
```

| Тест | Что закрепляет |
|---|---|
| `TestNotesLifecycle` | health + POST/GET notes под auth |
| `TestAddNote` | POST 201 `{id,text}`, владелец из токена |
| `TestDeleteNote` | 204 своя; повторно/чужая/нет → 404; `abc` → 400; список без удалённой |
| `TestDeleteExisting` | 204 + отсутствие в List |
| `TestDeleteMissing` | 404 `{"error":"not found"}` |
| `TestDeleteInvalidID` | 400 `{"error":"invalid id"}` для `abc`/пустой/overflow; negative без паники |
| `TestListAfterDelete` | List = ровно оставшиеся свои |
| `TestNotesMethodNotAllowed` | authed GET/POST/PUT/PATCH на item → 405 + тело |
| `TestDeleteErrorEnvelope` | authed 400/404 envelope, без утечек |
| `TestAuthRequired` | все методы `/api/notes*` без/битый/истёкший токен → 401 до 405/400 |
| `TestRegister` | 201/400/409/405 |
| `TestLogin` | 200 `{token}`; 400; 401 |
| `TestLoginInvalid` | 401 одинаков для «нет пользователя» и «неверный пароль» |
| `TestNotesIsolation` | A не видит/не удаляет note B; DELETE B → 404 |
| `TestDeleteForeignNote` | чужая → 404 (не 403) |
| `TestNoSecretLeak` | в JSON нет `password`/`hash`/`salt`; `token` только в login 200 |
| `TestPasswordHashed` | PBKDF2 детерминизм, разные соли, constant-time compare |
| `TestTokenExpiry` | инъекция `now`: до TTL 200, после 401, сессия удалена |
| `TestWireContract` | ключи ровно `id/text/token/username/error`, нижний регистр |
| `TestHTTPTransport` | httptest.Server, не прямые вызовы Store |
| `TestNotesPrefixBoundary` | нечисловой/пустой/отрицательный/overflow id → 400/404 без паники |
| `TestAuthMethodOrder` | auth раньше method/id/body |
| `TestUISemantics` | embed-ресурсы, `data-testid`, `role=alert`, `aria-live`, labels, empty state, нет фантомных заметок |

Требования: без build-тегов `integration/e2e/manual`; `pbkdf2Iterations` —
`var`, тесты понижают с восстановлением; canary
`CANARY-DELETE-STATUS` (`sed s/http.StatusNoContent/http.StatusOK/ main.go`)
остаётся валидной.

### 7.2 Playwright — ровно 7 сценариев

`web/e2e/auth-notes.spec.js`, `playwright.config.js`, `chromium`,
`baseURL = E2E_BASE_URL`, уникальные username на прогон, отдельные
`browser.newContext()` для A/B, сценарии независимы от порядка.

1. Регистрация нового пользователя (201 → `/login`).
2. Логин, токен в `localStorage["notebook.token"]` (200 → `/notes`).
3. Создание заметки (201, строка в списке).
4. Reload `/notes` — заметка видна (сессия сохранилась).
5. Удаление заметки (204, строка убрана / empty state).
6. User B не видит заметку User A (два context).
7. Неавторизованный `GET /api/notes` → 401 (APIRequestContext).

### 7.3 Preview smoke (`e2e-preview.sh`)

1. `/healthz` стенда — nginx JSON (`build_ref`, `commit` 40hex).
2. `GET /api/notes` без токена → 401.
3. `POST /api/register` A и B → 201/409-логика уникальных имён.
4. `POST /api/login` A/B → 200 + token.
5. Authed `POST /api/notes` A → 201; `GET /api/notes` A содержит note;
   `GET /api/notes` B не содержит note A.
6. Authed `DELETE` note A → 204; повторно/чужая → 404; `abc` → 400.
7. Playwright 7/7; отсутствие браузеров → fail-close.

### 7.4 Инварианты → оракулы

| Invariant | Оракул |
|---|---|
| `INV-AUTH-REQUIRED` | `TestAuthRequired`, `TestLoginInvalid` |
| `INV-USER-ISOLATION` | `TestNotesIsolation`, `TestDeleteForeignNote` |
| `INV-NO-SECRET-LEAK` | `TestNoSecretLeak` |
| `INV-PASSWORD-HASHED` | `TestPasswordHashed` |
| `INV-VERB-REJECT` | `TestNotesMethodNotAllowed`, `TestAuthMethodOrder` |
| `INV-PREFIX-BOUNDARY` | `TestDeleteInvalidID`, `TestNotesPrefixBoundary` |
| `INV-WIRE-CASING` | `TestWireContract` |
| `INV-REAL-TRANSPORT` | `TestHTTPTransport` |
| `INV-NO-SKIP-TAGS` | `grep`-оракул из `invariants.json` |
| `INV-UI-TRUTH/LABEL/A11Y-NAME/EMPTY-STATE` | `TestUISemantics` |
| `INV-UI-ORACLE` | `proposed` → `ui-audit.json` на s22a |
| `INV-UI-E2E-PREVIEW` | `proposed` → `e2e-preview.sh` + screenshots на s20c |

---

## 8. Риски и митигации

| ID | Риск | Митигация | Шаг |
|---|---|---|---|
| R1 | Конфликт `main.go` U01/U02 | U02 хук — только embed/static; merge U02 после U01; при конфликте embed после API; повторный `go test -race` | s20a |
| R2 | `go:embed` до появления `web/` | U02 создаёт `web/*` и embed в одном unit; Docker не собирается до merge; `COPY web/` до `go build` | s20a/s20b |
| R3 | Dockerfile не копирует `web/`/Go-файлы | `COPY *.go`, `COPY web/ ./web/`; `.dockerignore`; локальный `docker build` | s20/s20b |
| R4 | Нет Playwright/браузеров на runner | API-smoke всегда; Chromium ставит runner; отсутствие → fail-close, не skip | s20c |
| R5 | UI-граф расходится с кодом | Один источник `arch/structure/ui-pages/*`; s21 `status: implemented`, сверка `source_files`/selectors по факту; не создавать второй граф | s21 |
| R6 | `CANARY-DELETE-STATUS` sed не попадает | DELETE-обработчик и `http.StatusNoContent` остаются в `main.go`; grep-оракул; не переносить без правки canary | s20/s22b |
| R7 | `preview-deploy.json` с локальным HEAD | s20b пишет `sha` из фактического деплоя/provenance; s22a копирует его в `ui-audit.json` | s20b/s22a |
| R8 | Утечка `password`/`hash`/`salt`/`token` | response-структуры, `json:"-"`, запрет логов кредов, `TestNoSecretLeak` | s20 |
| R9 | PBKDF2 под `Store.mu` / медленные тесты | hash вне lock; `regMu`; `pbkdf2Iterations` — `var`, понижать в тестах с восстановлением | s20 |
| R10 | `null` вместо `[]` или `UserID` в JSON | `make([]Note, 0, ...)`, `Note.UserID json:"-"`, `TestWireContract` | s20 |
| R11 | 404 vs 403 / порядок auth | `TestDeleteForeignNote`, `TestAuthRequired`, `TestAuthMethodOrder` | s20 |
| R12 | `/healthz` стенда — nginx JSON, app — `ok` | e2e проверяет nginx JSON; Playwright не проверяет app-health | s20c |
| R13 | localStorage + HTTP на стенде | dev-only допущение; TTL 24h; пароль не хранится; `Cache-Control: no-store` | s20 |
| R14 | Adapter path10 сломан | `deploy.stand_command` и `preview-deploy.sh` не менять; `git diff --exit-code` | s20a |

---

## 9. Definition of Done (фича)

- [ ] U01–U03 смержены на `dev/f-v3-auth-notes`; конфликтов нет.
- [ ] `go build ./...`, `go vet ./...`, `go test -race ./...` — зелёные.
- [ ] Все обязательные тесты присутствуют; имена `TestDeleteNote`,
      `TestDeleteErrorEnvelope`, `TestNotesMethodNotAllowed` сохранены;
      build-тегов `integration/e2e/manual` нет.
- [ ] Canary `CANARY-DELETE-STATUS` валиден: DELETE и `http.StatusNoContent`
      в `main.go`.
- [ ] UI отдаётся через `go:embed`; `/login`, `/register`, `/notes` работают;
      `data-testid`/`role=alert`/`aria-live`/empty state на месте.
- [ ] Docker-образ собирается (`COPY web/` до `go build`); `preview-deploy.sh`
      не изменён.
- [ ] Preview test2 развёрнут; `/healthz` — nginx JSON; `preview-deploy.json`
      содержит `sha` выкаченного ref.
- [ ] `e2e-preview.sh` auth-smoke зелёный; Playwright 7/7 зелёные; evidence
      (e2e-report/screenshots) привязан к SHA стенда.
- [ ] `arch/structure/ui-pages/*.yaml` актуализированы на s21
      (`status: implemented`); второго графа нет.
- [ ] s22a `ui-audit.json`: блоки A–L, `open_critical_high=0`, у каждого item
      есть `oracle` и `evidence`.
- [ ] Adapter в целевом состоянии: `frontend_dir=web`, `platform=web`,
      `audit.mode=app`, `database=false`, `canaries.require_dsn=false`,
      `deploy.stand_command` — path10.
- [ ] Out-of-scope не затронут: нет БД, `POST /api/logout`, refresh TTL,
      prod/canary rollout, `s45/s46`, push primary, force/skip/waiver.
- [ ] s20a/s20b/s20c и гейты s21/s22a/s24 пройдены штатно.

---

## 10. Заготовка `unit_briefs` для s16

```json
{
  "unit_briefs": [
    {
      "unit_id": "notebook-auth-api",
      "domain": "notebook-api",
      "sde": "sde-backend",
      "change_class": "security",
      "scope": [
        "Store users/sessions/notes: mu+regMu, hash вне lock, now для TTL",
        "PBKDF2-HMAC-SHA256 stdlib: 16B salt, 210k iterations (var), 32B key, constant-time compare",
        "Opaque token 32B crypto/rand, base64.RawURLEncoding, TTL 24h fixed, lazy expiry",
        "POST /api/register: 201/400/409/405, MaxBytesReader 1MiB",
        "POST /api/login: 200/400/401/405, dummy-PBKDF2 anti-enumeration",
        "Auth guard /api/notes*: auth -> method -> path/id -> body; 401 + WWW-Authenticate",
        "GET /api/notes owner-scoped: 200 [] not null, UserID not serialized",
        "POST /api/notes owner from token: 201/400",
        "DELETE /api/notes/{id}: 204/400/404/405; http.StatusNoContent stays in main.go",
        "JSON envelope writeJSON/writeErr all codes, Allow on 405",
        "Tests: migrate all under auth, preserve TestDeleteNote/TestDeleteErrorEnvelope/TestNotesMethodNotAllowed; seedUser/authedRequest; all negatives; no secret leak",
        "No new go.mod deps; no build tags"
      ],
      "files": ["main.go", "main_test.go"]
    },
    {
      "unit_id": "notebook-web-ui",
      "domain": "notebook-web",
      "sde": "sde-frontend",
      "change_class": "security",
      "scope": [
        "web/index.html: /login /register /notes markup, ui-pages data-testid, labels, role=alert, aria-live",
        "web/app.css: <=640px column, mobile one column, full-width, touch >=44px, overflow-wrap",
        "web/app.js: login/register/notes, fetch same-origin, Bearer, localStorage notebook.token/user, 400/401/409, 401 clear+replace",
        "register confirm-password client-only; notes loading/empty/list; add/delete; client logout; no phantom notes",
        "main.go integration hunk: go:embed explicit web files, static routes /login /register /notes /app.js /app.css, / -> 302 /login, Cache-Control no-store",
        "web_ui_test.go TestUISemantics: embed resources, testids, labels, role=alert, aria-live, empty state, no hardcoded notes",
        "Playwright 7 scenarios + config: register, login token, create, reload, delete, isolation A/B, 401"
      ],
      "files": [
        "web/index.html",
        "web/app.js",
        "web/app.css",
        "web/e2e/auth-notes.spec.js",
        "playwright.config.js",
        "web_ui_test.go",
        "main.go"
      ]
    },
    {
      "unit_id": "notebook-deploy-e2e",
      "domain": "notebook-deploy",
      "sde": "sde-infra",
      "change_class": "security",
      "scope": [
        "Dockerfile build stage: COPY web/ ./web/ before go build, COPY *.go; runtime unchanged",
        ".dockerignore: web/e2e, web/node_modules",
        "e2e-preview.sh: E2E_BASE_URL, nginx /healthz JSON, register/login A/B, authed GET/POST/DELETE, 401, isolation A/B, Playwright chromium, fail-close without browsers",
        "path1.project.json: graph.source_roots=web, frontend_dir=web, e2e.command unchanged, audit.mode=app, database=false, require_dsn=false, stand_command path10 unchanged; oracles preserved",
        "path1.ui.json: platform=web",
        "preview-deploy.sh unchanged; preview-deploy.json materialized at s20b with deployed sha"
      ],
      "files": [
        "deploy/Dockerfile",
        "deploy/path1/e2e-preview.sh",
        "path1.project.json",
        "path1.ui.json",
        ".dockerignore"
      ]
    }
  ]
}
```

---

## 11. Итог

- 1 milestone (M01), 3 units, 9 tasks.
- U01 и U03 стартуют параллельно; U02 параллелен по `web/*`, его `main.go`-хук
  вливается после U01 на s20a.
- Критический путь: U01 → (embed U02) → s20a → s20b (Docker + test2) → s20c
  (auth-smoke + Playwright) → s21 (graph actualize) → s22a (ui-audit) → s24.
- Главные риски: merge `main.go`, embed до `web/`, Dockerfile, Playwright на
  стенде, canary `CANARY-DELETE-STATUS`, SHA в `preview-deploy.json`.
