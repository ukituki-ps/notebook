# f-v3-auth-notes — spec/core

- Execution: **E4312**, шаг **s14.spec_generation**
- Repo: `/workspace/projects/notebook`, ветка `dev/f-v3-auth-notes`, база `8e0e949`
- Change class: **security**; `feature_profile=full`; `path1.ui.json.platform=web`
- Нормативная база: [feature-brief.md](../feature-brief.md) (FINAL + invariants),
  [change-definition.md](../change-definition.md), [plan.md](../plan.md),
  [scope-report.md](../scope-report.md), [expertise-report.md](../expertise-report.md),
  [intent-brief.md](../intent-brief.md), [intent-trace.json](../intent-trace.json),
  [invariants.json](../invariants.json), `arch/structure/ui-pages/*.yaml`,
  `main.go` (base), `main_test.go` (base), `path1.project.json`, `path1.ui.json`.
- Матрица «endpoint × code × envelope × test» — [contract-matrix.md](./contract-matrix.md).
- Границы шага: только спеки. Код, `main.go`, `main_test.go`, адаптеры, Dockerfile,
  deploy-скрипты и UI-граф на s14 не меняются.

Спека описывает **целевой** контракт. Расхождения с текущим backend (`8e0e949`)
перечислены в §12 и являются осознанными (breaking change), а не дрейфом.

## 0. Границы контракта и OpenAPI

Внешний контракт `notebook-api` — ровно пять операций: `POST /api/register`,
`POST /api/login`, `GET /api/notes`, `POST /api/notes`, `DELETE /api/notes/{id}`.
`/healthz` и раздача статики — вспомогательные, в auth-контракт не входят.

### 0.1 OpenAPI не ведётся

`openapi/modules/*.yaml` в этом app-репо **не создаётся** (как и в f-dev-v1):
нет `openapi/common.yaml`, нет generated-кода (`internal/api/generated`), нет
кодогенерации/contract-first пайплайна. Источник истины контракта —
этот `core.md` + `contract-matrix.md` + имена/ассерты тестов из §7.
`gate-contract-sync`/`gate-shared-contract` при пустом `spec_glob` — N/A
(precedent: `doc/идеи/f-dev-v1/result-audit.md`, «no OpenAPI modules in this app
repo»). Если в репо появится `openapi/common.yaml`, модуль
`openapi/modules/notebook.yaml` добавляется отдельным шагом; в этом прогоне
`specs[].openapi_path = ""`.

## 1. API-контракт

### 1.1 Общие правила

- Все тела ответов — `application/json` (`Content-Type: application/json`),
  кроме `204`, у которого тела и `Content-Type` нет.
- Ошибки — единый envelope `{"error":"<literal>"}`, без stack/имён файлов/
  внутренних деталей.
- Запросы с телом: `http.MaxBytesReader` **1 MiB** (register, login, POST notes).
  Превышение/битый JSON → `400 {"error":"invalid request body"}`.
- Неизвестные JSON-поля игнорируются; неверные типы → `400 invalid request body`.
- `Content-Type` запроса строго не валидируется; токен — только заголовок
  `Authorization`, не query/cookie.
- Wire-ключи только нижний регистр: `id`, `text`, `token`, `username`, `error`
  (INV-WIRE-CASING); лишние поля запрещены.

Заголовки:

| Ситуация | Заголовок |
|---|---|
| любой `401` | `WWW-Authenticate: Bearer` |
| `405` на `/api/notes` | `Allow: GET, POST` |
| `405` на `/api/notes/{id}` | `Allow: DELETE` |
| `405` на `/api/register`, `/api/login` | `Allow: POST` |
| HTML-страницы UI | `Cache-Control: no-store` |
| все JSON-тела | `Content-Type: application/json` |

Лимиты:

| Что | Лимит |
|---|---|
| тело запроса (register/login/POST notes) | 1 MiB |
| `username` | 3–32 символа, `[A-Za-z0-9_-]`, после `TrimSpace` |
| `password` | 8–128 символов (UTF-8 runes; не trim) |
| `text` | 1–4096 байт UTF-8, не пустой/не whitespace-only |
| число заметок, сессий | не ограничено (dev, in-memory) |
| TTL сессии | 24h fixed |

### 1.2 Операции

| Метод | Путь | Auth | Тело запроса | Успех | Ошибки |
|---|---|---|---|---|---|
| POST | `/api/register` | нет | `{"username":"...","password":"..."}` | `201 {"id":N,"username":"..."}` | `400` поля/тело, `409 username taken`, `405`+`Allow: POST`, `500` |
| POST | `/api/login` | нет | `{"username":"...","password":"..."}` | `200 {"token":"<opaque>"}` | `400` поля/тело, `401 unauthorized`, `405`+`Allow: POST`, `500` |
| GET | `/api/notes` | да | — | `200 [{"id":N,"text":"..."}]`, только свои, `[]` при пустом | `401`, `405`+`Allow: GET, POST` |
| POST | `/api/notes` | да | `{"text":"..."}` | `201 {"id":N,"text":"..."}`, владелец из токена | `400 text required`/`400 invalid request body`, `401`, `405`+`Allow: GET, POST` |
| DELETE | `/api/notes/{id}` | да | — | `204` без тела | `400 invalid id`, `401`, `404 not found` (нет/чужая), `405`+`Allow: DELETE` |

`500 {"error":"internal error"}` — только отказ `crypto/rand`/encode; наружу без
деталей, в лог без паролей/токенов/hash. Тестом не закрепляется (недетерминированный
failure-путь), но envelope обязателен для всех кодов.

### 1.3 Порядок проверок

- Публичные `/api/register`, `/api/login`: **method → body → validation**.
- Защищённые `/api/notes`, `/api/notes/`: **auth → method → path/id → body**.
  Следствия, обязательные к закреплению:
  - без/битый/истёкший bearer на **любой** метод и **любой** id → `401`,
    включая `PUT /api/notes`, `GET /api/notes/abc`, `DELETE /api/notes/abc`;
  - авторизованный неверный метод на item-пути (`GET/POST/PUT/PATCH
    /api/notes/{id}`) → `405`, а не `400 invalid id`;
  - авторизованный `DELETE /api/notes/abc` → `400 invalid id`.
- Неизвестный `/api/*` → `404 {"error":"not found"}` (JSON, не HTML).
- `/api/notes` (коллекция) и `/api/notes/` (item) — разные обработчики;
  `/api/notes/` с пустым id → `400 invalid id`.

### 1.4 Литералы ошибок (стабильные)

| Код | `error` | Когда | Доп. заголовок |
|---|---|---|---|
| 400 | `username and password required` | пустой `username` (после trim) или пустой `password` (register/login) | — |
| 400 | `invalid username` | username не `[A-Za-z0-9_-]{3,32}` (register) | — |
| 400 | `invalid password` | password вне 8–128 (register) | — |
| 400 | `invalid request body` | тело > 1 MiB / битый JSON / неверный тип поля | — |
| 400 | `text required` | `text` пустой, whitespace-only или > 4096 байт | — |
| 400 | `invalid id` | id пустой/нечисловой/overflow (`DELETE /api/notes/{id}`) | — |
| 401 | `unauthorized` | нет/битый/истёкший токен; неверная пара login | `WWW-Authenticate: Bearer` |
| 404 | `not found` | заметки нет, заметка чужая, неизвестный `/api/*` | — |
| 405 | `method not allowed` | неверный метод на известном пути | `Allow` (см. §1.1) |
| 409 | `username taken` | username уже зарегистрирован | — |
| 500 | `internal error` | rand/encode failure | — |

Литералы `invalid id`, `not found`, `method not allowed`, `text required`
сохраняются от base-контракта (audit-оракулы `CONTRACT-STATUS-CODE`,
`SEC-ERROR-LEAK`, `SEC-WRITE-VERB-REJECT`).

## 2. Модель данных

### 2.1 Структуры (in-memory, один процесс)

```go
type User struct {
    ID           int
    Username     string
    PasswordHash []byte // json:"-" — никогда не сериализуется
    Salt         []byte // json:"-" — никогда не сериализуется
}
type Session struct {
    Token     string    // json:"-" — наружу только в теле login 200
    UserID    int       // json:"-"
    ExpiresAt time.Time // json:"-"
}
type Note struct {
    ID     int    // json:"id"
    UserID int    // json:"-" — владелец не раскрывается
    Text   string // json:"text"
}
```

`Store` (без БД): `mu sync.Mutex` на users/sessions/notes/next*,
`regMu sync.Mutex` только на register, `now func() time.Time` (default
`time.Now`, инъекция для TTL-тестов), `nextUser`, `nextNote`, `usersByID
map[int]*User`, `usersByName map[string]*User`, `sessions map[string]*Session`,
`notes map[int]Note`. Рестарт процесса очищает всё — норма для dev.

### 2.2 Wire-формат

| Ответ | Тело | Ключи ровно |
|---|---|---|
| register 201 | `{"id":N,"username":"<как сохранён>"}` | `id`, `username` |
| login 200 | `{"token":"<base64url 43 символа>"}` | `token` |
| notes GET 200 | `[{"id":N,"text":"..."}]`, `[]` при пустом (не `null`) | `id`, `text` |
| notes POST 201 | `{"id":N,"text":"..."}` | `id`, `text` |
| DELETE 204 | пусто | — |
| любая ошибка | `{"error":"<literal>"}` | `error` |

Порядок `GET /api/notes` — порядок вставки (id глобально монотонные, не
переиспользуются), без сортировки на сервере.

### 2.3 Что НЕ сериализуется

- `User.PasswordHash`, `User.Salt`, `User` целиком (наружу — отдельная
  response-структура `{id,username}`);
- `Session.Token` (кроме поля `token` в теле login 200), `Session.UserID`,
  `Session.ExpiresAt`;
- `Note.UserID`;
- никакие поля `password`/`hash`/`salt`/`user_id`/`expires_at` не появляются
  ни в одном ответе (INV-NO-SECRET-LEAK, INV-WIRE-CASING).

### 2.4 Конкурентность

1. PBKDF2 (hash и verify) — **вне** `Store.mu`.
2. Register: `regMu` держится на весь «проверить username → посчитать hash →
   вставить», иначе TOCTOU-дубль при параллельных запросах.
3. `List`/`Delete` копируют/фильтруют под `mu`; JSON-энкодер не читает данные
   без блокировки.
4. Сессии: lookup под `mu`, ленивое удаление истёкшей под `mu`.
5. `go test -race ./...` обязателен.

## 3. Auth и сессии

### 3.1 Пароли

- **PBKDF2-HMAC-SHA256** на stdlib (`crypto/hmac` + `crypto/sha256` +
  `encoding/binary`; `crypto/pbkdf2` в Go 1.23 отсутствует).
- Соль: **16 байт** `crypto/rand` на пользователя.
- Итерации: **210 000**, package-level `var` (тесты понижают и восстанавливают).
- Ключ: **32 байта**.
- Сравнение: `crypto/subtle.ConstantTimeCompare`; не `==` и не `bytes.Equal`.
- Пароль не хранится открыто и не логируется; в JSON не попадает.
- Login с несуществующим username выполняет dummy-PBKDF2 (фиксированная
  dummy-соль, те же итерации/ключ) и возвращает тот же `401 unauthorized`, что
  и неверный пароль (анти-enumeration по времени/ответу).
- `crypto/rand` failure → `500 internal error`, без деградации к предсказуемой
  соли/токену.

### 3.2 Токен

- Непрозрачный (не JWT): **32 случайных байта** `crypto/rand`,
  `base64.RawURLEncoding` → 43 символа без padding.
- Сервер хранит `map[token]*Session`; поиск — по ключу map (не побайтовое
  сравнение по списку). Клиенту токен отдаётся только в `200 /api/login`.

### 3.3 Проверка Bearer

- Заголовок `Authorization`; ровно два токена через пробел: схема + токен.
- Схема `Bearer` case-insensitive; токен непустой; иначе/при отсутствии
  заголовка → `401 unauthorized` + `WWW-Authenticate: Bearer`.
- Токен в query/cookie не принимается; cookie игнорируется.
- Неизвестный токен → `401`; истёкший → `401` + удаление сессии.

### 3.4 TTL и lazy expiry

- TTL фиксированный: `ExpiresAt = now() + 24h` в момент login.
- Sliding/refresh отсутствуют; logout-эндпоинта нет.
- Проверка: `now() >= ExpiresAt` → сессия удаляется при обращении → `401`.
- Часы — `Store.now()`, чтобы TTL-тест был детерминированным.
- UI-«Logout» клиентский (localStorage), серверная сессия живёт до TTL.

## 4. Owner isolation

- `GET /api/notes` → только `Note.UserID == session.UserID`; пусто → `[]`
  (не `null`).
- `POST /api/notes` → `UserID` берётся **только** из сессии; поле владельца в
  теле запроса отсутствует и игнорируется.
- `DELETE /api/notes/{id}`:
  - своя существующая → `204` без тела;
  - несуществующая **или чужая** → `404 {"error":"not found"}` (не `403`, не
    `204`), одинаковое тело и код — существование чужого id не раскрывается;
  - проверка владельца — по `UserID`, не по диапазону id.
- id заметок глобально монотонные, не переиспользуются между пользователями.
- Auth проверяется **раньше** method/id/body (см. §1.3): неавторизованный
  `DELETE /api/notes/{чужой id}` → `401`, а не `404`.
- `Note.UserID` не сериализуется.

## 5. Валидация

| Поле | Правило | Нормализация | Код при нарушении |
|---|---|---|---|
| `username` | после `TrimSpace`: длина 3–32, `^[A-Za-z0-9_-]+$`, ASCII | trim; регистр **сохраняется** (case-sensitive: `Alice` ≠ `alice`) | `400 username and password required` (пусто) / `400 invalid username` (формат) |
| `password` | 8–128 символов (UTF-8 runes); не trim (пробелы значимы) | нет | `400 username and password required` (пусто) / `400 invalid password` (длина) |
| `text` | 1–4096 байт UTF-8; не пустой и не только whitespace | сохраняется дословно (без trim) | `400 text required` |
| `id` | целое ≥ 0 из пути, без overflow | `strconv.Atoi` | `400 invalid id` (пусто/нечисловой/overflow); отрицательный → `404 not found` |

- Register: сначала валидация (400), затем проверка дубля (409); при `409`
  вторая запись не создаётся.
- Дубликат username определяется по точному совпадению (case-sensitive).
- Login не валидирует формат username/password: любая непустая пара, которой
  нет/не совпадает, → `401 unauthorized` (без различения причин).

## 6. UI-спецификация (notebook-web)

### 6.1 Раздача и маршруты

- Один HTML-вход `web/index.html` + `web/app.js` + `web/app.css`; клиентские
  экраны `/login`, `/register`, `/notes` (три страницы-состояния одного
  приложения). Это финальная форма OD-09 по `change-definition.md` C6/plan U02;
  `arch/structure/ui-pages/*.yaml` ссылаются на `source_files: web/index.html`
  и актуализируются по коду на s21.
- `go:embed` **явными** паттернами: `web/index.html web/app.js web/app.css`
  (не `web/` целиком — иначе `web/e2e/`, `node_modules/` попадут в бинарь).
- Маршруты: `/` → `302 /login`; `/login`, `/register`, `/notes` → `index.html`
  (`Cache-Control: no-store`); `/app.js`, `/app.css` → статика с корректным
  `Content-Type`; `/api/*` — API (статика не перекрывает API).
- Same-origin, без CORS/отдельного frontend-сервера.

### 6.2 Общие правила

- `localStorage["notebook.token"]` — bearer-токен (единственный секрет в
  хранилище). `localStorage["notebook.user"]` — только отображаемое имя
  (значение поля username при логине; сервер его не возвращает).
- Пароль никогда не сохраняется в storage.
- Ошибки — одна видимая область `[role="alert"]` с `aria-live="polite"`
  (`login-error`, `register-error`, `notes-error`); не `alert()`; новая ошибка
  заменяет старую.
- `submitting` блокирует кнопку и поля (защита от двойного запроса); `Enter`
  отправляет форму (в textarea `Shift+Enter` — перенос строки).
- Все переходы — `location.replace` (кнопка «Назад» не возвращает на экран с
  невалидной сессией).
- Ошибки не стирают введённый текст, кроме пароля при `401` на login.
- Reload `/notes` сохраняет сессию: токен из localStorage → повторный `GET`.
- Logout — только клиентский: удалить `notebook.token`/`notebook.user`,
  `location.replace("/login")`; `POST /api/logout` не вызывается.

### 6.3 Login (`/login`)

| Элемент | `data-testid` | Подпись / текст | Поведение |
|---|---|---|---|
| карточка | `login-card` | «Вход» | контейнер |
| форма | `login-form` | — | submit по `Enter`/кнопке |
| username | `login-username` | visible `<label for>` «Username» | `autocomplete=username` |
| password | `login-password` | visible `<label for>` «Password» | `type=password`, `autocomplete=current-password` |
| submit | `login-submit` | «Login» | `type=submit`; `submitting` → «Logging in...», disabled |
| error | `login-error` | — | `role=alert` + `aria-live=polite`, скрыт при пустом |
| ссылка | `register-link` | «Register» | переход на `/register` |

Поведение:

- `POST /api/login`; поля тела — `username` (trim) и `password`.
- `200` → `notebook.token = token`, `notebook.user = username` из формы,
  `location.replace("/notes")`.
- `400` → «Username и password обязательны», ввод сохраняется.
- `401` → «Неверный username или пароль», пароль очищается, фокус в Password.
- Открытие `/login` с уже валидным токеном всё равно показывает форму (guard
  только на `/notes`); ссылка Register не скрывается.
- Если задан `sessionStorage["notebook.prefill"]` (после register 201):
  username предзаполнен, ключ удалён, фокус в Password.

### 6.4 Register (`/register`)

| Элемент | `data-testid` | Подпись / текст | Поведение |
|---|---|---|---|
| карточка | `register-card` | «Регистрация» | контейнер |
| форма | `register-form` | — | submit по `Enter`/кнопке |
| username | `register-username` | «Username (3-32: a-z A-Z 0-9 _ -)» | `autocomplete=username` |
| password | `register-password` | «Password (>= 8 символов)» | `type=password`, `autocomplete=new-password` |
| confirm | `register-confirm` | «Confirm password» | `type=password`; **только клиентская** проверка |
| submit | `register-submit` | «Register» | `submitting` → «Registering...», disabled |
| error | `register-error` | — | `role=alert` + `aria-live=polite` |
| ссылка | `login-link` | «Login» | переход на `/login` |

Поведение:

- Confirm пустой или не совпадает → «Passwords do not match», запрос **не**
  отправляется (сервер не получает confirm).
- `POST /api/register` (username trim + password); `201` → «Аккаунт создан.
  Войдите.», `sessionStorage["notebook.prefill"] = username` и через ~0.8 s
  `location.replace("/login")`.
- `400` → строка по коду: пусто — «Username и password обязательны», формат —
  «Username: 3-32 символа, a-z A-Z 0-9 _ -», длина пароля — «Password: от 8 до
  128 символов»; подсветка поля, форма не очищается.
- `409` → «Username уже занят», фокус в Username, пароль сохраняется.
- Дубликат/ошибка не создаёт второй пользователь в UI-состоянии (retry только
  по действию пользователя).

### 6.5 Notes (`/notes`)

| Элемент | `data-testid` | Подпись / текст | Поведение |
|---|---|---|---|
| шапка | `notes-header` | «Notebook» | контейнер шапки |
| имя | `user-name` | значение `notebook.user` | только подпись, не секрет |
| logout | `logout` | «Logout» | клиентский выход (UI-only) |
| форма | `note-form` | «Новая заметка» | контейнер формы добавления |
| textarea | `note-input` | visible `<label for>` «Текст заметки» | `Enter` — submit, `Shift+Enter` — перенос |
| добавить | `add-note` | «Add» | disabled при пустом поле/`submitting` («Adding...») |
| ошибка | `notes-error` | — | `role=alert` + `aria-live=polite`, одна видимая |
| список | `notes-list` | — | `role=list`, элементы `role=listitem` |
| заметка | `note-item` | `#<id> <text>` | атрибут `data-note-id="<id>"` |
| удалить | `delete-note` | видимый текст «Delete» | `aria-label="Удалить заметку #<id>"` |
| пусто | `notes-empty` | «Пока нет заметок. Добавьте первую выше.» | виден только после успешного `GET` с `[]` |
| загрузка | `notes-loading` | «Загрузка...» | пока `GET` не завершён; форма disabled |

Поведение:

- Открытие/reload: нет `notebook.token` → `location.replace("/login")` **без**
  запроса; есть токен → `GET /api/notes` с `Authorization: Bearer <token>`.
- `GET 200` → `list` (`[]` → `empty`); рендерятся только данные ответа, без
  захардкоженных/фантомных заметок.
- Добавление: `POST /api/notes`; `201` → строка добавляется в конец списка из
  ответа (без полного перезапроса), поле очищается, фокус в textarea, empty
  state снимается; `400` → «Текст заметки не может быть пустым» (ввод
  сохраняется).
- Удаление: `DELETE /api/notes/{id}`; во время pending строка приглушена
  (opacity .5), её Delete disabled; `204` → строка удалена из DOM, при
  опустении — `notes-empty`; `404` → «Заметка не найдена» + повторный `GET`;
  `400` → inline-ошибка без удаления строки.
- Любой `401` на `GET`/`POST`/`DELETE` → очистить `notebook.token` и
  `notebook.user`, показать «Сессия истекла. Перенаправление на вход...»,
  `location.replace("/login")`; форма и список блокируются.
- Logout: очистка ключей + `location.replace("/login")`; API не вызывается.
- Повторный клик во время pending игнорируется; текст заметки не дублируется.

### 6.6 Состояния (сводно)

| Экран | Состояния |
|---|---|
| login | `idle`, `submitting`, `error-400`, `error-401`, `success-200` |
| register | `idle`, `submitting`, `error-local-mismatch`, `error-400`, `error-409`, `success-201` |
| notes | `loading`, `empty`, `list`, `submitting-add`, `error-400-add`, `error-401`, `error-404-delete`, `delete-pending`, `logout-local` |

### 6.7 A11y

- У каждого поля — видимый `<label for="<id>">`; у кнопок — accessible name
  (видимый текст Login/Register/Add/Delete; у Delete дополнительно
  `aria-label` с id заметки).
- Ошибки: `role="alert"` + `aria-live="polite"`; одновременно видима одна.
- Список: `role="list"` / `role="listitem"`; при 401 фокус/баннер не теряют
  информацию о причине.
- Focus-visible стили присутствуют; touch-target ≥ 44 px по высоте.
- Контраст текста читаемый (не ниже WCAG AA для обычного текста).

### 6.8 Narrow (< 640px)

Один breakpoint **640px**: шире — карточка по центру (колонка ≤ 640px); уже —
одна колонка, все `input`/`textarea`/`button` на всю ширину, заметка
перестраивается в две строки (текст, затем Delete), длинный текст переносится
(`overflow-wrap: anywhere`), горизонтального скролла нет, тач-таргеты ≥ 44 px.

## 7. Маппинг инвариантов на оракулы

| Invariant | Оракул (файл) | Что именно проверяется |
|---|---|---|
| `INV-AUTH-REQUIRED` | `TestAuthRequired`, `TestLoginInvalid` (`main_test.go`) | все методы `/api/notes*` без/битый/истёкший токен → 401 до 405/400; login неверная пара/нет пользователя → одинаковый 401 |
| `INV-USER-ISOLATION` | `TestNotesIsolation`, `TestDeleteForeignNote` (`main_test.go`) | A не видит/не удаляет note B; DELETE B → 404; GET A не содержит note B |
| `INV-NO-SECRET-LEAK` | `TestNoSecretLeak` (`main_test.go`) | в JSON нет `password`/`hash`/`salt`; `token` только в login 200 |
| `INV-PASSWORD-HASHED` | `TestPasswordHashed` (`main_test.go`) | PBKDF2 детерминизм, разные соли, неверный пароль false, constant-time compare |
| `INV-VERB-REJECT` | `TestNotesMethodNotAllowed`, `TestAuthMethodOrder` (`main_test.go`) | 405 + `Allow` для авторизованных неверных методов; auth раньше method |
| `INV-PREFIX-BOUNDARY` | `TestDeleteInvalidID`, `TestNotesPrefixBoundary` (`main_test.go`) | `abc`/пустой/overflow → 400; отрицательный → 400/404 без паники; `/api/notes/1/x` не трактуется как id 1 |
| `INV-WIRE-CASING` | `TestWireContract` (`main_test.go`) | ключи ровно `id/text/token/username/error`, нижний регистр, без лишних |
| `INV-REAL-TRANSPORT` | `TestHTTPTransport` (`main_test.go`) | тесты через `httptest.Server`/HTTP, не прямые вызовы Store |
| `INV-NO-SKIP-TAGS` | `sh -c "! grep -R -E '^//go:build.*(integration\|e2e\|manual)' --include='*_test.go' ."` | нет build-тегов, исключающих инвариантный набор |
| `INV-UI-TRUTH` | `TestUISemantics` (`web_ui_test.go`) + E2E-4 | embed-ресурсы, нет фантомных заметок, reload = серверный `GET` |
| `INV-UI-LABEL` | `TestUISemantics` | у полей/кнопок подписи; тексты `Login`/`Register`/`Add`/`Delete` |
| `INV-UI-A11Y-NAME` | `TestUISemantics` | accessible name/role; `role="alert"` + `aria-live="polite"` |
| `INV-UI-EMPTY-STATE` | `TestUISemantics` + E2E-5 | `data-testid="notes-empty"` при `[]`; после удаления последней заметки |
| `INV-UI-ORACLE` | `s22a` → `ui-audit.json` (`items[].oracle/evidence`) | `proposed` до s22a; каждый критерий A–L с оракулом |
| `INV-UI-E2E-PREVIEW` | `s20c` → `e2e-preview.sh` + Playwright | `proposed` до s20c; 7/7 на стенде + screenshots |

Команды прогона (из `invariants.json`):

```sh
go test -count=1 -run 'TestAuthRequired|TestLoginInvalid' ./...
go test -count=1 -run 'TestNotesIsolation|TestDeleteForeignNote' ./...
go test -count=1 -run 'TestNoSecretLeak' ./...
go test -count=1 -run 'TestPasswordHashed' ./...
go test -count=1 -run 'TestNotesMethodNotAllowed|TestAuthMethodOrder' ./...
go test -count=1 -run 'TestDeleteInvalidID|TestNotesPrefixBoundary' ./...
go test -count=1 -run 'TestWireContract' ./...
go test -count=1 -run 'TestHTTPTransport' ./...
go test -count=1 -run 'TestUISemantics' ./...
go test -race ./...
```

Сохраняемые имена (canary/audit): `TestDeleteNote`, `TestDeleteErrorEnvelope`,
`TestNotesMethodNotAllowed`.

## 8. E2E-маппинг (Playwright, `web/e2e/auth-notes.spec.js`)

| ID | Сценарий | Оракул | Связь с инвариантом |
|---|---|---|---|
| E2E-1 | Регистрация нового пользователя | `/register` → 201 → `/login`, username предзаполнен | `INV-UI-TRUTH`, `INV-UI-LABEL` |
| E2E-2 | Логин и токен | 200 → `localStorage["notebook.token"]` непустой → `/notes` | `INV-AUTH-REQUIRED`, `INV-UI-TRUTH` |
| E2E-3 | Создание заметки | 201, строка `#id text` в `notes-list` | `INV-USER-ISOLATION` (позитив) |
| E2E-4 | Reload `/notes` | после reload заметка видна (сессия из localStorage) | `INV-UI-TRUTH` |
| E2E-5 | Удаление заметки | 204, строка убрана; пусто → `notes-empty` | `INV-UI-EMPTY-STATE` |
| E2E-6 | A/B изоляция | два `browser.newContext()`: B не видит note A | `INV-USER-ISOLATION` |
| E2E-7 | Неавторизованный `GET /api/notes` | APIRequestContext → 401 + `WWW-Authenticate` | `INV-AUTH-REQUIRED` |

Требования: `baseURL` из `E2E_BASE_URL`, `chromium`, уникальные username на
прогон, независимость от порядка, отдельные context для A/B, отсутствие
браузеров → fail-close (не skip). Полный прогон — s20c.

## 9. Acceptance criteria

- **AC-01 (register 201)**: валидные уникальные username/password → `201`,
  тело ровно `{"id":N,"username":"..."}`, `Content-Type: application/json`.
- **AC-02 (register 400)**: пустые/битые/невалидные поля и тело > 1 MiB →
  `400` с литералами §1.4.
- **AC-03 (register 409)**: повторный username → `409 username taken`, вторая
  запись не создаётся.
- **AC-04 (login 200)**: верная пара → `200`, тело ровно `{"token":"..."}`,
  токен 43 символа base64url, сессия с TTL 24h.
- **AC-05 (login 401)**: неверный пароль и несуществующий username → одинаковые
  `401 unauthorized` + `WWW-Authenticate: Bearer`.
- **AC-06 (auth guard)**: `/api/notes*` без/битый/истёкший токен → `401` для
  любого метода и id, **до** 405/400.
- **AC-07 (изоляция)**: `GET` возвращает только свои заметки, `[]` при пустом
  (не `null`); чужие id в ответе отсутствуют.
- **AC-08 (чужой DELETE)**: чужая и несуществующая заметка → `404 not found`
  без различия.
- **AC-09 (свой DELETE)**: своя заметка → `204` без тела и `Content-Type`;
  повторный DELETE → `404`.
- **AC-10 (env/envelope)**: все ошибки — `{"error":"..."}`; на 405 — `Allow`;
  на 401 — `WWW-Authenticate`; `http.Error` (text/plain) не используется.
- **AC-11 (секреты)**: ни один ответ не содержит `password`/`hash`/`salt`/
  `user_id`; `token` — только login 200.
- **AC-12 (пароли)**: в Store только `Salt` (16B) + `PasswordHash` (32B);
  verify — constant-time; dummy-PBKDF2 на несуществующем username.
- **AC-13 (TTL)**: до 24h — доступ есть; после — `401`, сессия удалена;
  sliding/refresh отсутствуют.
- **AC-14 (валидация)**: username trim/3–32/`[A-Za-z0-9_-]`/case-sensitive;
  password 8–128 символов; text 1–4096 байт, whitespace-only → 400.
- **AC-15 (wire)**: ключи ровно `id`/`text`/`token`/`username`/`error`; нижний
  регистр; лишних полей нет.
- **AC-16 (UI-3 экрана)**: `/login`, `/register`, `/notes` доступны; `/` →
  `302 /login`; HTML с `Cache-Control: no-store`; статика через embed.
- **AC-17 (UI-селекторы/a11y)**: все `data-testid` из §6.3–6.5 присутствуют;
  `role="alert"` + `aria-live="polite"`; видимые labels; тексты кнопок
  `Login`/`Register`/`Add`/`Delete`.
- **AC-18 (UI-состояния)**: loading (`notes-loading`), empty (`notes-empty`),
  list, submitting, delete-pending; 401 → очистка `notebook.token`/
  `notebook.user` + `location.replace("/login")`; reload сохраняет сессию.
- **AC-19 (UI-честность)**: UI не содержит захардкоженных/фантомных заметок;
  список = ответ `GET /api/notes`.
- **AC-20 (canary/транспорт)**: `http.StatusNoContent` и DELETE-обработчик
  остаются в `main.go`; все тесты идут через HTTP-транспорт; build-тегов нет;
  `go test -race ./...` и `go vet ./...` зелёные.

## 10. Негативные и краевые случаи

- `/api/notes` без `Authorization` (GET/POST/PUT/PATCH/DELETE) → `401`
  (до method/id/body), `TestAuthRequired`.
- `Authorization: Basic ...`, `Bearer` без токена, `Bearer a b`, пустой
  заголовок → `401`, `TestAuthRequired`.
- Истёкший токен (`now` после TTL) → `401`, сессия удалена, `TestTokenExpiry`.
- `GET /api/notes` у нового пользователя → `200 []`, не `null`,
  `TestNotesLifecycle`.
- `DELETE /api/notes/abc` авторизованным → `400 invalid id`,
  `TestDeleteInvalidID`.
- `DELETE /api/notes/` (пустой id) → `400 invalid id`, `TestNotesPrefixBoundary`.
- `DELETE /api/notes/999999999999999999999999` (overflow) → `400`, без паники,
  `TestDeleteInvalidID`.
- `DELETE /api/notes/-1` → `404 not found` (или `400`), без паники,
  `TestDeleteInvalidID`.
- `DELETE /api/notes/1/extra` → `400 invalid id`, не удаляет note 1,
  `TestNotesPrefixBoundary`.
- `DELETE` отсутствующей заметки → `404 not found`, `TestDeleteMissing`.
- `DELETE` чужой заметки → `404 not found` (не `403`/`204`),
  `TestDeleteForeignNote`, `TestNotesIsolation`.
- Повторный `DELETE` своей уже удалённой → `404`, `TestDeleteNote`.
- Авторизованный `GET/POST/PUT/PATCH /api/notes/{id}` → `405 method not allowed`
  + `Allow: DELETE`, `TestNotesMethodNotAllowed`.
- Авторизованный `PUT /api/notes` → `405` + `Allow: GET, POST`,
  `TestNotesMethodNotAllowed`.
- `POST /api/notes` с `text=""`, `"   "`, `"\n\t"` → `400 text required`,
  `TestAddNote`.
- `POST /api/notes` с `text` > 4096 байт → `400 text required`.
- `POST /api/notes` без `text`/битый JSON → `400` (`text required`/
  `invalid request body`), `TestAddNote`.
- `POST /api/register` без полей/с пустыми строками → `400 username and
  password required`, `TestRegister`.
- `POST /api/register` с `username="ab"` / `"a b"` / `"юзер"` / 33 символа →
  `400 invalid username`, `TestRegister`.
- `POST /api/register` с `password` 7 или 129 символов → `400 invalid password`,
  `TestRegister`.
- `POST /api/register` с существующим username (в т.ч. `Alice` vs `alice` —
  разные) → `409` только для точного совпадения, `TestRegister`.
- `POST /api/register`/`login` с телом > 1 MiB → `400 invalid request body`.
- `POST /api/login` с несуществующим username и с неверным паролем →
  идентичные `401` (код + тело), `TestLoginInvalid`.
- `POST /api/register`/`login` с `GET` → `405` + `Allow: POST`, `TestRegister`,
  `TestLogin`.
- Неизвестный `/api/unknown` → `404 {"error":"not found"}` (JSON), а не HTML.
- `GET /api/notes` после удаления не содержит удалённую заметку,
  `TestListAfterDelete`.
- Параллельные register с одним username (race) → один `201`, остальные `409`,
  без дублей, `go test -race ./...`.
- `crypto/rand` failure (инъекция) → `500 internal error`, без предсказуемого
  токена; ответ без внутренних деталей.

## 11. Canary-совместимость (`CANARY-DELETE-STATUS`)

Canary в `path1.project.json`:

```
seed:   sed -i 's/http.StatusNoContent/http.StatusOK/' {worktree}/main.go
detect: cd {worktree} && go test -run TestDeleteNote ./...
```

Обязательные условия спеки:

1. **DELETE-обработчик остаётся в `main.go`** (`mux.HandleFunc("/api/notes/", …)`).
   Перенос в другой файл запрещён: sed перестанет попадать в целевой файл, а
   `detect` останется зелёным → ложно-зелёная канарейка.
2. **Литерал `http.StatusNoContent` присутствует в успешной ветке DELETE**
   (`grep -n 'http.StatusNoContent' main.go` непусто). Замена литерала на
   константу/алиас/`204` запрещена.
3. `TestDeleteNote` ассертит ровно `204` для своей заметки; после seed-замены
   на `http.StatusOK` тест обязан упасть (`200 != 204`).
4. Auth-guard не должен маскировать canary: при валидном токене DELETE доходит
   до успешной ветки; `TestDeleteNote` получает токен через `seedUser`.
5. Имена `TestDeleteNote`, `TestDeleteErrorEnvelope`,
   `TestNotesMethodNotAllowed` сохраняются (их используют canaries/audit).

## 12. Contract delta и parity

База — `main.go` на `8e0e949`.

| Операция | Base | Target | Класс |
|---|---|---|---|
| `POST /api/register` | отсутствует | `201 {id,username}` / 400 / 409 / 405 | **added** |
| `POST /api/login` | отсутствует | `200 {token}` / 400 / 401 / 405 | **added** |
| `GET /api/notes` | 200 все заметки, без auth, ошибки `text/plain` | 200 только свои (`[]`), 401, 405, JSON envelope | **changed** |
| `POST /api/notes` | 201 без auth, envelope `text/plain` | 201 своя заметка, 401/400, JSON envelope | **changed** |
| `DELETE /api/notes/{id}` | 204/400/404 без auth, `text/plain` | auth + owner-scope (404 чужая), JSON envelope | **changed** |
| `GET /healthz` | `ok\n` | без изменений | unchanged (вне контракта) |

Итог: **added = 2, removed = 0, changed = 3**.

`contract_parity`: `drift_count = 0`, `items = []` — OpenAPI-модулей и
generated-кода в репо нет (`spec_glob` пуст → N/A), а все отличия от base
перечислены выше как осознанная дельта. Дрейфом считалось бы расхождение
спеки с кодом/артефактом контракта, которого на s14 ещё нет; после s20
сверка повторяется на `gate-contract-sync` (s24).

## 13. Out of scope

- БД/персистентность, DSN, миграции; рестарт очищает users/sessions/notes.
- Prod-деплой, canary rollout, `s45.push_primary`, `s46.post_deploy_verify`,
  push в `main`/`stage`/primary.
- `POST /api/logout`, refresh/sliding TTL, password reset/change, remember-me,
  email.
- Rate limiting, lockout, CAPTCHA (принятый dev-риск, OD-16).
- Фреймворки/сборщики/npm-рантайм для UI; multi-tenant роли/admin/sharing.
- Второй UI-граф (`arch/frontend/pages/*`, `UI-GRAPH.yaml`).
- OpenAPI-модуль (см. §0.1).

## 14. Трассировка решений

| Решение спеки | Источник |
|---|---|
| 5 эндпоинтов, коды, envelope, 401/405-заголовки | `FB §2.1, §3`, `CD C2–C5`, `B1/B6` |
| PBKDF2 16B/210k/32B + constant-time + dummy | `FB §2.4`, `CD C1`, `B3`, OD-02 |
| Токен 32B, TTL 24h, lazy expiry | `FB §2.2`, `CD C1`, `B4`, OD-03 |
| 404 для чужой/несуществующей, auth→method→id→body | `FB §2.1/§3`, `CD C4/C5`, `B5`, OD-01 |
| Валидация 3–32 / 8–128 / 1–4096, trim, case-sensitive | `FB §7.4`, `CD C2`, AN-04, OD-07/OD-13 |
| 409 `username taken`, register без auto-login | `FB §2.1`, `CD C2`, OD-05/OD-06 |
| Три экрана в `web/index.html` + embed, localStorage, UI-состояния | `FB §4`, `CD C6`, `plan U02`, OD-08/OD-09/OD-10 |
| Logout только клиентский | `FB §4/§6`, `CD C6`, OD-04 |
| Canary: DELETE и `http.StatusNoContent` в `main.go` | `CD C5`, `plan §8 R6`, R7 |
| Тесты: имена base + новые security-негативы | `CD C7`, `plan §7`, `B10` |
| `openapi/modules/*.yaml` не ведётся | f-dev-v1 precedent, отсутствие common.yaml/generated |

---

Nexus artifact: `f-v3-auth-notes/spec/core.md` (s14, E4312).
