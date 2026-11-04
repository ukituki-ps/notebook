# Expertise Report — f-v3-auth-notes (s05.architect_validation)

- Execution: **E4312**, шаг **s05.architect_validation**
- Repo: `/workspace/projects/notebook`, ветка `dev/f-v3-auth-notes`, база `8e0e949`
- Дата: 2026-11-04
- Роль: architect
- Источники: `feature-request.md` (неизменяем), `feature-brief.md` (s01+s03),
  `scope-report.md` (s02), `arch/structure/ui-pages/{login,register,notes}.yaml`
  (s04), `path1.project.json`, `path1.ui.json`, `main.go`, `main_test.go`,
  `deploy/Dockerfile`, `deploy/path1/e2e-preview.sh`,
  `deploy/path1/preview-deploy.sh`, `arch/processes/path-1.feature.yaml`
  (только чтение — требования s21/s22a/s24).
- Границы шага: **только этот документ**. Код, адаптеры, Dockerfile, скрипты
  деплоя, UI-граф и process-definition на s05 не редактируются.

Сокращения ссылок:

- `FR:<строка>` — `doc/идеи/f-v3-auth-notes/feature-request.md`
- `FB:<строка>` — `doc/идеи/f-v3-auth-notes/feature-brief.md`
- `SR:<строка>` — `doc/идеи/f-v3-auth-notes/scope-report.md`
- `OD-xx` — open decision из §3 (нумерация совместима с `SR §5`)

> **Конвенция о B\* и OD\*.** `B1..B10` — это проектное состояние, в котором
> дизайн архитектурно состоятелен. Там, где сырой запрос допускает ≥2 прочтения,
> соответствующее `B*` опирается на рекомендацию `OD-*` и **не считается
> закрытым до подтверждения человеком на s08**. Молчаливых решений нет:
> каждая такая развилка вынесена в §3 и уходит в `s07.requirements_reconcile`
> как вопрос, а не как факт.

---

## 0. Резюме

**Вердикт: CONDITIONAL PASS.**

Дизайн s01–s04 в целом соответствует ограничениям: stdlib-only, in-memory,
один процесс, path-10, web UI, preview на test2. Однако **до s20 нельзя
начинать реализацию без устранения пяти блокеров**, а до s06 нужно
подтвердить/вынести open decisions:

| # | Блокер | Почему блокер | Где закрывать |
|---|---|---|---|
| K1 | `deploy/Dockerfile` копирует только `main.go` | при `go:embed` и любом новом `.go`-файле сборка образа упадёт; UI не попадёт в бинарь | s20/s20b |
| K2 | `deploy/path1/e2e-preview.sh` не умеет auth | после введения auth старые `GET/POST /api/notes` дают 401 → gate `e2e-preview` красный | s20a/s20c |
| K3 | UI-граф ссылается на `web/index.html`, а wireframes s03 — на 3 HTML-файла | s21 `graph-actualized` требует граф по коду; расхождение даст model drift | s06 (OD-09) → s21 |
| K4 | Селекторы s04 (`[data-testid=...]`) расходятся с предложением s03 (`#login-form`, ...) | UI-аудит и E2E будут искать несуществующие элементы | s20 → s21 |
| K5 | `preview-deploy.json` с `stand.sha` не создаётся текущим `preview-deploy.sh` | s22a `gate-ui-audit` сверяет SHA стенда и упадёт «аудит не на том билде» | s20b/s22a |

Дополнительно: `s21` в process-definition пишет `arch/frontend/pages/*.yaml`,
а гейт принимает `arch/structure/ui-pages/*.yaml` — это риск раздвоения
источника истины (см. §5.2).

---

## 1. Вердикт по архитектурным ограничениям

| # | Ограничение | Вердикт | Доказательство / замечание |
|---|---|---|---|
| C1 | Только stdlib, `go.mod` без зависимостей | **PASS (conditional)** | PBKDF2 реализуется на `crypto/hmac`+`crypto/sha256`; `golang.org/x/crypto`, JWT и веб-фреймворки запрещены. Условие: не поддаться на bcrypt/argon2 (OD-02). |
| C2 | In-memory users/sessions/notes | **PASS** | `Store` в памяти; рестарт = очистка (FR:27,33; FB §2.3). |
| C3 | Один процесс, один бинарь, `:8080` | **PASS** | `main.go` + `http.ListenAndServe`; embed не добавляет второй процесс. |
| C4 | path-10 adapter не ломать | **PASS (conditional)** | `deploy.stand_command` и `preview-deploy.sh` не меняются; `e2e.command` остаётся `bash deploy/path1/e2e-preview.sh`, меняется только тело скрипта. Условие — K2. |
| C5 | Web UI: login/register/notes, без React/Vue | **PASS (conditional)** | Статический HTML/JS/CSS + `go:embed`; Playwright — только тест-тулинг, не runtime UI. Условия — K1, K3, K4. |
| C6 | Preview на test2, без prod | **PASS** | `preview-deploy.sh` разрешает только `test2` и запрещает `*prod*`; `s45/s46` не запускаются (FR:62–67). |
| C7 | Без БД/DSN | **PASS** | `audit.database=false`, `canaries.require_dsn=false`, `dsn_command=""` уже в `path1.project.json`. |
| C8 | Go 1.23 | **PASS (conditional)** | `go.mod` = `go 1.23`; `crypto/pbkdf2` появился в 1.24 → локальная реализация. Не повышать версию ради одной функции. |
| C9 | Офлайн сборка/тесты | **PASS (conditional)** | stdlib-only; Playwright-браузеры — ответственность runner, E2E fail-close, а не тихий skip. |
| C10 | Секреты не утекают | **PASS (conditional)** | Отдельные response-структуры, `json:"-"`, тест `TestPasswordNotLeaked`; не логировать creds. |
| C11 | Никаких force/skip/waiver, direct-код вне шагов | **PASS** | В границах s05 не применяются; шаг пишет только этот документ. |

### 1.1. Нарушения и риски

Severity: **Critical** — ломает приёмку/безопасность; **High** — ломает шаг или
контракт; **Medium** — требует правки до/во время реализации; **Low** —
желательное улучшение.

| ID | Sev | Нарушение / риск | Митигация | Шаг |
|---|---|---|---|---|
| R1 | **Critical** | `deploy/Dockerfile` (`COPY main.go ./`) не скопирует новые `.go`-файлы и `web/`; `go:embed` не соберётся, образ не стартует | в build-stage: `COPY *.go ./` (или `COPY . .` с `.dockerignore`) + `COPY web/ ./web/`; локально `docker build`; runtime-stage не менять | s20/s20b |
| R2 | **Critical** | `e2e-preview.sh` делает безавторизационные `GET/POST /api/notes`; после auth это 401 → gate `e2e-preview` красный | переписать скрипт: health → register/login → authed GET/POST/DELETE → проверка 401 → Playwright; `e2e.command` не менять | s20a/s20c |
| R3 | **High** | UI-граф s04: `source_files: web/index.html` у всех трёх страниц, тогда как s03 рисует `login.html`/`register.html`/`notes.html` | выбрать форму UI (OD-09) и привести `source_files`, routes, selectors к коду на s21; не оставлять «planned»-граф | s06/s20/s21 |
| R4 | **High** | Селекторы s04 — `[data-testid=...]`, s03 предлагает `#login-form`, `#note-input`, `#notes-list`; код может реализовать третье | зафиксировать один контракт (рекомендация: `data-testid` + `id` для form-полей); s20 реализует, s21 актуализирует по коду | s20/s21 |
| R5 | **High** | `s21.arch_writes` в процессе указывает `arch/frontend/pages/*.yaml`, а gate `graph-actualized` — `arch/structure/ui-pages/*.yaml` | оставить единственный источник — `arch/structure/ui-pages/*.yaml`; не создавать `arch/frontend/pages` и `UI-GRAPH.yaml` одновременно | s21 |
| R6 | **High** | `main_test.go` целиком безавторизационный; после auth все тесты упадут 401 | мигрировать тесты, сохранив имена `TestDeleteNote`, `TestDeleteErrorEnvelope`, `TestNotesMethodNotAllowed`; helper `seedUser`/`authedRequest` | s20 |
| R7 | **High** | Canary `CANARY-DELETE-STATUS` делает `sed s/http.StatusNoContent/http.StatusOK/ {worktree}/main.go` | оставить DELETE-обработчик и литерал `http.StatusNoContent` в `main.go`; не переносить в другой файл без синхронной правки canary `seed`/`detect` | s20/s22b |
| R8 | **Medium** | PBKDF2 210k итераций под `Store.mu` заблокирует все запросы | хэширование и проверка — **вне `Store.mu`**; `regMu` сериализует register (check+hash+insert); `List` копирует под lock | s20 |
| R9 | **Medium** | Enumeration/timing: «нет пользователя» и «неверный пароль» могут отличаться по времени | одинаковый 401 + dummy-PBKDF2 для несуществующего username; 409 на register — осознанно (OD-06) | s20/s22b |
| R10 | **Medium** | Гонка register (TOCTOU): два параллельных запроса с одним username | `regMu` вокруг «проверить username → hash → вставить»; `go test -race` | s20 |
| R11 | **Medium** | `GET /api/notes` при фильтрации может вернуть `null` вместо `[]` | инициализировать `out := make([]Note, 0, ...)`; тест на пустой список | s20 |
| R12 | **Medium** | Утечка владельца заметки, если `UserID` попадёт в JSON | `Note.UserID` с `json:"-"`; наружу — response-структура `{id,text}` | s20 |
| R13 | **Medium** | `http.Error` ставит `text/plain` и `\n`; текущие тесты ждут JSON-строки | `writeErr`/`writeJSON`: `Content-Type: application/json`, без `http.Error`; сохранить строки `invalid id`, `not found`, `method not allowed`, `text required` | s20 |
| R14 | **Medium** | localStorage + HTTP на стенде: XSS/перехват токена | dev-only допущение; TTL 24h; не хранить пароль; `Cache-Control: no-store` на HTML; при желании — CSP | s05/s06/s20 |
| R15 | **Medium** | `preview-deploy.json` со `stand.sha` не создаётся текущим `preview-deploy.sh` (он пишет только `deploy/stands/.runtime/...`) | s20b обязан материализовать артефакт `preview-deploy.json` с `stand.url`, `stand.sha` = выкаченный ref, `commit`, `image_digest`; s22a не берёт локальный HEAD | s20b/s22a |
| R16 | **Medium** | E2E на общем in-memory store: пользователи/заметки протекают между сценариями | уникальные username на прогон, отдельный `browser.newContext()` на пользователя, сценарии независимы от порядка | s20c |
| R17 | **Medium** | Playwright/браузеры могут отсутствовать на runner | fail-close на web-платформе с явной ошибкой; установка браузеров — runner; нельзя «зеленить» E2E без UI-сценариев | s19/s20c |
| R18 | **Low** | `405` без заголовка `Allow`; неизвестный `/api/*` может отдать HTML из static handler | на 405 ставить `Allow`; для `/api/` зарегистрировать JSON-404 fallback, чтобы ошибки API оставались JSON | s20 |
| R19 | **Low** | `README.md` описывает старый безавторизационный API | обновить в рамках docs-шага, не блокер | s20/s25 |
| R20 | **Low** | `http.MaxBytesReader` нужен и на register/login, не только notes | 1 MiB на все тела; ограничить password ≤ 128, text ≤ 4096 | s20 |

---

## 2. Явные решения B1..B10

### B1. API-контракт и коды

**Решение:** контракт из таблицы ниже; все ответы — JSON, кроме `204`.
Порядок проверок на защищённых путях: **auth → method → path/id → body**.
На публичных (`/api/register`, `/api/login`): **method → body**.

| Метод | Путь | Auth | Успех | Ошибки |
|---|---|---|---|---|
| POST | `/api/register` | нет | `201 {"id":N,"username":"..."}` | `400` пустые/невалидные поля, `409` username занят, `405`, `500` |
| POST | `/api/login` | нет | `200 {"token":"..."}` | `400` пустые поля, `401` неверная пара, `405`, `500` |
| GET | `/api/notes` | да | `200 [{"id":N,"text":"..."}]` только свои; `[]` при пустом | `401`, `405` |
| POST | `/api/notes` | да | `201 {"id":N,"text":"..."}` | `400` пустой `text`, `401`, `405` |
| DELETE | `/api/notes/{id}` | да | `204` без тела | `400` нечисловой/пустой/overflow id, `401`, `404` нет/чужая, `405` |

Дополнительно:

- `401` — `WWW-Authenticate: Bearer` + `{"error":"unauthorized"}`.
- `405` — `Allow` с разрешёнными методами + `{"error":"method not allowed"}`.
- `409` — `{"error":"username taken"}`; `400` register/login — стабильные строки
  (например `"username and password required"`, `"invalid username"`).
- `404` — `{"error":"not found"}`; `400` id — `{"error":"invalid id"}`;
  `400` text — `{"error":"text required"}`. Эти три литерала сохраняются ради
  audit-оракулов и `main_test.go`.
- Неизвестный `/api/*` — JSON-404, не HTML.
- `204` не имеет тела и `Content-Type`.
- `Content-Type` запроса не валидируется строго; тело декодируется с лимитом.

**decision_ref:** FR:15–23 (весь список endpoint’ов), FR:31 (401), FB §2.1,
SR §2.5. **Связанные OD:** OD-01, OD-05, OD-06, OD-07.

### B2. Модель store и конкурентность

**Решение:** один `Store` на процесс; один `sync.Mutex` на users/sessions/notes
+ отдельный `regMu` только для регистрации. Хэширование — вне `Store.mu`.

```go
type Store struct {
    mu       sync.Mutex
    regMu    sync.Mutex
    now      func() time.Time // default time.Now, инъекция для TTL-тестов
    nextUser int
    nextNote int
    usersByID   map[int]*User
    usersByName map[string]*User
    sessions    map[string]*Session // token -> session
    notes       map[int]Note
}
```

Дисциплина:

1. `User{ID, Username, PasswordHash, Salt}` — секреты `json:"-"`;
   `Session{Token, UserID, ExpiresAt}`; `Note{ID, UserID, Text}`, `UserID`
   `json:"-"`.
2. `Register`: `regMu` → под `mu` проверить username → отпустить `mu` → PBKDF2
   (вне `mu`) → под `mu` вставить. `regMu` держится на весь check+hash+insert,
   чтобы не было TOCTOU; глобальные запросы при этом не блокируются.
3. `Login`: под `mu` взять пользователя и копию hash/salt → отпустить → PBKDF2
   verify → под `mu` создать сессию. Для отсутствующего username — dummy-PBKDF2.
4. `List(userID)` под `mu` копирует только свои заметки в не-nil срез.
5. `Add(userID, text)` под `mu` выдаёт глобально монотонный `nextNote`.
6. `Delete(userID, noteID)` под `mu`: `!exists || note.UserID != userID` → `false`.
7. Просроченные сессии удаляются лениво при lookup; отдельного ticker’а нет.
8. `nextUser`/`nextNote` только под `mu`, id не переиспользуются.

**decision_ref:** FR:27,33; FB §2.3; SR §2.2.

### B3. Пароли: PBKDF2-HMAC-SHA256 на stdlib

**Решение:** локальная реализация PBKDF2-HMAC-SHA256, потому что
`crypto/pbkdf2` есть только в Go 1.24.

- Соль: 16 байт `crypto/rand`; ключ: 32 байта; итерации: package-level
  `var pbkdf2Iterations = 210000` (тесты могут понизить и восстановить).
- Сравнение: `crypto/subtle.ConstantTimeCompare` (или `hmac.Equal`).
- Хранить только `Salt` + `PasswordHash`; никогда не сериализовать и не логировать.
- Логин с несуществующим username выполняет PBKDF2 с фиксированной dummy-солью
  и тем же числом итераций → одинаковый 401 и сопоставимое время.
- Пароль ограничить сверху (рекомендация 128 символов), чтобы стоимость
  PBKDF2 не стала DoS-вектором; тело — `MaxBytesReader` 1 MiB.
- `crypto/rand` failure → `500` JSON, не «деградация» к предсказуемому токену/соли.
- В тестах не мутировать глобальную переменную параллельно: либо helper с
  `t.Cleanup`, либо не помечать тесты `t.Parallel()`.

**decision_ref:** FR:28,32; FB §2.4; SR §2.3. **OD:** OD-02.

### B4. Bearer-токен, TTL 24h и семантика 401

**Решение:**

- Токен непрозрачный: 32 случайных байта `crypto/rand`,
  `base64.RawURLEncoding` (~43 символа).
- Сервер хранит `map[token]*Session` в памяти; токен — ключ map.
- `Session{Token, UserID, ExpiresAt}`; TTL **24 часа fixed** от логина,
  без refresh/sliding.
- Заголовок `Authorization: Bearer <token>`; схема case-insensitive, токен
  непустой, ровно два поля. Токен в query/cookie не принимается.
- Нет заголовка / битый / истёкший токен → **401** + `WWW-Authenticate: Bearer`
  + `{"error":"unauthorized"}`. Истёкшая сессия удаляется при обращении.
- Время через `Store.now()`, чтобы `TestTokenExpiry` был детерминированным.
- Logout-эндпоинта нет (OD-04); UI-«выход» только чистит localStorage.

**decision_ref:** FR:29,31; FB §2.2; SR §2.4. **OD:** OD-03, OD-04.

### B5. Чужая/несуществующая заметка → 404; auth раньше id/method

**Решение:**

- `DELETE /api/notes/{id}`: auth → method → parse id → ownership. Чужая и
  несуществующая заметка неразличимы: `404 {"error":"not found"}`.
- Без валидного токена **любой** метод на `/api/notes` и `/api/notes/{...}`
  даёт **401** — включая `PUT`, `GET /api/notes/abc`, `DELETE /api/notes/abc`.
  Это фиксируется `TestAuthRequired` и не должно «дрейфовать» в 405/400.
- `GET /api/notes` возвращает только `Note.UserID == currentUserID`.
- id заметок глобально монотонные, не переиспользуются; принадлежность — по
  `UserID`, а не по диапазону id.
- `Note.UserID` никогда не сериализуется.

**decision_ref:** FR:18,22,30; FB §2.1, §3; SR §2.5. **OD:** OD-01.

### B6. JSON error envelope для всех ошибок

**Решение:** заменить все `http.Error` на хелперы:

- `writeJSON(w, code, v)` — `Content-Type: application/json`, marshal,
  `WriteHeader`, `Write`; без лишнего перевода строки.
- `writeErr(w, code, msg)` — `writeJSON(w, code, map[string]string{"error": msg})`.
- Для `204` — только `WriteHeader(http.StatusNoContent)`, без тела.
- Строки ошибок — стабильные, без внутренних деталей/stack/имён файлов:
  `"invalid id"`, `"not found"`, `"method not allowed"`, `"text required"`,
  `"unauthorized"`, `"username taken"`, `"internal error"`.
- `500` логируется на сервере без паролей/токенов/hash; клиенту — generic.
- `405` — с `Allow`; `401` — с `WWW-Authenticate`.
- `MaxBytesReader` на register/login/notes; ошибка декодирования → 400 JSON.

**decision_ref:** FR:44; FB §2.1; SR §2.5; текущие тесты `main_test.go:156,171,213,228`.

### B7. UI: `go:embed web/`, один handler, same-origin

**Решение:** UI встраивается в бинарь, раздаётся тем же Go-процессом на том же
origin, что и `/api/*`; отдельного frontend-сервера/CORS нет.

- Embed-паттерны **явные**, не `web/` целиком:
  - вариант «3 HTML»: `//go:embed web/login.html web/register.html web/notes.html web/app.js web/app.css`;
  - вариант «SPA»: `//go:embed web/index.html web/app.js web/app.css`.
  Иначе в бинарь попадут `web/e2e/` и `node_modules/`.
- Один handler: `/` → `302 /login`; `/login`, `/register`, `/notes` — HTML;
  `/app.js`, `/app.css` — статика; `/api/*` — API. Для SPA — History API
  fallback на `index.html` только для трёх UI-маршрутов, не для `/api/*`.
- HTML — `Cache-Control: no-store`; статика — с корректным `Content-Type`.
- Guard `notes` — клиентский (нет `notebook.token` → `/login`); сервер всё равно
  обязан вернуть 401.
- Dockerfile: `COPY web/ ./web/` в build stage; `.dockerignore` —
  `web/e2e/`, `web/node_modules/`.
- Токен — `localStorage["notebook.token"]`; `notebook.user` — только подпись.
- Ошибки — `[role="alert"]` c `aria-live="polite"`, не `alert()`.

**Открытая развилка:** 3 HTML (wireframes s03) vs `index.html` + SPA-роуты
(текущие `source_files` в ui-графе s04) — **OD-09**. До s20 форма должна быть
одна и та же в коде, ui-графе и Playwright. Рекомендация — 3 HTML.

**decision_ref:** FR:37–45; FB §4; SR §2.6. **OD:** OD-08, OD-09, OD-10.

### B8. path1 adapter

**Решение:** adapter приводится к целевому состоянию; `deploy.stand_command`
и `preview-deploy.sh` **не меняются**.

| Поле | Целевое | Текущее в репо | Действие |
|---|---|---|---|
| `graph.source_roots` | `["web"]` | `["web"]` | ок |
| `graph.artifact_globs` | `arch/structure/ui-pages/*.yaml`, `*.yml`, `UI-GRAPH.yaml` | уже так | ок |
| `e2e.frontend_dir` | `"web"` | `"web"` | ок |
| `e2e.command` | `bash deploy/path1/e2e-preview.sh` | уже так | строку не менять; обновить тело скрипта |
| `e2e` Playwright | `web/e2e/auth-notes.spec.js`, baseURL из `E2E_BASE_URL` | спеки нет | создать на s20c |
| `deploy.stand_command` | `bash deploy/path1/preview-deploy.sh {stand} {ref}` | уже так | **не менять** |
| `audit.mode` | `app` | `app` | ок |
| `audit.database` | `false` | `false` | ок |
| `canaries.require_dsn` | `false` | `false` | ок |
| `canaries.items` | `CANARY-DELETE-STATUS` + auth/изоляция | один DELETE-canary | сохранить существующий; добавить auth-canary опционально |
| `path1.ui.json.platform` | `web` | `web` | ок |

`e2e-preview.sh` должен: проверить `/healthz` стенда (это **nginx JSON**, не
app-`/healthz`), сделать register/login, authed GET/POST/DELETE, проверить
401 без токена и изоляцию A/B, затем запустить Playwright. При отсутствии
браузеров — fail-close, не skip.

**decision_ref:** FR:49–54; SR §2.7. **OD:** OD-12.

### B9. UI-граф

**Решение:** источник истины — `arch/structure/ui-pages/{login,register,notes}.yaml`.
`status` меняется с `planned` на `implemented` на s21 **по коду**; фактические
`source_files`, `route`, `selector`, `api_calls`, `states`, `transitions`,
`a11y` должны совпадать с реализацией.

- Не создавать одновременно `UI-GRAPH.yaml` и `ui-pages/*` как два источника
  истины (OD-11).
- `arch_writes` процесса (`arch/frontend/pages/*.yaml`) не должен порождать
  второй набор файлов: гейт `graph-actualized` проверяет
  `arch/structure/ui-pages/*` (R5).
- Текущий граф уже перечисляет все три страницы и нужные API; но
  `source_files: web/index.html` и `[data-testid=...]` должны быть сверены
  с кодом (K3/K4).
- `s21` не скипать (FR:60); `feature_profile` = `full` (OD-15).

**decision_ref:** FR:55–56,60; SR §2.8. **OD:** OD-11, OD-15.

### B10. Тесты

**Решение:** `main_test.go` мигрирует под auth; имена
`TestDeleteNote`, `TestDeleteErrorEnvelope`, `TestNotesMethodNotAllowed`
**сохраняются** (их используют `canaries` и `audit.oracles`).

Обязательный набор:

| Тест | Что закрепляет |
|---|---|
| `TestDeleteNote` | seed user/token; своя заметка → 204; повторно/чужая/несуществующая → 404; `abc` → 400; список без удалённой |
| `TestDeleteErrorEnvelope` | authed 400 `{"error":"invalid id"}` и 404 `{"error":"not found"}`, без утечек |
| `TestNotesMethodNotAllowed` | authed GET/POST/PUT/PATCH на `/api/notes/{id}` → 405 + тело |
| `TestAuthRequired` | все методы на `/api/notes*` без/битый/истёкший токен → 401 **до** 405/400 |
| `TestRegister` | 201 `{id,username}`; 400 пустые/невалидные; 409 дубль; 405 |
| `TestLogin` | 200 `{token}`; 400 пустые; 401 неверный пароль; 401 несуществующий username (тот же ответ) |
| `TestNotesIsolation` | A не видит и не удаляет заметку B; удаление B → 404 |
| `TestPasswordNotLeaked` | в телах ответов нет `password`/`hash`/`salt` |
| `TestTokenExpiry` | инъекция `now`: до TTL — 200, после — 401, сессия удалена |
| `TestPasswordHashVerify` | PBKDF2 детерминизм, неверный пароль false, разные соли |
| `TestUIStaticContract` (рекомендуется) | в embed-ресурсах есть нужные страницы/поля/`role=alert`/`aria-live`, нет захардкоженных заметок |

Требования:

- helper `seedUser(t, h) (username, token)` и
  `authedRequest(t, h, method, path, body, token)`;
- `mustSeedNote` получает токен;
- в `main.go` сохраняется литерал `http.StatusNoContent` (R7);
- `go test -race ./...` и `go vet ./...` — локальный DoD;
- тесты не должны зависеть от 210k итераций (понижать `pbkdf2Iterations`
  с восстановлением, без параллельной мутации).

**decision_ref:** FR:57–59; SR §2.10, §3.3.

---

## 3. open_decisions[]

Ни один пункт ниже не закрывается молча. Формат: вопрос → варианты →
рекомендация → `decision_ref` → куда уходит. Все пункты должны попасть в
`intent-trace.json`/`open_questions[]` на s07 и, при необходимости, в вопрос
человеку на s08.

### OD-01. DELETE чужой заметки: 404 или 403?

- A) **404** — не раскрывать существование чужого id.
- B) 403 — явно «запрещено», но подтверждает существование.
- **Рекомендация: A (404).** Совпадает с FB §2.1 и SR §2.5.
- `decision_ref`: FR:22 «удалить только свою заметку»; FR:30 «user A не видит
  и не удаляет заметки user B».
- **Влияние:** B5, `TestNotesIsolation`, `TestDeleteNote`.

### OD-02. PBKDF2-HMAC-SHA256 vs bcrypt/argon2

- A) **PBKDF2-HMAC-SHA256 на stdlib** (соль 16B, 210k, 32B).
- B) bcrypt (`golang.org/x/crypto`) — новая зависимость, `go mod download`.
- C) argon2id (`x/crypto`) — тоже зависимость.
- **Рекомендация: A.** Офлайн-сборка, Go 1.23, `go.mod` без `require`.
- `decision_ref`: FR:28 «соль + hash»; FR:32 «без утечки»; ограничение
  «без БД/внешних сервисов» (FR:27).
- **Влияние:** B3, Dockerfile (нет `go mod download`), R8/R9.

### OD-03. TTL bearer-токена

- A) **24h fixed** от логина, без refresh/sliding.
- B) 1h fixed — безопаснее, но чаще логин.
- C) sliding expiry — вне scope по брифу.
- **Рекомендация: A (24h), часы инъектируемы для тестов.**
- `decision_ref`: FR:29 «bearer-токен»; TTL в запросе не задан; FB §2.2.
- **Влияние:** B4, `TestTokenExpiry`, UX reload-сценария.

### OD-04. Logout-эндпоинт

- A) **Не добавлять** `POST /api/logout` — в запросе его нет.
- B) Добавить `POST /api/logout` (удаляет сессию) — расширяет scope.
- **Рекомендация: A.** UI-«Logout» = удалить `notebook.token`/`notebook.user`
  и `location.replace("/login")`; серверная сессия живёт до TTL.
- `decision_ref`: FR:15–23 — список API без logout; FB §4/§6 (UI-only logout).
- **Влияние:** B4, `notes.yaml` (кнопка помечена UI-only), E2E (logout не
  проверяет серверную инвалидацию).

### OD-05. Ответ `POST /api/register`

- A) **201 `{"id":N,"username":"..."}`** (как в FB §2.1).
- B) 201 без тела — меньше данных.
- C) 201 + сразу токен (auto-login) — в запросе логин отдельным шагом.
- **Рекомендация: A.** `decision_ref`: FR:15 «`POST /api/register` ... -> 201»;
  отдельный `POST /api/login` в FR:16.
- **Влияние:** B1, UI register (переход на login, не auto-login).

### OD-06. Регистрация с занятым username

- A) **409** — явно и просто.
- B) 200/201 идемпотентно — скрывает существование, но врёт о создании.
- C) 400 — смешивает с валидацией.
- **Рекомендация: A (409).** Enumeration через register принимается для dev.
- `decision_ref`: FR:15 (код не задан); FB §2.1 предлагает 409; FR:44 (UI
  показывает 400/401; 409 добавляется UI-логикой).
- **Влияние:** B1, UI register, `TestRegisterDuplicate`.

### OD-07. Строгая валидация vs только non-empty

- A) **Строгая:** username `[A-Za-z0-9_-]{3,32}` (trim), password 8–128,
  text 1–4096.
- B) Только non-empty + верхние лимиты (минимум домыслов).
- **Рекомендация: A**, но явно пометить как «добавлено от себя» в
  `intent-trace`: в сыром запросе только «битые/пустые поля» (FR:15–23) и
  «ошибки 401/400» (FR:44). Если человек не подтверждает — B.
- `decision_ref`: FR:15–23, FR:44; FB §2.1, §7.4; SR OD-07.
- **Влияние:** B1, UI register (подсказки формата), `TestRegister`,
  `TestAddNote` (пустой/whitespace text).

### OD-08. Раздача UI: `go:embed` vs файлы с диска

- A) **`go:embed`** — один бинарь, preview без volume, Dockerfile + `COPY web`
  в build stage.
- B) `http.FileServer` по `web/` — правки без пересборки, но нужен `web/`
  в runtime-образе и корректный cwd.
- **Рекомендация: A.** `decision_ref`: FR:45 «минимальный HTML/JS/CSS или Go
  embed»; текущий Dockerfile копирует только `main.go` (SR §2.6).
- **Влияние:** B7, K1, R1.

### OD-09. Отдельные страницы vs SPA

- A) **3 отдельных HTML** (`login.html`, `register.html`, `notes.html`) +
  общий `app.js`/`app.css`, чистые URL.
- B) Один `index.html` + hash/History-routing.
- **Рекомендация: A** — проще UI-граф из трёх страниц, reload и Playwright;
  совпадает с wireframes s03.
- `decision_ref`: FR:55 «Страницы: login, register, notes»; FR:37–42
  (регистрация/логин/список/добавление/удаление); FB §4 (три HTML).
- **Влияние:** B7, B9, K3/K4, `e2e.frontend_dir=web`, `source_files` в
  ui-графе. **Это главный блокер до s20:** s04 уже сослался на `index.html`,
  s03 — на три HTML. Нужно выбрать один вариант и синхронизировать код,
  граф и E2E.

### OD-10. Где хранить токен

- A) **localStorage** — reload сохраняет сессию (E2E №4).
- B) `sessionStorage` — живёт вкладку; reload сохраняет, новые вкладки нет.
- C) только память JS — reload разлогинивает, ломает сценарий.
- **Рекомендация: A** `localStorage["notebook.token"]`.
- `decision_ref`: FR:43 «токен в памяти/localStorage»; FR:58 «reload — заметка
  видна»; FB §4.
- **Влияние:** B7, R14, E2E reload.

### OD-11. Формат UI-графа

- A) **`arch/structure/ui-pages/{login,register,notes}.yaml`** (per-page).
- B) Один `UI-GRAPH.yaml`.
- **Рекомендация: A** — гейт перечисляет этот glob; per-page проще
  актуализировать; не дублировать.
- `decision_ref`: FR:55 «`arch/structure/ui-pages/...` или `UI-GRAPH.yaml`».
- **Влияние:** B9, s21, R5.

### OD-12. E2E-runner на стенде

- A) **Playwright обязателен**, API-smoke — быстрый префлайт; браузеры ставит
  runner; отсутствие → fail-close.
- B) Playwright опционален, gate держится на curl.
- **Рекомендация: A** — иначе UI-фича принимается без UI-E2E.
- `decision_ref`: FR:57–59 «Добавить Playwright `web/e2e/auth-notes.spec.js`».
- **Влияние:** B8, R17, s20c.

### OD-13. Username: регистр/нормализация

- A) **case-sensitive**, trim пробелов, `[A-Za-z0-9_-]{3,32}`.
- B) case-insensitive (lowercase-канонизация).
- **Рекомендация: A** — минимальный сюрприз; зафиксировать в спеке.
- `decision_ref`: формат username в FR не задан; FR:15–16.
- **Влияние:** B1/B3, `TestRegisterDuplicate`, UI подсказки.

### OD-15. `feature_profile` для прогона

- A) **`full`** — backend + frontend; s03/s04/s21/s22a исполняются.
- B) `frontend` — тоже UI-шаги, но семантически уже.
- C) `backend` — UI-шаги и s21-gate отключатся, **противоречит** FR:60.
- **Рекомендация: A.** `decision_ref`: FR:60 «s21 gate-graph-actualized не
  скипать» + UI в FR:35–45.
- **Влияние:** s21/s22a passability; I1.

### OD-16. Rate limiting на login

- A) **Вне scope** (бриф: dev, не требуется).
- B) Минимальный лимит (5/мин на username).
- **Рекомендация: A**, зафиксировать как принятый риск; при требовании — B.
- `decision_ref`: FB §7.8 «Rate limiting ... для dev не требуются»; FR:62–69
  (dev-only).
- **Влияние:** R11/R20, s22b red-team.

---

## 4. Трассировка решений к пунктам feature-request

| # | Пункт запроса (цитата/строка) | Решение | OD | Статус |
|---|---|---|---|---|
| T1 | FR:15 `POST /api/register ... -> 201` | B1 (201 `{id,username}`), B2, B3 | OD-05, OD-06, OD-07 | дизайн есть; OD не подтверждены |
| T2 | FR:16 `POST /api/login ... -> 200 {"token"}; 401` | B1, B3, B4 | OD-02, OD-03 | дизайн есть |
| T3 | FR:18 `GET /api/notes ... только текущего пользователя` | B1, B5 | OD-01 | дизайн есть |
| T4 | FR:20 `POST /api/notes ... создать заметку текущего` | B1, B2, B5 | OD-07 | дизайн есть |
| T5 | FR:22 `DELETE /api/notes/{id} ... только свою` | B1, B5 | OD-01 | дизайн есть |
| T6 | FR:27 `users, sessions, notes — in-memory` | B2 | — | PASS |
| T7 | FR:28 `пароли ... соль + hash` | B3 | OD-02 | дизайн есть |
| T8 | FR:29 `bearer-токен` | B4 | OD-03 | дизайн есть |
| T9 | FR:30 `user A не видит и не удаляет заметки user B` | B5, B2 | OD-01 | дизайн есть |
| T10 | FR:31 `без авторизации — 401` | B4, B5 | — | PASS |
| T11 | FR:32 `без утечки паролей/хэшей` | B3, B6 | — | PASS (тест обязателен) |
| T12 | FR:33 `данные живут в рамках процесса` | B2 | — | PASS |
| T13 | FR:37 `статическая страница` | B7 | OD-08, OD-09 | дизайн есть; форма UI не выбрана |
| T14 | FR:38–42 `регистрация/логин/список/добавление/удаление` | B7, B9 | OD-09 | дизайн есть |
| T15 | FR:43 `токен в памяти/localStorage` | B7, B4 | OD-10 | дизайн есть |
| T16 | FR:44 `ошибки 401/400 показывать` | B6, B7 | — | PASS (409 добавить в UI) |
| T17 | FR:45 `без React/Vue ... или Go embed` | B7 | OD-08 | дизайн есть |
| T18 | FR:49–53 adapter: `e2e.frontend_dir`, `e2e.command`, `stand_command`, `audit.mode`, `audit.database`, `require_dsn` | B8 | OD-12 | файл уже в целевом состоянии; скрипт — нет |
| T19 | FR:54 `path1.ui.json: platform web` | B8 | — | PASS |
| T20 | FR:55–56 `UI-граф ... login, register, notes` | B9 | OD-11 | planned-граф есть; actualize на s21 |
| T21 | FR:57–59 `Playwright ... 7 сценариев` | B8, B10 | OD-12 | спеки нет → s20c |
| T22 | FR:60 `s21 gate-graph-actualized не скипать` | B9 | OD-15 | PASS (требование принято) |
| T23 | FR:62–67 `prod/main/stage/push/canary ... не трогать` | B8 | — | PASS (в границах шага) |
| T24 | FR:68 `force/skip/waiver не применять` | — | — | PASS |
| T25 | FR:69 `direct-код вне ORC-шагов не писать` | — | — | PASS (s05 пишет только doc) |

---

## 5. Проходимость s21/s22a (и зависимых гейтов s24)

### 5.1. s06: invariants.json и `INV-UI-*`

s06 обязан опубликовать `doc/идеи/f-v3-auth-notes/invariants.json` с core
UI-инвариантами. Статусы и оракулы:

| ID | Предлагаемая формулировка | status | test_ref / enforcement |
|---|---|---|---|
| `INV-UI-TRUTH` | Каждая отображаемая заметка существует на сервере и принадлежит текущему пользователю; UI не показывает чужие/фантомные заметки; reload совпадает с `GET /api/notes` | `active` | `go test -run TestUIStaticContract ./...` + данные `TestNotesIsolation`; s20 обязан реализовать тест |
| `INV-UI-LABEL` | У каждого поля/кнопки есть видимая или aria-подпись; submit-кнопки имеют текст `Login`/`Register`/`Add`/`Delete` | `active` | `go test -run TestUILabels ./...` |
| `INV-UI-A11Y-NAME` | У полей и кнопок есть доступное имя; ошибки в `role="alert"` + `aria-live="polite"`; фокус управляется на 401 | `active` | `go test -run TestUIA11yNames ./...` |
| `INV-UI-ORACLE` | Каждый критерий UI-аудита имеет исполнимый оракул и evidence | `proposed` | enforcement — `gate-ui-audit-machine`/`oracle-cited` на s22a; оракул `ui-audit.json` появляется только на s22a |
| `INV-UI-E2E-PREVIEW` | UI-сценарии проходят на стенде test2, есть screenshot-доказательство | `proposed` | `bash deploy/path1/e2e-preview.sh` на s20c; evidence — e2e-report/screenshot |

**Важно:** `INV-UI-ORACLE` и `INV-UI-E2E-PREVIEW` нельзя публиковать `active`
на s06 — их оракулы материализуются позже (s22a/s20c), иначе
`gate-invariant-enforced` упадёт. Для `TRUTH/LABEL/A11Y-NAME` нужны
**исполнимые** `test_ref`; s06 должен согласовать имена тестов с s20
(`TestUIStaticContract`, `TestUILabels`, `TestUIA11yNames`) и проверить
`bash tools/path1-gate.sh test-ref-runnable` в окружении шага. `tools/` в
рабочем дереве отсутствует — это платформенный слой, поэтому проверка
обязательна на s06, а не предполагается.

### 5.2. s21: `gate-graph-actualized`

Чек-лист к s21:

- `feature_profile=full` (OD-15), `path1.ui.json.platform=web` — иначе s21
  отфильтруется по `when`.
- Все три файла `arch/structure/ui-pages/{login,register,notes}.yaml` имеют
  `status: implemented` (не `planned`).
- `source_files` соответствуют фактическим файлам (`web/login.html` и т.д.
  **или** `web/index.html` — по OD-09), без ссылок на несуществующие файлы.
- `route`, `selector`, `api_calls`, `states`, `transitions`, `a11y` совпадают
  с кодом; `selectors` — фактический контракт (K4).
- Не создавать `arch/frontend/pages/*.yaml` и `UI-GRAPH.yaml` как второй
  источник: гейт смотрит `arch/structure/ui-pages/*` (R5).
- Актуализация должна быть **этим прогоном**; копия planned-графа не проходит.

### 5.3. s22a: `ui-audit.json` (блоки A–L) и `gate-ui-audit-*`

Формат (по process s22a): `platform`; `stand{url,sha}`; `summary`
(`open_critical_high:0`, `blockers:0`); `items[{id,block,verdict,severity,
criterion,oracle,evidence}]`. Для `platform=web` обязательны **все блоки A–L**
(блок M не требуется). `stand.sha` обязан совпадать с выкаченным ref из
`preview-deploy.json`, а не с локальным HEAD.

| Блок | Критерий для этой фичи | Пример оракула / evidence |
|---|---|---|
| A. Состояния/честность | idle/submitting/error-400/error-401/error-409/loading/empty/list/delete-pending/401-logout; нет ложного успеха | `dom:` assertions в Playwright; state screenshots |
| B. Информативность | 400/401/409 и empty/loading понятны; ошибка не стирает ввод (кроме пароля при 401) | `dom:` текст `[role=alert]`; screenshot |
| C. Человеческий слой | русские подписи, нет технического жаргона, фокус на ошибке, пароль очищается при 401 | `dom:`/Playwright focus assertions |
| D. Визуальная система | колонка ≤640px, единые отступы/кнопки, читаемый контраст | screenshot 1280/360 + CSS-чеклист |
| E. Композиция | карточка по центру, шапка notes, список с id+text, мобильная одна колонка | screenshots |
| F. Взаимодействие | Enter отправляет, Add disabled при пустом, double-submit заблокирован, delete-pending, logout UI-only | Playwright spec |
| G. A11y | label/aria-label, accessible name, `role=alert`+`aria-live=polite`, touch ≥44px, focus-visible | `go test -run TestUIA11yNames`; `dom:` |
| H. Адаптив/устройства | breakpoint 640px, 360px без горизонтального скролла, full-width кнопки, перенос длинного текста | Playwright viewport + screenshots |
| I. Данные/контракты | точные методы/коды API, `Authorization: Bearer`, 401→очистка+`/login`, reload сохраняет сессию | Playwright + e2e-report |
| J. Перф | быстрый первый рендер, нет тяжёлых ассетов, API in-memory | time-to-load budget / Playwright metrics |
| K. Завершённость | все 7 E2E-сценариев, нет TODO/заглушек, logout помечен UI-only, docs | scenario coverage |
| L. Доказательства | screenshot каждого ключевого состояния, e2e-report, `preview-deploy.json` sha | artifact refs в `evidence` |

Гейты s22a: `gate-ui-audit-machine` (схема/оракулы/DoD/привязка к стенду),
`gate-ui-audit-oracle` (у каждого item есть `oracle` и `evidence`),
`gate-ui-audit-accept` (designer accept), `gate-ui-audit-dod`
(`open_critical_high=0`). Все четыре должны пройти.

### 5.4. `preview-deploy.json` и scenarios/scenario-evidence

**preview-deploy.json.** s22a и `gate-preview-before-ui` требуют, чтобы
`stand.sha` в аудите равнялся выкаченному ref. Текущий `preview-deploy.sh`
пишет `deploy/stands/.runtime/<stand>/build-provenance.json` и
`deploy-provenance.json`, но **не** корневой `preview-deploy.json`.
s20b обязан материализовать гейтируемый артефакт (корень репо или путь,
который читает `tools/path1-gate.sh`) с полями:

```json
{
  "stand": "test2",
  "url": "http://127.0.0.1:9082",
  "sha": "<deployed ref>",
  "commit": "<40hex>",
  "image_digest": "<docker image id>",
  "build_ref": "<short>",
  "deployed_at": "<RFC3339>"
}
```

`sha` берётся из деплоя (provenance/`/healthz` nginx), не из локального HEAD.
s22a копирует этот `sha` в `ui-audit.json.stand.sha`; расхождение — fail
«аудит не на том билде».

**scenarios/scenario-evidence.** `gate-scenario-coverage` на s24 требует, чтобы
у сценариев был пройденный E2E/скриншот. Сейчас каталога сценариев нет —
s07/s10 должны его создать, а s20c — наполнить evidence. Минимальный набор
(1:1 с FR:57–59 и UI-состояниями):

| ID | Сценарий | Evidence |
|---|---|---|
| S1 | Регистрация нового пользователя (201) | Playwright step + screenshot register success |
| S2 | Логин, токен в localStorage (200) | step + screenshot notes header |
| S3 | Создание заметки (201) | step + screenshot list |
| S4 | Reload notes — заметка видна | step + screenshot after reload |
| S5 | Удаление заметки (204) | step + screenshot after delete/empty |
| S6 | User B не видит заметку A | два browser context + screenshot B empty |
| S7 | Неавторизованный `GET /api/notes` → 401 | APIRequestContext + response evidence |
| S8 | 400 пустой text / 401 неверный пароль / 409 дубль | UI screenshots error states |
| S9 | 401 на notes → очистка токена и `/login` | step + screenshot login |
| S10 | Mobile 360px (одна колонка, full-width) | screenshot 360px |

Каждый сценарий должен иметь `scenario_ref` в `intent-trace.json` (s07) и
ссылку на evidence в `ui-audit.json`/e2e-report. Без этого `s24` не пройдёт
`gate-scenario-coverage`.

### 5.5. Зависимости s24

`s24.team_lead_accept` дополнительно требует:

- `gate-graph-actualized` — s21 (см. §5.2);
- `gate-scenario-coverage` — §5.4;
- `gate-preview-verified` — s20c;
- `gate-evidence-authentic` — s22b/s22c;
- `gate-oracle-cited-final` — оракулы s22, включая UI;
- `gate-ui-audit-dod` — s22a (0 open critical/high);
- `gate-stand-leased-accept` — аренда стенда;
- `gate-branch-fresh` — s24a.

Следовательно, K1/K2/K3/K5 должны быть закрыты до s20c/s22a, иначе каскад
гейтов s24 гарантированно красный.

---

## 6. Рекомендации по шагам

### s06.feature_brief_final
1. Вынести OD-01/02/03/04/05/06/07/08/09/10/11/12/13/15/16 в
   `open_questions[]`; не закрывать молча.
2. Зафиксировать `feature_profile=full`.
3. Опубликовать `invariants.json` с `INV-UI-*` по §5.1; `ORACLE` и
   `E2E-PREVIEW` — `proposed`; имена `test_ref` согласовать с s20.
4. В `intent-trace` пометить строгую валидацию как «добавлено от себя» (OD-07).

### s20 (реализация)
1. Dockerfile: `COPY *.go` + `COPY web/ ./web/`; `.dockerignore` для
   `web/e2e`, `web/node_modules`.
2. `main.go`: auth-guard, register/login, owner-scoped store, JSON-хелперы;
   сохранить `http.StatusNoContent` и DELETE в `main.go`.
3. UI: одна форма по OD-09; `data-testid` + `id`; `role=alert`,
   `aria-live`, localStorage-ключи; same-origin.
4. Тесты: миграция `main_test.go`, сохранить имена; добавить негативы;
   `go test -race ./...`, `go vet ./...`.

### s20a/s20b/s20c
1. `e2e-preview.sh`: auth-smoke + Playwright; `e2e.command` не менять;
   fail-close без браузеров.
2. `preview-deploy.sh` не менять; обеспечить `preview-deploy.json` (§5.4).
3. Playwright: `web/e2e/auth-notes.spec.js`, уникальные пользователи,
   отдельные context, 7 сценариев + UI-состояния.

### s21.graph_actualize
1. Актуализировать `arch/structure/ui-pages/*.yaml` по коду, `status:
   implemented`; синхронизировать `source_files`/`selectors`/`routes`.
2. Не создавать второй граф в `arch/frontend/pages` или `UI-GRAPH.yaml`.

### s22a.ui_audit
1. `ui-audit.json` на SHA стенда из `preview-deploy.json`; блоки A–L;
   у каждого item — `oracle` и `evidence`.
2. `invariants.json` с core `INV-UI-*`; `summary.open_critical_high=0`.
3. Переиспользовать screenshots/e2e-report из s20c как evidence.

---

## 7. Итог

- Дизайн **архитектурно состоятелен** при условии закрытия K1–K5 и
  подтверждения OD-развилок.
- Ключевые архитектурные решения: один `Store.mu` + `regMu`; PBKDF2-HMAC-SHA256
  stdlib; bearer 32B/24h; 404 для чужой/несуществующей заметки; JSON-envelope
  для всех ошибок; `go:embed` + один handler; 3 UI-страницы (или SPA — OD-09);
  `arch/structure/ui-pages/*.yaml`; Playwright по `E2E_BASE_URL`.
- До s20 обязательны: Dockerfile (`*.go` + `web/`), auth+Playwright в
  `e2e-preview.sh`, синхронизация UI-графа/селекторов с кодом, артефакт
  `preview-deploy.json` со `stand.sha`.
- До s06 обязательны: `feature_profile=full`, `invariants.json` с корректными
  статусами `INV-UI-*` и исполнимыми `test_ref` для active-инвариантов,
  вынесение OD в `open_questions[]`.
