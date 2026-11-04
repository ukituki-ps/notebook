# Scope Report — f-v3-auth-notes (s02.architect_scope_analysis)

- Execution: **E4312**, шаг **s02.architect_scope_analysis**
- Repo: `/workspace/projects/notebook`, ветка `dev/f-v3-auth-notes`, база `8e0e949`
- Дата: 2026-11-04
- Источники: `feature-request.md` (неизменяем), `feature-brief.md` (s01),
  текущий код `main.go` / `main_test.go`, `path1.project.json`, `path1.ui.json`,
  `deploy/path1/*.sh`, `deploy/Dockerfile`, `arch/processes/path-1.feature.yaml`
  (только чтение — требования s21/s22a и гейтов).
- Границы шага: **только этот документ**. Код, адаптеры, Dockerfile, скрипты
  деплоя и UI-граф на s02 не редактируются.

---

## 1. Затронутые домены и слои

| # | Домен/слой | Текущее состояние | Что меняется | Основной риск |
|---|---|---|---|---|
| D1 | HTTP API / routing (`main.go`) | `GET/POST /api/notes`, `DELETE /api/notes/{id}`, `/healthz`; всё без auth | + `POST /api/register`, `POST /api/login`; auth-guard на `/api/notes*`; ответы через общий JSON-хелпер | порядок проверок (auth → метод → тело), сохранение 400/404/405 семантики |
| D2 | auth/session store | отсутствует | `User`, `Session`, PBKDF2-хэширование, генерация токена, TTL, поиск/протухание сессии | гонки, timing/enumeration, утечка секретов |
| D3 | notes store | `Store` с `sync.Mutex`, глобальный `[]Note`, монотонный `next` | у заметки появляется `UserID`; list/delete фильтруются по владельцу; id остаются глобально монотонными | «чужая» заметка не должна отличаться от несуществующей (404) |
| D4 | static UI (`web/`) | отсутствует | `login.html`, `register.html`, `notes.html`, общий `app.js`/`styles.css` | хранение токена, состояния 400/401/409, reload |
| D5 | embed / раздача статики | приложение отдаёт только API | `go:embed` + явные маршруты чистых URL; `/` → `/login` | embed затянет `web/e2e`/`node_modules`; Dockerfile без `web/` |
| D6 | tests (Go) | `main_test.go` закрепляет безавторизационный контракт | миграция всех тестов под auth + новые security-тесты | сломать canary/audit-оракулы, потерять имена тестов |
| D7 | E2E (Playwright) | `deploy/path1/e2e-preview.sh` — только curl API-smoke без auth | `web/e2e/auth-notes.spec.js` + конфиг; `e2e-preview.sh` выполняет auth-smoke и Playwright | отсутствие браузеров/сети на runner; общее in-memory состояние |
| D8 | deploy/preview | `preview-deploy.sh` (path10) собирает Docker-образ, nginx проксирует `/` и `/api/` на app:8080 | Dockerfile build-stage должен получить `web/`; runtime-стадия без изменений | path10 adapter нельзя ломать; `/healthz` на стенде отдаёт nginx, а не app |
| D9 | path1 adapter | `e2e.frontend_dir=""`, `e2e.command` = старый smoke; `path1.ui.json` = `none` | `frontend_dir=web`, `platform=web`; audit/canaries уже частично соответствуют | gate `e2e-preview` читает `e2e.command`; нельзя подменить `stand_command` |
| D10 | UI-граф | отсутствует (`arch/` содержит только процесс) | `arch/structure/ui-pages/{login,register,notes}.yaml` (актуализация на s21) | gate `graph-actualized` (s21 и s24) требует граф «этим прогоном» |
| D11 | invariants / acceptance docs | `invariants.json`/`ui-audit.json` ещё нет | s06 обязан опубликовать `INV-UI-*`; s22a — `ui-audit.json` на SHA стенда | `feature_profile`/`platform` без UI-значений отключат шаги s03/s04/s21/s22a |

**Вывод по домену:** фича не «backend-only». При `path1.ui.json.platform=web` и
наличии `web/` обязательны UI-граф (s21), UI-аудит (s22a) и стендовый E2E (s20c).
Это должно быть отражено в `feature_profile` (см. §6, интеграционная заметка I1).

---

## 2. Архитектурные ограничения и решения

### 2.1 Runtime и зависимости

- Один Go-процесс, один бинарь, `:8080`.
- Только stdlib; `go.mod` без `require`; Go **1.23** (как в `go.mod` и
  `deploy/Dockerfile`). Запрещены `golang.org/x/crypto`, JWT-библиотеки,
  веб-фреймворки, npm-рантайм для UI.
- In-memory store; рестарт процесса = полная очистка users/sessions/notes —
  осознанно допустимо.
- Сборка/тесты должны работать офлайн (`go build ./...`, `go test ./...`).

### 2.2 Store и конкурентность (users + sessions + notes в одном Store)

Один `Store` с **одним** `sync.Mutex` на данные — достаточно для dev-нагрузки.
Предлагаемая форма (эскиз, не код к реализации):

```go
type Store struct {
    mu     sync.Mutex        // users, sessions, notes, next*
    regMu  sync.Mutex        // сериализация register (check+hash+insert)
    now    func() time.Time  // инъекция часов для тестов TTL
    nextUser int
    nextNote int
    usersByID   map[int]*User
    usersByName map[string]*User
    sessions    map[string]*Session // token -> session
    notes       map[int]Note
}
```

Дисциплина блокировок:

1. **PBKDF2 нельзя выполнять под `Store.mu`** — 210k итераций заблокируют все
   запросы. Хэширование делается вне lock.
2. Регистрация: `regMu` сериализует «проверить username → посчитать hash →
   вставить». Иначе два параллельных register с одним username пройдут
   проверку до вставки (TOCTOU) и создадут дубль. `Store.mu` берётся только на
   проверку и на вставку.
3. `List(userID)` копирует отфильтрованный срез под lock и возвращает копию
   (как сейчас), чтобы JSON-энкодер не читал данные без блокировки.
4. `Delete(userID, noteID)` под lock ищет заметку; если `!exists` **или**
   `note.UserID != userID` → `false` → 404. Наружу не различаем.
5. Протухшие сессии удаляются лениво при lookup; отдельный ticker-горутин не
   нужен (не держим лишний фон и не мешаем тестам).
6. `now func() time.Time` с дефолтом `time.Now` — детерминированные тесты TTL.
7. `nextUser`/`nextNote` инкрементируются под `Store.mu`, id не переиспользуются.

### 2.3 Пароли

- **PBKDF2-HMAC-SHA256** на stdlib (`crypto/hmac` + `crypto/sha256` +
  `encoding/binary`), ~15 строк: `crypto/pbkdf2` появился только в Go 1.24.
- Параметры по умолчанию: соль **16 байт** `crypto/rand`, итераций **210 000**,
  ключ **32 байта**.
- Итерации — package-level `var` (не жёсткий `const`), чтобы Go-тесты могли
  понизить стоимость; прод/dev-дефолт остаётся 210k.
- Сравнение — `crypto/subtle.ConstantTimeCompare` (или `hmac.Equal`).
- `PasswordHash`/`Salt` — `[]byte` с `json:"-"`; наружу отдаются только
  отдельные response-структуры (`{id,username}`), а не `User`.
- Логин с несуществующим username обязан потратить сопоставимое время:
  выполняем PBKDF2 с фиксированной «dummy» солью/хэшем и возвращаем тот же 401
  (анти-enumeration по времени).
- Пароли/хэши/соли никогда не логируются; тест проверяет отсутствие подстрок
  `password`, `hash`, `salt` в телах ответов.

### 2.4 Bearer-токен и сессии

- Токен непрозрачный: **32 случайных байта** `crypto/rand`,
  `base64.RawURLEncoding` (~43 символа). Ошибка `crypto/rand` → 500, без
  «деградации» до предсказуемого токена.
- Хранится на сервере: `map[token]*Session` в памяти, под тем же `Store.mu`.
- `Session{Token, UserID, ExpiresAt}`; TTL по умолчанию **24 часа** от логина,
  fixed (без sliding/refresh — вне scope).
- Проверка: заголовок `Authorization: Bearer <token>`; нет/битый/истёкший →
  **401** + `WWW-Authenticate: Bearer` + `{"error":"unauthorized"}`.
  Истёкшая сессия удаляется при обращении.
- Токен в URL/query не принимается; cookie не используется.

### 2.5 Auth-семантика, коды и JSON-envelope

- Защищённые пути: `/api/notes`, `/api/notes/` (все методы). Порядок проверок:
  **auth → метод → путь/id → тело**. Следствие: неавторизованный `PUT` или
  `DELETE /api/notes/abc` даёт **401**, а не 405/400; авторизованный — 405/400.
- Публичные: `/api/register`, `/api/login` (неизвестный метод → 405).
- Ошибки — единый JSON `{"error":"..."}` **для всех кодов** (401/400/404/405/
  409/500). `Content-Type: application/json`.
- Текущий код использует `http.Error`, который ставит `text/plain` и добавляет
  `\n`. Нужен хелпер `writeErr(w, code, msg)` + `writeJSON(w, code, v)`;
  строки ошибок сохраняем прежними (`"invalid id"`, `"not found"`,
  `"method not allowed"`, `"text required"`), чтобы не ломать audit-оракулы.
- `DELETE` своей заметки → **204 без тела**; чужая/несуществующая → **404**
  (`{"error":"not found"}`); нечисловой/пустой/overflow id → 400.
- `POST /api/notes` → 201 `{"id":N,"text":"..."}`; пустой/отсутствующий `text`
  → 400.
- `POST /api/register` → 201 `{"id":N,"username":"..."}`; пустые/битые поля →
  400; занятый username → 409. Тело ограничить `http.MaxBytesReader` (1 MiB).
- `POST /api/login` → 200 `{"token":"..."}`; неверная пара → 401 (одинаково для
  «нет пользователя» и «неверный пароль»).
- `GET /api/notes` → 200 `[]` (не `null`), только `UserID == current`.
- `Content-Type` проверять не строго (curl/Playwright шлют корректный); JSON
  декодировать с лимитом тела.

### 2.6 Статический UI: `go:embed` vs file serving

**Решение: `go:embed`.** Обоснование:

1. `deploy/Dockerfile` сейчас копирует только `main.go`; runtime-стадия содержит
   только бинарь. При file serving пришлось бы копировать `web/` в runtime-образ,
   задавать WORKDIR и рисковать 404 при неверном cwd. С embed достаточно
   добавить `COPY web/ ./web/` в **build stage** — runtime не меняется.
2. `preview-deploy.sh` (path10 adapter) не трогаем: nginx проксирует `/` на
   `app:8080`, значит UI обязан отдавать сам Go-процесс. Embed гарантирует, что
   UI доступен на test2 без volume mount.
3. Один бинарь = воспроизводимый preview и Playwright по одному origin.
4. Минус (принять): правка UI требует пересборки образа — для dev приемлемо.

Детали:

- Embed-паттерны **явные**, чтобы не затянуть тесты/зависимости:
  `//go:embed web/*.html web/app.js web/styles.css` (или `web/assets/*`), но
  **не** `web/` целиком, иначе в бинарь попадут `web/e2e/` и `node_modules/`.
- Маршруты: `/login` → `login.html`, `/register` → `register.html`,
  `/notes` → `notes.html`, `/` → 302 `/login`; статика — `/app.js`,
  `/styles.css`. HTML отдавать с `Cache-Control: no-store`.
- Сервер не знает про localStorage: guard `notes` — на клиенте (нет токена →
  `/login`); API всё равно вернёт 401.
- `.dockerignore`: `web/node_modules/`, `web/e2e/` (spec не нужен в образе).

### 2.7 path1 adapter (значения, которые должны быть на поздних шагах)

`path1.project.json` (s02 не редактирует; целевое состояние):

| Поле | Сейчас | Целевое | Комментарий |
|---|---|---|---|
| `e2e.frontend_dir` | `""` | `"web"` | UI-каталог для E2E/UI-гейтов |
| `e2e.command` | `bash deploy/path1/e2e-preview.sh` | оставить ту же строку, изменить **содержимое** скрипта: auth-smoke + Playwright | gate `e2e-preview` читает это поле; один вход |
| `deploy.stand_command` | `bash deploy/path1/preview-deploy.sh {stand} {ref}` | **не менять** | это path10 adapter, не archkit fallback |
| `audit.mode` | `app` | `app` | уже верно |
| `audit.database` | `false` | `false` | уже верно |
| `canaries.require_dsn` | `false` | `false` | уже верно |
| `canaries.items` | `CANARY-DELETE-STATUS` (sed по `main.go`) | сохранить + добавить auth/изоляцию | см. риск R8: sed должен попадать в файл с литералом |

`path1.ui.json`:

```json
{ "platform": "web", "note": "Записная книга — web UI (login/register/notes), API same-origin" }
```

`audit.oracles` рекомендуется расширить (имена тестов сохранить/добавить):
`CONTRACT-STATUS-CODE` (+ `TestAuthRequired|TestRegister|TestLogin|TestNotesIsolation`),
`SEC-ERROR-LEAK` (+ `TestPasswordNotLeaked`), `SEC-WRITE-VERB-REJECT` (как есть),
новые `SEC-AUTH-REQUIRED`, `SEC-USER-ISOLATION`.

### 2.8 UI-граф

Gate `gate-graph-actualized` (s21 и s24) принимает
`arch/structure/ui-pages/*.yaml` **или** `UI-GRAPH.yaml`, актуализированный этим
прогоном. Процесс s04 (`arch_writes`) упоминает `arch/frontend/pages/*.yaml`, но
гейт перечисляет `arch/structure/ui-pages/*` — чтобы не спорить с гейтом,
**выбираем `arch/structure/ui-pages/`** (см. OD-11).

Создать три per-page файла:

- `arch/structure/ui-pages/login.yaml` — route `/login`, guest, элементы
  `username`, `password`, `submit`, `error`, состояния `idle/submitting/error`,
  API `POST /api/login`, переход `success → /notes`.
- `arch/structure/ui-pages/register.yaml` — route `/register`, guest, поля
  `username`, `password`, `confirm`, `submit`, `error`, API
  `POST /api/register`, переход `201 → /login`, `400/409 → error`.
- `arch/structure/ui-pages/notes.yaml` — route `/notes`, auth guard (token в
  localStorage), элементы `note-list`, `note-item (delete)`, `note-input`,
  `add`, `logout?`, `error`, состояния `loading/empty/list/error401`, API
  `GET/POST /api/notes`, `DELETE /api/notes/{id}`, переход `401 → /login`.

Минимальный контракт файла (уточнит graph-builder на s04): `page`, `route`,
`auth`, `nodes[]` (id/kind/label/selector), `states[]`, `api[]`
(method/path/request/response), `transitions[]`. На **s21** граф
актуализируется **по коду** (фактические селекторы/маршруты), а не копируется
из дизайна; без этого гейт s21/s24 падает.

### 2.9 Playwright E2E

- Спека: `web/e2e/auth-notes.spec.js` (путь из запроса).
- Конфиг: `playwright.config.js` (корень или `web/`), `testDir: "web/e2e"`,
  `use.baseURL = process.env.E2E_BASE_URL || "http://127.0.0.1:9082"`,
  `headless: true`, один проект `chromium`.
- Сценарии (ровно из запроса):
  1. регистрация нового пользователя (уникальный username на прогон);
  2. логин, получение токена (UI кладёт в `localStorage["notebook.token"]`);
  3. создание заметки;
  4. reload страницы notes — заметка видна (сессия сохранилась);
  5. удаление заметки;
  6. user B не видит заметку user A (два независимых browser context);
  7. неавторизованный `GET /api/notes` → 401 (APIRequestContext).
- Для изоляции: `browser.newContext()` на пользователя; уникальные имена
  (`a_<runID>`, `b_<runID>`); не полагаться на порядок сценариев.
- Запуск на preview: `deploy/path1/e2e-preview.sh` читает `E2E_BASE_URL` (как
  сейчас), сначала делает curl auth-smoke, затем `npx playwright test` (или
  `npx @playwright/test test`) из корня. Если браузеры не установлены —
  **fail-close** на web-платформе (нельзя «зеленить» E2E без UI-сценариев);
  установка `npx playwright install --with-deps chromium` — ответственность
  runner/стенда (см. риск R4).
- `/healthz` на стенде отдаёт **nginx** (JSON build_ref/commit), а app-`/healthz`
  отдаёт `ok\n`; Playwright не должен проверять app-`/healthz` как JSON.

### 2.10 Тесты Go (целевой набор)

- Обязательные имена сохранить: `TestDeleteNote`, `TestDeleteErrorEnvelope`,
  `TestNotesMethodNotAllowed` (их используют canary и `audit.oracles`).
- Новые: `TestAuthRequired` (все методы `/api/notes*` без токена → 401),
  `TestRegister`, `TestRegisterDuplicate` (409), `TestLoginInvalid` (401,
  одинаковый для нет/неверного пользователя), `TestNotesIsolation`
  (A не видит/не удаляет B), `TestPasswordNotLeaked` (нет `password/hash/salt`
  в JSON), `TestTokenExpiry` (инъекция `now`), unit-тест
  `TestPasswordHashVerify` (PBKDF2 детерминизм/constant-time compare).
- Прогон `go test -race ./...` — отдельный оракул/локальная проверка.

---

## 3. Влияние на существующий DELETE-note контракт

### 3.1 Что ломается

Все текущие тесты ходят на `/api/notes*` **без** `Authorization`. После
введения auth-guard они получат 401 ещё до разбора метода/id:

| Тест | Почему падает |
|---|---|
| `TestNotesLifecycle` | `GET/POST /api/notes` без токена → 401 вместо 200/201 |
| `TestDeleteNote` | seed POST, DELETE, повторный DELETE, invalid id — всё без токена |
| `mustSeedNote` (helper) | POST без токена → 401 |
| `TestAddNote` | POST без токена → 401 |
| `TestDeleteExisting` | seed/DELETE без токена → 401 |
| `TestDeleteMissing` | ожидает 404, получит 401 (auth раньше пути) |
| `TestDeleteInvalidID` | ожидает 400, получит 401 |
| `TestListAfterDelete` | seed/GET/DELETE без токена → 401 |
| `TestNotesMethodNotAllowed` | ожидает 405, получит 401 |
| `TestDeleteErrorEnvelope` | ожидает 400/404, получит 401 |

### 3.2 Контракт «до → после»

| Endpoint | До | После |
|---|---|---|
| `GET /api/notes` | 200, все заметки, без auth | 200, только свои; без/битый/истёкший токен → 401 |
| `POST /api/notes` | 201 `Note`, без auth | 201 своя заметка; 401 без токена; 400 пустой text |
| `DELETE /api/notes/{id}` | 204/400/404, без auth | auth → 204 своя; 404 нет/чужая; 400 нечисловой id; 401 без токена |
| `POST /api/register` | — | 201 `{id,username}` / 400 / 409 |
| `POST /api/login` | — | 200 `{token}` / 400 / 401 |
| error body | `http.Error` → `text/plain` + `\n` | `application/json` + `{"error":"..."}` (строки те же) |

### 3.3 План миграции `main_test.go`

1. Добавить helper `seedUser(t, h) (username, token)`:
   `POST /api/register` (уникальный username через `t.Name()`/счётчик) +
   `POST /api/login`; вернуть токен.
2. Добавить helper `authedRequest(t, h, method, path, body, token)` —
   `httptest.NewRequest` + `Authorization: Bearer <token>`.
3. Переписать существующие тесты на `authedRequest`, сохранив **имена** и
   проверяемые коды/тела (`204`, `400 invalid id`, `404 not found`,
   `405 method not allowed`).
4. Отдельно закрепить новый порядок: неавторизованный любой метод на
   `/api/notes*` → 401 (включая нечисловой id и «неправильный» метод).
5. Сохранить литерал `http.StatusNoContent` в обработчике DELETE (canary
   `CANARY-DELETE-STATUS` делает `sed s/http.StatusNoContent/http.StatusOK/`).
6. **Не переносить** DELETE-обработчик из `main.go` в другой файл без правки
   canary `seed`/`detect`. Иначе sed не найдёт строку, тест останется зелёным —
   ложнозелёная канарейка (риск R8).
7. `go test -race ./...` + `go vet ./...` как локальный DoD.

### 3.4 Совместимость адаптера

- `deploy.stand_command` не меняется; `preview-deploy.sh` не меняется по
  смыслу (только Dockerfile build-stage получает `web/`).
- `e2e.command` остаётся `bash deploy/path1/e2e-preview.sh`, но скрипт
  перестаёт быть «безавторизационным»: старые `GET/POST /api/notes` без токена
  дадут 401 → gate `e2e-preview` упадёт, если скрипт не обновить (s20a/s20c).

---

## 4. Риски и митигации

| ID | Риск | Влияние | Митигация | Шаг |
|---|---|---|---|---|
| R1 | Утечка `password`/`hash`/`salt` в JSON или логи | security-блокер | отдельные response-структуры, `json:"-"`, запрет логировать креды, `TestPasswordNotLeaked` | s20 |
| R2 | Enumeration/timing: разный ответ для «нет пользователя» и «неверный пароль» | утечка списка пользователей | одинаковый 401 + dummy-PBKDF2 для несуществующего; 409 на register осознанно (OD-15) | s20, s22b |
| R3 | Гонки/порча Store (users/sessions/notes) | 500/потеря данных | один `Store.mu`, `regMu` на register, hash вне lock, `go test -race` | s20 |
| R4 | На preview нет docker/сети/Playwright/браузеров | s20c не зелёный | API-smoke всегда; Playwright обязателен для web, браузеры ставит runner; fail-close с явной ошибкой; не «зеленить» при отсутствии браузера | s19/s20c |
| R5 | UI-граф не актуализирован/не тот путь | gate s21/s24 quarantine | `arch/structure/ui-pages/*.yaml` по коду на s21; `feature_profile=full` | s04/s21 |
| R6 | Playwright на стенде: общий in-memory store между тестами | flaky/ложные падения | уникальные username, отдельные browser context, независимые сценарии, без общего порядка | s20c |
| R7 | Dockerfile не копирует `web/` → сборка/UI 404 | preview не стартует | `COPY web/ ./web/` в build stage, `.dockerignore` (node_modules/e2e), локальная проверка `docker build` | s20/s20b |
| R8 | Canary `CANARY-DELETE-STATUS` sed по `main.go` перестал попадать в литерал | ложнозелёная канарейка / gate canary | оставить DELETE в `main.go` или синхронно обновить `seed`+`detect`; добавить auth-канарейку | s20/s22b |
| R9 | Старый `e2e-preview.sh` без auth | gate `e2e-preview` красный | обновить скрипт: register/login → authed GET/POST/DELETE + 401-проверка | s20a/s20c |
| R10 | localStorage + HTTP на стенде (XSS/перехват токена) | компрометация сессии | dev-only допущение; TTL 24h; не хранить пароль; опционально CSP; явно зафиксировать в брифе | s05/s06 |
| R11 | Большие/мусорные тела, перебор паролей | DoS/brute-force | `MaxBytesReader` 1 MiB, лимиты полей; rate limiting — OD (вне scope по брифу) | s20 |
| R12 | Неверный порядок auth/метод/id | 401 vs 405/400 дрейф контракта | зафиксировать «auth → method → id → body» тестами `TestAuthRequired`/`TestNotesMethodNotAllowed` | s20 |
| R13 | Username Unicode/регистр/пробелы | дубли/непредсказуемый логин | trim, валидация `[A-Za-z0-9_-]{3,32}`, case-sensitive (OD-13) | s20 |
| R14 | Health-check стенда путает app/nginx | ложный E2E-успех/фейл | помнить: `/healthz` на стенде — nginx JSON; app-`/healthz` — `ok\n`; E2E проверяет UI/API, не app-health | s20c |
| R15 | `feature_profile`/`platform` не выставлены | s03/s04/s21/s22a пропущены, s24 gate падает | установить `feature_profile=full`, `path1.ui.json.platform=web` (I1) | s05/старт |

---

## 5. open_decisions[] (двусмысленности, не решать молча)

> Формат: id — вопрос; варианты; **рекомендация**; `decision_ref` (цитата
> сырого запроса/брифа). Эти пункты уходят в s07 → вопрос человеку на s08.

### OD-01. DELETE чужой заметки: 404 или 403?
- A) **404** (не раскрывать существование чужого id).
- B) 403 (явно «запрещено», но подтверждает существование).
- **Рекомендация: A — 404.** `decision_ref`: «удалить только свою заметку»,
  «user A не видит и не удаляет заметки user B».

### OD-02. Алгоритм хэширования пароля
- A) **PBKDF2-HMAC-SHA256 на stdlib** (соль 16B, 210k, 32B).
- B) bcrypt (`golang.org/x/crypto`) — новая зависимость, нужен `go mod download`.
- C) argon2id (`x/crypto`) — тоже зависимость.
- **Рекомендация: A.** Офлайн-сборка, Go 1.23, stdlib-only.
  `decision_ref`: «соль + hash», «без БД/внешних сервисов».

### OD-03. TTL bearer-токена
- A) **24h fixed** от логина, без refresh/sliding.
- B) 1h fixed (безопаснее, но чаще логин).
- C) sliding expiry (вне scope по брифу).
- **Рекомендация: A (24h), часы инъектируемы для тестов.**
  `decision_ref`: «bearer-токен» (TTL в запросе не задан).

### OD-04. Logout-эндпоинт
- A) **Не добавлять** (`POST /api/logout` в запросе отсутствует).
- B) Добавить `POST /api/logout` (удаляет сессию) — удобно, но расширяет scope.
- **Рекомендация: A — вне scope**; UI-«выход» = удалить токен из localStorage
  (сессия истечёт/останется на сервере до TTL). `decision_ref`: список API в
  запросе без logout.

### OD-05. Ответ `POST /api/register`
- A) **201 `{"id":N,"username":"..."}`** (как в брифе).
- B) 201 без тела (меньше данных).
- C) 201 + сразу токен (auto-login) — в запросе логин отдельным шагом.
- **Рекомендация: A.** `decision_ref`: «`POST /api/register` ... -> 201».

### OD-06. Регистрация с занятым username
- A) **409** (явно и просто).
- B) 200/201 идемпотентно (скрывает существование, но врёт о создании).
- C) 400 (смешивает с валидацией).
- **Рекомендация: A — 409**, enumeration через register принимаем для dev.
  `decision_ref`: в запросе код не задан, бриф предлагает 409.

### OD-07. Строгость валидации полей
- A) **Строгая**: username `[A-Za-z0-9_-]{3,32}`, password ≥ 8 (≤ 128),
  text 1–4096.
- B) Только non-empty + верхние лимиты (минимум домыслов).
- **Рекомендация: A**, но зафиксировать как «добавлено от себя» в intent-trace;
  иначе B. `decision_ref`: в запросе только «битые/пустые поля».

### OD-08. Раздача UI: `go:embed` или файлы с диска
- A) **`go:embed`** (один бинарь, preview без volume, Dockerfile + COPY web в
  build stage).
- B) `http.FileServer` по `web/` (правки без пересборки, но нужен `web/` в
  runtime-образе и cwd).
- **Рекомендация: A.** `decision_ref`: «статическая страница ... или Go embed»,
  «COPY только main.go» (текущий Dockerfile).

### OD-09. Структура UI
- A) **3 отдельных HTML** (`login/register/notes`) + общий JS/CSS, чистые URL.
- B) Один `index.html` SPA с hash-routing.
- **Рекомендация: A** — проще UI-граф из 3 страниц и Playwright reload.
  `decision_ref`: «Страницы: login, register, notes».

### OD-10. Где хранить токен
- A) **localStorage** (reload сохраняет сессию — сценарий E2E №4).
- B) `sessionStorage` (живёт вкладку; reload сохраняет, но не новые вкладки).
- C) только память JS (reload разлогинивает — ломает сценарий).
- **Рекомендация: A** `localStorage["notebook.token"]`.
  `decision_ref`: «токен в памяти/localStorage», «reload — заметка видна».

### OD-11. Формат UI-графа
- A) **`arch/structure/ui-pages/{login,register,notes}.yaml`** (per-page).
- B) Один `UI-GRAPH.yaml`.
- **Рекомендация: A** — гейт перечисляет этот glob первым, per-page проще
  актуализировать; не дублировать два источника истины. `decision_ref`:
  «`arch/structure/ui-pages/...` или `UI-GRAPH.yaml`».

### OD-12. E2E-runner на стенде
- A) **Playwright обязателен** (spec из запроса), API-smoke как быстрый префлайт;
  браузеры ставит runner; отсутствие → fail-close.
- B) Playwright опционален, gate держится на curl-сценариях.
- **Рекомендация: A** (иначе UI-фича принимается без UI-E2E).
  `decision_ref`: «Добавить Playwright `web/e2e/auth-notes.spec.js`».

### OD-13. Username: регистр/нормализация
- A) **case-sensitive**, trim пробелов, `[A-Za-z0-9_-]{3,32}`.
- B) case-insensitive (lowercase-канонизация) — меньше дублей, но меняет
  ожидания логина.
- **Рекомендация: A** для минимального сюрприза; зафиксировать в спеке.
  `decision_ref`: формат username в запросе не задан.

### OD-14. Порядок заметок в `GET /api/notes`
- A) **Порядок вставки** (текущее поведение `[]Note`).
- B) Новые сверху (удобнее UI, но меняет контракт/тесты).
- **Рекомендация: A** — минимизировать дрейф; UI может развернуть на клиенте.
  `decision_ref`: формат списка в запросе не задан.

### OD-15. `feature_profile` для прогона
- A) **`full`** (backend + frontend; s03/s04/s21/s22a исполняются).
- B) `frontend` (тоже включает UI-шаги, но семантически уже).
- C) `backend` (UI-шаги и s21-gate отключатся — **противоречит** запросу).
- **Рекомендация: A.** `decision_ref`: «s21 gate-graph-actualized не скипать» +
  UI в запросе.

### OD-16. Rate limiting на login
- A) **Вне scope** (бриф: dev, не требуется).
- B) Минимальный лимит (5/мин на username) — security-инвариант.
- **Рекомендация: A**, зафиксировать как принятый риск; при требовании — B.
  `decision_ref`: «Rate limiting ... для dev не требуются».

---

## 6. Рекомендации для s03–s05

### s03.proto_visualize
- ASCII-схемы трёх экранов: `login`, `register`, `notes`; для каждого —
  состояния `idle / submitting / error(400,401,409) / empty / list / loading`.
- Явно показать: переходы (`register 201 → login`, `login 200 → notes`,
  `notes 401 → login`), хранение токена (`localStorage["notebook.token"]`),
  reload-сценарий, кнопку delete у своей заметки.
- Не рисовать «выйти», если OD-04 = A (иначе пометить как optional).

### s04.graph_builder_design
- Создать **planned**-граф в `arch/structure/ui-pages/{login,register,notes}.yaml`
  (OD-11 = A) с route/auth/nodes/states/api/transitions.
- Отразить same-origin API (`/api/*`) и отсутствие отдельного frontend-сервера.
- Не создавать одновременно `UI-GRAPH.yaml` и `ui-pages/*` как два источника
  истины; если graph-builder требует единый файл — согласовать и оставить один.

### s05.architect_validation
- Проверить дизайн против ограничений: stdlib-only, Go 1.23, один Store/mutex,
  embed, 404-семантика, JSON-envelope, 401-before-method.
- Опубликовать `open_decisions[]` из §5 с `decision_ref` на сырой запрос; **не
  закрывать** OD-01/02/03/04/06/07/08/09/10/12/15 молча.
- Зафиксировать интеграционные условия (см. ниже I1–I3) как обязательные для
  s20/s21/s24.

### Интеграционные заметки для team-lead / поздних шагов
- **I1 (критично).** Выставить `feature_profile=full` (OD-15) и
  `path1.ui.json.platform=web` **до** s20/s21. Иначе шаги s03/s04/s21/s22a
  отфильтруются по `when`, а `gate-graph-actualized` на s24 упадёт для UI-фичи.
- **I2.** `path1.project.json`: `e2e.frontend_dir=web`, `deploy.stand_command`
  оставить path10 (`bash deploy/path1/preview-deploy.sh {stand} {ref}`),
  `audit.mode=app`, `audit.database=false`, `canaries.require_dsn=false`.
  `e2e.command` не менять строкой, обновить тело `e2e-preview.sh`.
- **I3.** Dockerfile: `COPY web/ ./web/` в build stage + `.dockerignore`;
  `preview-deploy.sh` не трогать. Canary `CANARY-DELETE-STATUS` держать
  валидной (литерал `http.StatusNoContent` в `main.go` или обновить sed).
- **I4.** Для s06/s07: `invariants.json` должен получить core `INV-UI-TRUTH`,
  `INV-UI-LABEL`, `INV-UI-A11Y-NAME` (active, исполнимый `test_ref`),
  `INV-UI-ORACLE` (proposed до s22a) и `INV-UI-E2E-PREVIEW` (оракул — s20c);
  `intent-trace.json` — по каждому пункту сырого запроса, включая OD-решения.

---

## 7. Итог (кратко)

- Затрагиваются 11 слоёв: API, auth/session, notes, UI, embed, Go-тесты, E2E,
  deploy/preview, path1 adapter, UI-граф, invariants/audit.
- Ключевые решения: один `Store` + `mu`/`regMu`; PBKDF2-HMAC-SHA256 stdlib;
  bearer 32B/24h; 404 для чужой заметки; `go:embed`; 3 статических страницы;
  `arch/structure/ui-pages/*.yaml`; Playwright по `E2E_BASE_URL`.
- Главный контрактный разрыв: все `/api/notes*` становятся auth-required →
  `main_test.go` мигрирует, имена `TestDeleteNote`/`TestDeleteErrorEnvelope`/
  `TestNotesMethodNotAllowed` сохраняются ради canary/audit.
- 16 open_decisions вынесены в §5; молча не закрываются, уходят в s07/s08.
