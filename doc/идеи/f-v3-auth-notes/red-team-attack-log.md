# Red-Team / Adversarial Attack Log — f-v3-auth-notes (E4312)

- **Шаг:** `s22b.red_team_audit`
- **Execution:** `E4312` · feature `f-v3-auth-notes`
- **Роль:** независимый red-team reviewer (НЕ автор кода, НЕ team-lead; self-review запрещён)
- **Repo:** `/workspace/projects/notebook` · ветка `dev/f-v3-auth-notes` @ `86040ae`
- **Preview:** `https://test2.nexus.ukituki.tech` · `build_ref=4fbfbb1` (UI/API идентичны `80478e4`), `/healthz` 200, unauth `GET /api/notes` 401
- **Change class:** security · `feature_profile=full` · platform `web`

> **Метод.** Stic analysis + исполненное доказательство: (1) полный проход по коду
> (`main.go`, `main_test.go`, `web/index.html`, `web/app.js`, `web/app.css`,
> `web_ui_test.go`); (2) спеки `spec/core.md` §1–§13, `spec/contract-matrix.md`,
> `invariants.json`, `fault-verdicts.json`, `scenarios.json`; (3) исполненные
> оракулы — `go build` + `go vet` + `go test -count=1 ./...` **GREEN** (23
> test-func, HTTP-транспорт через `httptest.Server`); `INV-NO-SKIP-TAGS` PASS;
> (4) s20c E2E **7/7** (screenshots E2E-1..7, per-run execution root); s20b
> API-smoke **GREEN** на test2.
>
> **Ограничение среды.** Живые curl-пробы на стенде не перепрогонялись на
> `:8080` (порт занят shared-службой; `main.go` хардкодит `:8080`). «Фактическое»
> поведение по коду/спекам/снятому smoke+E2E + HTTP-транспортным тестам; это
> разрешено TЗ (actual = по коду/спекам/сняттому smoke/E2E). `go test -race`
> в этом окружении не собрался (нет C-компилятора → cgo) — **не дефект кода,
> ограничение среды**; race-прогон обязателен в CI.

## Scope & Inputs

Прочитано и проверено: `main.go` (auth/session/PBKDF2/owner-scope/envelope),
`main_test.go` (23 security-негатива), `web/index.html` + `web/app.js` +
`web/app.css` (UI XSS/escaping, token storage), `spec/core.md`,
`spec/contract-matrix.md`, `invariants.json`, `fault-verdicts.json`,
`scenarios.json`, `path1.project.json` (audit.oracles/canaries), s20c proof
(7/7 E2E + screenshots E2E-1..7; API smoke GREEN).

Ключевые факты кода (доказательство для «actual»):
- `main.go:362` `bearerToken()` — токен читается **только** из `Authorization`,
  query/cookie игнорируются; `main.go:449` `requireAuth()` → при провале
  `WWW-Authenticate: Bearer` + `401 unauthorized`.
- `main.go:141` `Authenticate()` — неизвестный username выполняет
  **dummy-PBKDF2** (фикс. `dummySalt`, 210k итераций) → одинаковый 401.
- `main.go:194` `ListNotes` / `main.go:219` `DeleteNote` — owner-scope по
  `UserID`; чужая/нет → `false` → 404 (без 403/204).
- `main.go:340` `writeJSON` — при ошибке marshal → generic
  `{"error":"internal error"}`, **без stack/имён файлов**.
- `main.go:358` `decodeJSON` — `http.MaxBytesReader` **1 MiB** на
  register/login/POST-notes; превышение/битый JSON → 400.
- `web/app.js:333/346/410` — **все** пользовательские данные рендерятся через
  `textContent`; `web/app.js` **без** `innerHTML`/`outerHTML`/`document.write`/
  `eval`/`new Function` (grep: NONE). Токен — только `localStorage` +
  заголовок `Authorization`; в DOM не выводится.
- `main.go:406/425/443` — HTML/статики `Cache-Control: no-store`; **нет**
  заголовков `Access-Control-*` и `Set-Cookie` (grep: NONE) → без cookie-auth,
  cross-origin блокируется браузером.

## Attacks (15)

Каждый: `ID` · `вектор` · `шаги` · `ожидаемое` · `фактическое (evidence)` ·
`verdict` · `severity`.

### AT-01 — no-auth / malformed bearer → 401 без данных · `blocked` · low
- **Вектор:** доступ к `/api/notes*` без валидного bearer.
- **Шаги:** `GET/POST/PUT/DELETE /api/notes`, `GET/DELETE /api/notes/{id}` без
  заголовка; `Authorization: Basic …`; `Authorization: Bearer` (пусто);
  `Authorization: Bearer a b` (2 токена).
- **Ожидаемое:** `401 {"error":"unauthorized"}` + `WWW-Authenticate: Bearer`
  **до** method/id/body; данные не отдаются.
- **Factual:** `TestAuthRequired`, `TestAuthMethodOrder` (все verbs × id ×
  заголовки), `main.go:449/455` — `requireAuth` + `WWW-Authenticate`/401 раньше
  method/id/body. spec §1.3/§10, INV-AUTH-REQUIRED. **BLOCKED.**

### AT-02 — expired / forged token → 401 · `blocked` · low
- **Вектор:** истёкший TTL; подделанный/чужой/чуждый токен; токен в query/cookie.
- **Шаги:** `GET /api/notes` с токеном, `now() ≥ ExpiresAt`; с произвольным
  `Bearer <forged>`; `?token=` / cookie.
- **Ожидаемое:** 401 + ленивое удаление сессии; query/cookie игнорируются
  (токен только заголовок).
- **Factual:** `TestTokenExpiry` (24h → 401, `sessionCount()=0`, повтор → 401),
  `TestAuthRequired` (`not-a-real-token` → 401), `main.go:362` (только
  `Authorization`), spec §3.3/§3.4. **BLOCKED.**

### AT-03 — cross-user GET isolation (A↛B) · `blocked` · high
- **Вектор:** чтение чужих заметок через `GET /api/notes`.
- **Шаги:** A и B зарегистрированы, у каждого по заметке; `GET /api/notes`
  с токеном A; поиск id/B-текста в ответе A; у нового юзера → `[]`.
- **Ожидаемое:** только свои; чужие id/текст отсутствуют; пустой → `[]`
  (не `null`).
- **Factual:** `TestNotesIsolation`, `TestNotesLifecycle` (пустое → `[]`),
  `main.go:194` (фильтр `note.UserID==userID`), E2E-6 (B видит 0 note-item).
  spec §4, INV-USER-ISOLATION. **BLOCKED.**

### AT-04 — IDOR / cross-user & missing DELETE → 404 · `blocked` · high
- **Вектор:** удаление чужой/несуществующей заметки по последовательному id;
  инъекция `owner`-поля в теле.
- **Шаги:** B → `DELETE /api/notes/{id_A}`; `DELETE /api/notes/999` (нет);
  `POST /api/notes` с `{"text":"x","owner":A}` (чуждый владелец).
- **Ожидаемое:** 404 `not found` **одинаково** для чужой и несуществующей
  (существование не раскрывается); `owner`-поле в теле **игнорируется**,
  владелец только из сессии.
- **Factual:** `TestDeleteForeignNote`, `TestNotesIsolation` (B → 404, A остаётся),
  `TestDeleteMissing`, `main.go:219` (RLS-предикат), `noteRequest` = только
  `Text` (`main.go:321`). E2E-6 (`DELETE` чужой → 404). **BLOCKED.**

### AT-05 — injection: SQLi / JSON / wrong-type (in-mem, no SQL) · `blocked` · low
- **Вектор:** payload в `username`/`text`; битый/неверного-типа JSON.
- **Шаги:** `register/login` с `{"username":` (обрыв),
  `{"username":123}` (тип); `POST /api/notes` с `{`, `{"text":123}`,
  `"abc' OR 1=1--"`, `"</>"`, массив/объект в `text`.
- **Ожидаемое:** нет SQL (in-memory `Store`); JSON-декод — только в тип
  `credentials`/`noteRequest`; неверный тип/обрыв → `400 invalid request
  body`; extra-поля игнорируются; `text`-не-строка → 400.
- **Factual:** `TestRegister` (обрыв + `username:123` → 400), `TestAddNote`
  (`{`, `{"text":123}` → 400), `main.go:357` `json.Decode` в struct. spec
  §1.1/§1.4, `fault-verdicts` CONTRACT-ERROR-ENVELOPE. **BLOCKED.**

### AT-06 — Unicode / homoglyph username & text · `blocked` · low
- **Вектор:** не-ASCII и homoglyph в `username` (обход валидации); UTF-8 /
  длинные последовательности в `text`.
- **Шаги:** `register username="юзер"`, `"a b"`, `"é"`, 33 символа;
  `text` — кириллица/эмодзи/`%00`/CRLF до 4096 B.
- **Ожидаемое:** `username` строго `[A-Za-z0-9_-]{3,32}` ASCII → невалид →
  400 `invalid username`; `text` хранится дословно (1–4096 B, без trim),
  рендер в UI инертен (см. AT-07).
- **Factual:** `TestRegister` (`юзер`, `a b`, 33 → 400 `invalid username`),
  `main.go:286` `validUsername` (ASCII-белый список), `main.go:309` `validText`
  (byte-length, без char-restriction на `text`). **BLOCKED.**

### AT-07 — XSS: `<script>` / `<img onerror>` в note text · `blocked` · high
- **Вектор:** сохранённая заметка с разметкой/JS → исполнение в UI.
- **Шаги:** A: `POST /api/notes {"text":"<script>alert(1)</script>"}`,
  `"<img src=x onerror=alert(2)>"`, `"<a href=javascript:...>"`,
  `"{{constructor}}"`; B (или тот же A): `GET /api/notes`, рендер `note-item`.
- **Ожидаемое:** UI рендерит текст через `textContent`, **не** `innerHTML`;
  разметка отображается как литеральный текст, скрипт не исполняется;
  `<template id=note-item-template>` + `cloneNode(true)` без inline-markup.
- **Factual:** `web/app.js:333` `text.textContent = "#" + note.id + " " +
  note.text`; `renderNotes` `notesList.textContent=""` + `appendChild`
  (app.js:345-357); `grep` по `web/app.js` **NONE** `innerHTML`/`outerHTML`/
  `document.write`/`eval`/`new Function`; `web_ui_test.go` — нет фантомных
  `<li>` вне template, `cloneNode(true)` обязательны. E2E-3 (рендер `#id
  text`). **BLOCKED** (открытых sink нет; см. residual R-3).

### AT-08 — method confusion (collection & item) · `blocked` · low
- **Вектор:** неверные методы на `/api/notes` и `/api/notes/{id}`.
- **Шаги:** `PUT/PATCH/DELETE /api/notes`; `GET/POST/PUT/PATCH
  /api/notes/{id}`.
- **Ожидаемое:** коллекция `Allow: GET, POST` → 405; item `Allow: DELETE` →
  405; тело `{"error":"method not allowed"}`.
- **Factual:** `TestNotesMethodNotAllowed`, `TestAuthMethodOrder`
  (`main.go:548/559`), spec §1.3/§10, INV-VERB-REJECT. **BLOCKED.**

### AT-09 — path confusion / traversal · `blocked` · low
- **Вектор:** деформация пути id: префикс, двойной слаг, overflow, `../`.
- **Шаги:** `DELETE /api/notes/` (пусто); `/api/notes/{id}/extra`;
  `/api/notes/abc`; `/api/notes/-1`; `/api/notes/999999999999999999999999`;
  `/api/notes/../../etc/passwd` (URL-нормализация); `GET /api/unknown`.
- **Ожидаемое:** пусто/нечисл./overflow → 400 `invalid id`; отрицательный →
  404 (map miss); под-сегменты (содержат `/`) → 400; unknown `/api/*` → 404
  JSON; `net/http` нормализует `../`, note не затрагивается.
- **Factual:** `TestNotesPrefixBoundary` (`/api/notes/`→400, `/{id}/extra`→400,
  note 1 не удалена), `TestDeleteInvalidID` (`abc`/``/overflow→400, `-1`→404),
  `TestUnknownAPINotFound` (`/api/unknown`→404 JSON), `main.go:564-573`
  (`TrimPrefix`+`Contains(raw,"/")`+`Atoi`). spec §5, INV-PREFIX-BOUNDARY.
  **BLOCKED.**

### AT-10 — body limits: >1 MiB / empty / very-long text → 400, без OOM · `blocked` · low
- **Вектор:** превышение лимитов тела/поля (DoS/OOM).
- **Шаги:** `register`/`login`/`POST notes` с телом >1 MiB; `text=""`,
  `"   "`, `"\n\t"`; `text` = 4097 B; `text` = ровно 4096 B.
- **Ожидаемое:** >1 MiB → `400 invalid request body` (`MaxBytesReader`);
  пустой/whitespace/>4096 → `400 text required`; 4096 B — допустимо (201);
  память ограничена (нет OOM).
- **Factual:** `TestRegister` (oversized >1 MiB → 400), `TestAddNote`
  (`""`/`"   "`/`"\n\t"`/`4097B` → 400 `text required`; `4096B` → 201;
  oversized body → 400), `main.go:28/32` (`maxBodyBytes=1<<20`,
  `maxTextBytes=4096`). spec §1.1/§1.4. **BLOCKED.**

### AT-11 — duplicate username → 409 (case-sensitive) · `blocked` · low
- **Вектор:** повторная регистрация; обход регистром.
- **Шаги:** `register "alice"` → 201; ещё раз `"alice"` → ?; `"Alice"` → ?.
- **Ожидаемое:** повторный точный username → `409 username taken`, вторая
  запись не создаётся; `Alice` ≠ `alice` (case-sensitive) → 201.
- **Factual:** `TestRegister` (дубль → 409, `Alice` → 201), `main.go:110-118`
  (`regMu` держит check-hash-insert, без TOCTOU-дубля), `main.go:114`
  `usersByName[username]` — точный (case-sensitive) ключ. spec §5. **BLOCKED.**

### AT-12 — secret leakage: password/hash/salt/token в JSON/DOM/логах · `blocked` · high
- **Вектор:** утечка секретов в ответах, DOM, логгах.
- **Шаги:** `register` 201, `login` 200, `POST/GET /api/notes`, 401,
  failed-login; grep всех тел на `password`/`hash`/`salt`/`user_id`/
  `expires_at`; проверка DOM на вывод токена; проверка логов.
- **Ожидаемое:** `User.Salt/PasswordHash` — `json:"-"`; ответ register =
  `{id,username}`, login = `{token}`, note = `{id,text}` (`UserID` `json:"-"`);
  `token` **только** в login-200; DOM не выводит токен; логи без паролей/
  токенов/hash.
- **Factual:** `TestNoSecretLeak`, `TestRegister` (нет `password/hash/salt`),
  `main.go:56/57/68` (`json:"-"`), `main.go:325-336` (response-структуры
  без секретов), `web/app.js:89` (токен → только `Authorization` header;
  в DOM `#id text`/username, токен не пишется). `fault-verdicts`
  SEC-ERROR-LEAK covered. **BLOCKED.**

### AT-13 — timing / user enumeration: dummy-PBKDF2; residual rate-limit · `risk` · low
- **Вектор:** timing-oracle + отсутствие rate-limit/lockout на login/register.
- **Шаги:** `login` неверный пароль vs несуществующий username — сравнение
  задержки и тела; сериальные brute-force / mass-register без ограничения.
- **Ожидаемое:** login unknown-user выполняет dummy-PBKDF2 (фикс. соль,
  210k) → **идентичный** 401 + `WWW-Authenticate` (анти-enumeration по
  времени/ответу).
- **Factual:** `TestLoginInvalid` (`wrongPassword.body == unknownUser.body`,
  WWW-Authenticate `Bearer`), `main.go:153-156` (dummy-PBKDF2), spec §3.1.
  **Timing-part BLOCKED.** Residual: **rate limiting/lockout/CAPTCHA
  отсутствуют** (accepted dev risk, OD-16, spec §13) → `risk` `low`.

### AT-14 — CSRF / CORS: same-origin + bearer, no CORS; localStorage token · `blocked` · low
- **Вектор:** cross-origin вызов API; CSRF через cookie; кража токена из
  storage.
- **Шаги:** `fetch /api/notes` с другого origin; cookie-auth (нет);
  чтение `localStorage["notebook.token"]` злоумышленником.
- **Ожидаемое:** auth — только `Authorization: Bearer` (не cookie) → CSRF
  неприменим; **нет** `Access-Control-*` → cross-origin заблокирован браузером
  (fail-safe); `fetch credentials:"same-origin"`. Токен в localStorage =
  поверхность **только для XSS** (AT-07 закрыт → не эксплойтируется сегодня).
- **Factual:** `grep` по `web/` + `main.go` **NONE** `Access-Control`/
  `Set-Cookie`; `web/app.js:88/94` (`Authorization` + `credentials:
  "same-origin"`), `web/app.js:174/175` (`localStorage`); spec §6.1
  (same-origin, без CORS/отдельного frontend). **BLOCKED** (residual R-3).

### AT-15 — headers: WWW-Authenticate/Allow/Cache-Control; no stack traces · `blocked` · info
- **Вектор:** отсутствие обязательных заголовков; утечка internals в
  error-envelope.
- **Шаги:** любой 401 (WWW-Authenticate?), 405 (Allow?), HTML-страницы
  (Cache-Control?), 500/marshal-fail (нет stack/имён файлов?).
- **Ожидаемое:** 401 → `WWW-Authenticate: Bearer`; 405 → `Allow: GET, POST` /
  `DELETE` / `POST` / `GET, HEAD`; HTML → `Cache-Control: no-store`; все
  ошибки `{"error":"<literal>"}` **без stack/файлов/внутренних деталей**.
- **Factual:** `main.go:455/519` (WWW-Authenticate), `main.go:396/415/466/
  502/549/560` (Allow), `main.go:406/425/443` (no-store), `TestAuthRequired`
  / `TestNotesMethodNotAllowed` (заголовки), `TestDeleteErrorEnvelope`
  (нет `strconv/panic/goroutine/main.go`), `main.go:344` (marshal-fail →
  `"internal error"`). spec §1.1/§1.4, AC-10. **BLOCKED.**

## Summary

| ID | Вектор | Verdict | Severity |
|---|---|---|---|
| AT-01 | no-auth / malformed bearer → 401 | blocked | low |
| AT-02 | expired / forged token → 401 | blocked | low |
| AT-03 | cross-user GET isolation | blocked | high |
| AT-04 | IDOR cross-user / missing DELETE → 404 | blocked | high |
| AT-05 | SQLi / JSON / wrong-type injection | blocked | low |
| AT-06 | Unicode / homoglyph username & text | blocked | low |
| AT-07 | XSS `<script>`/`<img onerror>` в note text | blocked | high |
| AT-08 | method confusion (collection & item) | blocked | low |
| AT-09 | path confusion / traversal | blocked | low |
| AT-10 | body limits >1 MiB / empty / >4096 | blocked | low |
| AT-11 | duplicate username → 409 | blocked | low |
| AT-12 | secret leakage password/hash/salt/token | blocked | high |
| AT-13 | timing/enumeration + residual rate-limit | risk | low |
| AT-14 | CSRF / CORS + localStorage token | blocked | low |
| AT-15 | headers WWW-Auth/Allow/Cache-Control, no stack | blocked | info |

**Итог:** 15 атак · **14 blocked / 1 risk** (AT-13 residual rate-limit) ·
**open critical = 0, open high = 0**.

## Verdict

**Red-team verdict: `pass`** (pass = нет open critical/high).

Все 4 high-вектора (cross-user GET, IDOR/DELETE, XSS, secret-leak) закрыты
кодом и подтверждены тестами/E2E. Единственный `risk` — остаточное отсутствие
rate-limit/lockout (accepted dev risk, OD-16) — не повышает критерий pass.

## Residual risks (open, accepted / не блокеры)

- **R-1 (low):** нет rate-limiting / account lockout / CAPTCHA на
  `/api/login` и `/api/register` → brute-force и mass-register возможны.
  Accepted dev risk (OD-16, spec §13). В prod — **high** (см. рекомендации).
- **R-2 (low):** нет server-side logout / отзыва токена; `POST /api/logout`
  отсутствует; клиентский logout только чистит `localStorage`, серверная
  сессия живёт до TTL 24h. Утрённый токен остаётся валидным до истечения.
- **R-3 (low/info):** bearer-токен в `localStorage` — доступен любому XSS;
  **сегодня не эксплойтируется**, т.к. в UI нет DOM-injection sink (AT-07
  `textContent`). Станется уязвимым при будущем `innerHTML`/`eval`-изменении.
- **R-4 (info):** in-memory `Store` без персистентности: рестарт очищает
  users/sessions/notes (accepted dev scope, spec §13).
- **R-5 (info):** нет квоты на число заметок/сессий на пользователя
  (dev, без лимита).
- **R-6 (info):** username-existence oracle через `register` 409-vs-201
  (login анти-enumeration-защищён; register — осознанный).
- **R-7 (info):** PBKDF2-HMAC-SHA256 @ 210k итераций — приемлемо, но нижний
  предел по NIST-2023; перед prod перекалибровать.

## Recommendations (без изменения кода этого шага)

1. **Rate-limit / lockout / CAPTCHA** перед любой non-dev эксплуатацией
   (зафиксировать как prod-gate, OD-16); сейчас — accepted dev risk.
2. **UI XSS regression test:** добавить в s20c/E2E негативный сценарий —
   crafted `note.text` (`<script>`/`<img onerror>`) рендерится инертен
   (ассерт textContent, без выполнения). Закрепит R-3 как regression-инвариант.
3. **Secret storage:** перед prod — `httpOnly`+`Secure`+`SameSite` cookie или
   in-memory server-side с `POST /api/logout` + revocation list (закрывает
   R-2/R-3).
4. **Hashing:** перед prod — Argon2id / PBKDF2 ≥ 600k итераций (R-7).
5. **CI-обязательность `go test -race`:** в этом окружении cgo/`gcc` отсутсвует
   → race-прогон не исполнялся; гарантировать в CI (AC-20). Не дефект кода,
   ограничение среды.
6. **TLS-верификация на edge стенда:** бинарь слушает plain `:8080` и полагается
   на stand/proxy (HSTS/TLS-termination проверить на gate s24).

## Явные по scope (обязательно)

- **Canary rollout / prod НЕ запускались:** `s45.push_primary`,
  `s46.post_deploy_verify`, push в `main`/`stage`/primary — **не выполнялись**
  (out of scope, spec §13; срез s22b до s24).
- **Тесты только на `test2`** (preview stand `4fbfbb1`/`80478e4`):
  `go test -count=1 ./...` GREEN + s20b API-smoke GREEN + s20c E2E 7/7 на
  `test2`; других стендов/среда не задействовались.
- **E1320 не тронут:** аудит строго read-only по ветке `dev/f-v3-auth-notes`
  `@ 86040ae` (E4312); мутации/привязки к другому исполнению E1320 не
  выполнялись; код/адаптеры/граф не менялись (создан только этот `.md`).

---

Nexus artifact: `f-v3-auth-notes/red-team-attack-log.md` (s22b.red_team_audit,
E4312). Reviewer: independent red-team (self-review не выполнялся).

## Re-audit after s23/platform fix

- Preview `ea1e61f` (Playwright 1.64.1, E2E 7/7).
- Attack surface/код не менялись; verdict pass, 0 critical/high, residual risks прежние.
