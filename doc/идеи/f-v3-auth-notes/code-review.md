# Adversarial Code Review — f-v3-auth-notes (E4312, s22c)

- **Шаг:** `s22c.adversarial_code_review` · **Execution:** `E4312`
- **Repo:** `/workspace/projects/notebook` · ветка `dev/f-v3-auth-notes` @ `ba4a132` (HEAD; код идентичен `build_ref=0afe7ee`, который развёрнут на preview)
- **Preview:** `https://test2.nexus.ukituki.tech` · `build_ref=0afe7ee` · `/healthz` 200 · unauth `GET /api/notes` 401
- **Роль:** независимый adversarial reviewer (НЕ автор кода, НЕ s22b red-team; self-review запрещён)
- **Вердикт:** **`pass`** (нет open critical/high; 2 low + 3 info, см. findings)

## 1. Scope

Код и артефакты фичи f-v3-auth-notes на `ba4a132`:

| Область | Файлы |
|---|---|
| Backend | `main.go` (Store/User/Session/Note, PBKDF2-HMAC-SHA256, sessions TTL, JSON limits, auth guard, register/login/notes handlers, owner-scope, id parsing, status codes/headers) |
| Tests | `main_test.go` (24 test-func), `web_ui_test.go` (static UI oracle) |
| UI | `web/app.js`, `web/index.html`, `web/app.css` |
| Deploy | `deploy/Dockerfile`, `deploy/path1/e2e-preview.sh`, `.dockerignore`, `.gitignore`, `package.json`, `playwright.config.js`, `web/e2e/auth-notes.spec.js` |
| Project | `path1.project.json`, `path1.ui.json` |
| Specs/артефакты | `spec/core.md`, `spec/contract-matrix.md`, `invariants.json`, `fault-verdicts.json`, `ui-audit.json`, `red-team-attack-log.md`, `red-team-review.json` (в `doc/идеи/f-v3-auth-notes/`) |

**Методика.** (1) Полный ручной проход кода по классам: гонки (Store/lock/now/regMu),
PBKDF2-параметры и constant-time, token entropy/TTL/lazy expiry, auth order
(401 до 405/400/404), ID parsing (overflow/negative/empty/suffix), JSON body
limits/decoder (unknown fields/trailing garbage), XSS (innerHTML/eval/
document.write), secret leakage, error envelope/headers, cookie/CORS/CSRF,
deploy (COPY web, e2e fail-close), tests (race/flaky/not-executed).
(2) Исполненные проверки: `go build ./...`, `go vet ./...` — GREEN;
`go test -count=1 ./...` — **GREEN (24/24)**; оракул `INV-NO-SKIP-TAGS` —
`! grep -R -E '^//go:build.*(integration\|e2e\|manual)'` — PASS.
(3) Временный probe-тест (создан на прогоне, **удалён после**, `git status`
чист) подтвердил фактические краевые поведения: trailing-garbage JSON,
unknown-`owner`-поле, нижний регистр схемы bearer, `DELETE /-1`, `DELETE /0`,
`GET /login/`, `Bearer <пусто>`.
(4) Сравнение с s22b (red-team) и ui-audit: все `blocked`-атаки s22b
перепроверены по коду; findings ниже — **новые** (s22b `new_findings=[]`).

**Ограничение среды.** `go test -race` в окружении reviewer не исполняется
(нет C-компилятора, нет root; race требует cgo) — расписано в R-9;
гонки покрыты статическим анализом §4.1. Playwright E2E на стенде не
перепрогонялась в этом шаге (evidence s20c: 7/7 + screenshots в
`ui-audit.json`/`fault-verdicts.json` принят как input; перепрогон — зона s20c).

## 2. Findings

| ID | Severity | File:Line | Summary |
|---|---|---|---|
| CR-1 | low | main.go:359 | JSON-декодер принимает trailing-контент после первого значения (`{"text":"a"} x` → 201) |
| CR-5 | low | deploy/path1/e2e-preview.sh:204 | `npm install` в корне репо создаёт `node_modules/`+`package-lock.json`, не покрытые `.gitignore` |
| CR-2 | info | main.go:80 | `Store.usersByID` — write-only структура, никогда не читается |
| CR-3 | info | main.go:36 | Глобальный `pbkdf2Iterations` — латентная race-поверхность при мутации тестами под живым сервером |
| CR-4 | info | main.go:434 | Страницы UI с trailing slash (`/login/`) → `404` JSON, не SPA-shell (spec молчит; UI-путь недостижим) |

### CR-1 · low · main.go:359 (`decodeJSON`)

`json.NewDecoder(r.Body).Decode(dst)` читает **первое** JSON-значение и
останавливается; всё, что идёт после, молча игнорируется. Подтверждено
пробой: `POST /api/notes` с телом `{"text":"a"} trailing-garbage` →
**201** `{"id":2,"text":"a"}`; `{"text":"a"}{"text":"b"}` → **201**
(вторая запись не создаётся, `b` теряется). Spec §1.1/§1.4 этого не
требует («битый JSON» = обрезанный/непарсируемый → 400, закреплено
тестами), т.е. код соответствует спеке; это gap строгости.

- **Почему важно.** Строгий JSON (и большинство фреймворков) отклонили бы
  trailing-контент 400. Сегодня: клиент/прокси/CDN, добавляющий контент к
  телу, или двойная отправка — молча обрабатываются по первому объекту.
  Эксплуатационного эффекта нет (тип-кодек в struct, unknown fields
  игнорируются по спеке), но контракт «один JSON-объект на тело» не
  закреплён.
- **Рекомендация.** В `decodeJSON` после `Decode` проверять отсутствие
  остатка: `dec.More()` / повторный `Decode` → `io.EOF`; при остатке →
  `400 {"error":"invalid request body"}` + тест (негатив на все три
  decodeJSON-эндпоинта). Обновить spec §1.4, если решение принято.

### CR-5 · low · deploy/path1/e2e-preview.sh:204 (+ .gitignore)

`npm install --no-audit --no-fund` выполняется в `$ROOT` (корень репо) и
создаёт `node_modules/` и `package-lock.json`. `.dockerignore` оба
исключает (в образ не попадут — runtime-ок), но **`.gitignore` не
покрывает**: после любого локального прогона e2e `git status` показывает
untracked `node_modules/` (+`package-lock.json`) → риск случайного
коммита тестовых зависимостей.

- **Почему важно.** Гигиена репо / CI-clean: артефакты прогона
  e2e-preview.sh (по его же шапке — «E2E для notebook на арендованном
  стенде») живут в рабочем дереве разработчика без git-ignore.
- **Рекомендация.** В `.gitignore` добавить `node_modules/` и
  `package-lock.json` (либо зафиксировать `package-lock.json` и
  игнорировать только `node_modules/` — для воспроизводимости e2e-зависимости).

### CR-2 · info · main.go:80 (`usersByID`)

`usersByID map[int]*User` создаётся (`NewStore`, строка 92) и
заполняется в `CreateUser` (строка 134), но **нигде не читается**:
lookup — только `usersByName` (Authenticate), списки/удаление — через
`notes`/`noteOrder`. Мёртвая структура (0.3 KB на юзера + map overhead).

- **Почему важно.** Не дефект, но шум в security-критичной модели:
  второй индекс пользователей, который никто не использует, увеличивает
  поверхность и путает аудит (выглядит как незавершённый
  по-userID-lookup, которого нет по контракту).
- **Рекомендация.** Удалить `usersByID` (поле + инициализация + запись) —
  без изменения wire-контракта; либо использовать при наличии будущего
  по-userID-контракта.

### CR-3 · info · main.go:36 (`pbkdf2Iterations`)

Комментарий «Tests may lower it temporarily» описывает мутацию
package-level переменной. Сейчас тесты её **не мутируют** (grep по
`*_test.go`), поэтому активной гонки нет: `go test -race` по текущему
дереву её не найдёт. Но как только тест понизит итерации при живом
httptest-сервере (запросы из других тестов/тот же сервер в фоне),
запись глобальной переменной конкурентно с чтением в `pbkdf2Key`
из handler-goroutines — data race.

- **Почему важно.** Латентный mine: «удобство» тестов (опечатка в
  комментарии) превращается в race на первом же использовании.
- **Рекомендация.** Перенести work factor в `Store` (инъекция как у
  `now`) или параметр `iterations` в `pbkdf2Key`/`hashPassword`; тестам —
  свой Store с пониженным фактором.

### CR-4 · info · main.go:434 (page routes)

`mux.HandleFunc` зарегистрирован для точных `/login`, `/register`,
`/notes`; trailing-slash варианты падают в fallback `/` → `404
{"error":"not found"}` (подтверждено пробой: `GET /login/` → 404 JSON).
Spec §6.1 тракт только без слэша; UI ходит строго на `/login`
(`location.replace`), т.е. с экрана это недостижимо.

- **Почему важно.** Косметический: человек, вставивший `https://stand/login/`,
  получит JSON-404 вместо SPA. Не блокер (spec молчит, e2e/ui-audit не
  затрагивают).
- **Рекомендация.** Либо задокументировать как осознанное (spec §6.1),
  либо маппить trailing-slash варианты на `serveIndex`.

## 3. Классы, проверенные adversarial-проходом — закрыты (evidence)

### 3.1 Гонки (Store/lock/now/regMu) — OK

- `CreateUser` (main.go:109–137): `regMu` держится на весь
  «check → hash (вне mu) → insert», дубль TOCTOU исключён; порядок
  лочей regMu→mu единственный, инверсий нет (в остальных методах — только mu).
- `Authenticate` (141–175): чтение `usersByName` + копирование
  `Salt`/`PasswordHash` под `mu`, PBKDF2-работы вне `mu` (spec §2.4.1).
  User после вставки неизменяем — чтения ссылок на `Salt`/`PasswordHash`
  без лоча безопасны (happens-before через mu).
- `SessionByToken` (178–190): lookup + ленивое удаление истёкших — под `mu`.
- Смена часов `ts.store.now` в тестах — под `store.mu` (main_test.go:106–110),
  `currentTime` читает `s.now()` под `mu` — детерминированный TTL-тест, без гонок.
- Активных data-race не найдено (статически); см. латентный CR-3 и
  ограничение R-9 (`-race` не исполнялся в окружении с22c).

### 3.2 PBKDF2 — OK

- PBKDF2-HMAC-SHA256, stdlib-only (hmac+sha256+binary); реализация
  сверена по структуре (F(P,S,c,i) = HMAC(P, S‖INT(i)), XOR-цепочка,
  truncation) и **закреплена known-vector тестом** (main_test.go:581–584,
  c=1, keyLen=32 → `120fb6cf…70be17b`, вектор x/crypto/pbkdf2) — GREEN.
- Соль 16B `crypto/rand` (rand failure → 500, без деградации к
  фиксированной соли), ключ 32B, 210k итераций, compare —
  `crypto/subtle.ConstantTimeCompare` (main.go:273–276), `==`/`bytes.Equal`
  нет. Dummy-PBKDF2 на неизвестном username (main.go:153–156) → идентичный
  401 (TestLoginInvalid: `wrongPassword.body == unknownUser.body`).
- 210k — нижняя граница по NIST/OWASP-2023 (600k) → residual R-7 (prod-перекалибровка).

### 3.3 Token entropy / TTL / lazy expiry — OK

- 32 байта `crypto/rand` → `base64.RawURLEncoding` = 43 символа без
  padding (main.go:278–284; TestLogin: длина 43 + base64url-алфавит).
- Map-lookup по ключу, не побайтовое сравнение по списку (main.go:181).
- TTL 24h fixed (main.go:31,168); `now >= ExpiresAt` → delete + 401
  (main.go:185–188); TestTokenExpiry: 23h → 200, ровно 24h → 401,
  сессия удалена (`sessionCount()==0`), повтор → 401. Detached-clock
  через `Store.now` — детерминирован, flakiness нет.
- Logout только клиентский, серверной сессии — до TTL (осознанное, spec §3.4;
  residual R-2).

### 3.4 Auth order (401 до 405/400/404) — OK

- `requireAuth` вызывается **первым** в `handleNotes`/`handleNoteItem`
  (main.go:529–533, 555–558): без/битый/истёкший токен → 401 для
  любого метода и id, включая `PUT /api/notes`, `GET /api/notes/abc`,
  `DELETE /api/notes/{чужой}` (TestAuthRequired, TestAuthMethodOrder,
  TestNotesMethodNotAllowed — GREEN; probe: `GET /login/`… не релевантно,
  `Bearer <пусто>` → 401 подтверждено).
- Авторизованный неверный метод на item → 405+`Allow: DELETE` (не 400
  invalid id); авторизованный `DELETE /api/notes/abc` → 400 invalid id.
- `bearerToken` (362–372): ровно 2 части, схема case-insensitive
  (`EqualFold` — подтверждено пробой: `bearer <token>` → 200),
  `Bearer a b` (3 части) → 401 (TestAuthRequired). Токен — только
  `Authorization`; query/cookie не принимаются (нет кода, который читал
  бы их; cookie в app не используется — grep `Set-Cookie` по main.go: NONE).

### 3.5 ID parsing (overflow/negative/empty/suffix) — OK

- `raw == ""` → 400 (пустой id, `/api/notes/`); `Contains(raw, "/")` → 400
  (`/api/notes/1/extra` — TestNotesPrefixBoundary: note 1 не удалена);
  `Atoi` overflow (`999999999999999999999999`) → 400 без паники
  (TestDeleteInvalidID); отрицательный `-1` → 404 (map miss) — spec §5
  допускает 400/404, закреплено в тесте как `400|404`; `0` → 404
  (иды начинают с 1; подтверждено пробой). URL-нормализация `../`
  выполняется net/http до handler'а; любой под-сегмент → 400.

### 3.6 JSON body limits / decoder — OK (кроме CR-1)

- `http.MaxBytesReader(w, r.Body, 1<<20)` на всех трёх POST-эндпоинтах
  через `decodeJSON` (main.go:357–360): >1 MiB → 400 `invalid request
  body` (TestRegister/TestAddNote oversized — GREEN); обрезанный JSON
  (`{"username":`, `{`) → 400; неверный тип (`{"username":123}`,
  `{"text":123}`) → 400 (TestRegister/TestAddNote). Unknown fields
  игнорируются — по спеке (AT-04 s22b: `owner` в теле не влиятельно;
  подтверждено пробой: register с `owner` → 201, владелец только из сессии).
- Trailing-контент принимается → **CR-1 (low)**.

### 3.7 XSS — OK

- Все пользовательские данные в UI — только через `textContent`
  (web/app.js:333 `text.textContent = "#" + note.id + " " + note.text`,
  :346 `notesList.textContent = ""`, :410 `userNameEl.textContent`);
  `aria-label` — через `setAttribute`. Гrep `innerHTML|outerHTML|
  document.write|new Function|eval(` по `web/app.js`+`web/index.html` —
  **NONE**. Ряды только из `<template>` + `cloneNode(true)` (TestUISemantics:
  нет `<li>` вне template; «no phantom notes» закреплено).
- Заметка-HTML (`<script>`/`<img onerror>`) рендерится инертно (AT-07 s22b
  blocked). Токен в localStorage — поверхность только для XSS (residual R-3):
  sink на сегодня отсутствует.

### 3.8 Secret leakage — OK

- `User.Salt`/`PasswordHash`, `Session.*`, `Note.UserID` — `json:"-"`
  (main.go:53–70); наружу — только `registerResponse{id,username}`,
  `tokenResponse{token}`, `Note{id,text}` (325–336). `TestNoSecretLeak`
  (grep по всем телам на `password/hash/salt/user_id/expires_at`; `token`
  только в login-200) — GREEN. `writeJSON` при marshal-сбое пишет
  фиксированный `{"error":"internal error"}` (main.go:340–351), без
  stack/имён файлов (TestDeleteErrorEnvelope: нет `strconv/panic/
  goroutine/main.go`). Логирование секретов: в main.go нет log-вызовов,
  кроме `log.Fatal(ListenAndServe)` — пароли/токены не пишутся.

### 3.9 Error envelope / headers — OK

- Все ошибки — `{"error":"<literal>"}` + `Content-Type: application/json`
  (writeErr); 204 без тела и без CT (main.go:578; TestDeleteNote: тело
  пусто, CT пуст). 401 → `WWW-Authenticate: Bearer` (main.go:455, 519;
  TestAuthRequired на все 8 комбинаций method×id×заголовок). 405 →
  `Allow: POST` / `GET, POST` / `DELETE` / `GET, HEAD` (396, 415, 466, 549, 560).
  HTML/статики — `Cache-Control: no-store` (406, 425, 443). Литералы
  ошибок совпадают со spec §1.4 1:1 (сверено по contract-matrix).

### 3.10 Cookie / CORS / CSRF — OK

- Cookie-auth отсутствует (grep `Set-Cookie` — NONE); auth — только
  `Authorization: Bearer` (query/cookie не читаются — нет кода).
- Заголовков `Access-Control-*` нет (grep — NONE) → cross-origin
  заблокирован браузером (fail-safe); UI — same-origin, `fetch`
  `credentials: "same-origin"` (app.js:94). CSRF через cookie неприменим.
- Отсутствующие `X-Frame-Options`/CSP на stand — residual R-8 (prod-задача).

### 3.11 Deploy — OK

- `Dockerfile`: `COPY web/ ./web/` + **явные** embed-паттерны
  `web/index.html web/app.js web/app.css` (main.go:24) — бинарь не
  содержит `web/e2e/`/`node_modules` (TestUISemantics: `webFS.ReadFile(
  "web/e2e/auth-notes.spec.js")` → error; GREEN). `.dockerignore`
  исключает `web/e2e/`, `web/node_modules/`, `node_modules/`,
  `package-lock.json` из контекста. Тестовые `.go`-файлы в build-stage
  (`COPY *.go ./`) не попадают в runtime-образ (alpine + только
  `/notebook`) — не дефект.
- `e2e-preview.sh` fail-close: нет `E2E_BASE_URL` → exit 2; нет node/npm →
  fail (не skip); нет playwright → `npm install` (fail на ошибке);
  нет chromium → `playwright install chromium` (fail); `playwright test`
  падение → fail. API-smoke (2.1–2.10): 401 до method/id, 201/409,
  200-token ≥32, A/B-изоляция (B не видит idA и получает `[]`), чужой
  DELETE → 404, свой → 204/404/400. `E2E_API_ONLY=1` — осознанный
  ранний exit до Playwright (integration-gate s20a; Playwright на s20c) —
  документировано в шапке скрипта. **CR-5** — hygiene-следствие npm
  install в корне.

### 3.12 Tests — OK (кроме ограничений среды)

- 24 test-func, все GREEN (`go test -count=1 ./...` 2.45s); реальный
  HTTP-транспорт через `httptest.Server` (INV-REAL-TRANSPORT); build-тегов
  `integration/e2e/manual` нет (INV-NO-SKIP-TAGS PASS, canary
  `sec-skip-tagged` валидна). Flakiness: TTL-тест на injected clock +
  atomic offset — детерминирован; уникальные username в e2e
  (`stamp+rand`, spec: independent order). Не закреплено тестами:
  500-путь (rand failure) — осознанно (spec §1.2); trailing-garbage
  (CR-1); lowercase-scheme (работает по EqualFold, теста нет — spec §3.3
  допускает case-insensitive). `go test -race` — не исполнялся в
  окружении s22c (нет cgo/C-компилятора) → R-9; статический разбор §3.1
  активных гонок не нашёл.
- Canary `CANARY-DELETE-STATUS` валидна: литерал `http.StatusNoContent`
  в успешной DELETE-ветке (main.go:578), обработчик в `main.go`,
  `TestDeleteNote` ассертит ровно 204.

## 4. Residual risks (open, не блокеры)

| ID | Sev | Summary |
|---|---|---|
| R-1 | low | Нет rate-limit/lockout/CAPTCHA на `/api/login`, `/api/register` (accepted dev-risk, OD-16; в prod — high) |
| R-2 | low | Нет server-side logout/revocation: клиентский logout чистит `localStorage`, серверная сессия живёт до TTL 24h (утерянный токен валиден до истечения) |
| R-3 | low/info | Токен в `localStorage` — поверхность XSS; sink сегодня отсутствует (§3.7), регрессия при будущем `innerHTML`/`eval` |
| R-4 | info | In-memory store, без персистентности (accepted dev-scope, spec §13) |
| R-5 | info | Нет квоты на число заметок/сессий; истёкшие сессии удаляются лениво только при предъявлении токена — map растёт до рестарта (dev) |
| R-6 | info | Username-existence oracle через register 201/409 (login анти-enumeration-защищён §3.2; register — осознанно) |
| R-7 | info | PBKDF2 210k итераций — нижний предел по NIST/OWASP-2023 (600k); перед prod перекалибровать (Argon2id) |
| R-8 | low | Нет `X-Frame-Options`/CSP на stand-образах (TLS-терминация на nginx-прокси; clickjacking-риск минимален для internal dev-инструмента) — prod-hardening |
| R-9 | info | `go test -race` не исполнялся в s22c-окружении (нет C-компилятора); статический разбор активных гонок — §3.1. Обязателен в CI (AC-20) |

## 5. Verdict

**`pass`** — open critical/high отсутствуют. Закрыты все high-векторы
s22b (cross-user GET, IDOR/DELETE, XSS, secret-leak) + новый adversarial-
проход по 12 классам (§3). 5 новых findings (2 low / 3 info) —
hardening/gigiena, не блокеры: CR-1 (trailing-JSON-контент),
CR-5 (gitignore для npm-артефактов e2e), CR-2/CR-3/CR-4 (mёртвый
индекс, латентный work-factor, trailing-slash-страницы).

**Ограничения.** (1) `-race` и Playwright-e2e не исполнялись в
окружении s22c (нет cgo/C-компилятора; e2e-evidence принят из s20c) —
см. R-9; (2) reviewer_session_id не заполняется reviewer'ом (нет
task_id) — team-lead заполнит при приёмке; (3) код/адаптеры/граф не
менялись — созданы только `code-review.md`/`code-review.json`;
коммиты не создавались (по ТЗ).

---

Nexus artifact: `f-v3-auth-notes/code-review.md` (s22c.adversarial_code_review, E4312).
Reviewer: независимый adversarial code review (НЕ автор, НЕ s22b; self-review не выполнялся).

## Re-review after s23/platform fix

- Preview `ea1e61f`, Playwright 1.64.1, E2E 7/7.
- Код не менялся после ревью; findings CR-1…CR-5 прежние (0 critical/high), proofs валидны.
