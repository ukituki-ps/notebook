# Intent brief — f-v3-auth-notes (s07.requirements_reconcile)

Короткая сверка «что просил человек ↔ что собираемся делать». Полная
построчная трассировка — [intent-trace.json](./intent-trace.json) (32/32 пункта
сырого запроса, все `verdict: match`). Источник — [feature-request.md](./feature-request.md)
(неизменяем), итоговый дизайн — [feature-brief.md](./feature-brief.md) (FINAL).

## Цель

Несколько человек пользуются «Записной книжкой» на одном dev-инстансе и не видят
чужих заметок. Регистрация/логин → непрозрачный bearer-токен → CRUD только своих
заметок; всё in-memory, рестарт = очистка. UI — статические HTML/JS/CSS без
фреймворков, same-origin к `/api/*`, 3 страницы: login, register, notes.

## Просил → делаем (32 пункта)

| # | Просил | Делаем | Ref |
|---|---|---|---|
| R01 | `POST /api/register` → 201 | форма → создание пользователя, 201 `{id,username}` | B1/OD-05 |
| R02 | `POST /api/login` → 200 `{token}`, 401 | верная пара → токен; неверная → 401 | B1/B4 |
| R03 | `GET /api/notes` — только свои | 200, `[]`, фильтр по `UserID` | B5/OD-01 |
| R04 | `POST /api/notes` — своя заметка | 201 `{id,text}`, владелец из токена | B5/OD-07 |
| R05 | `DELETE /api/notes/{id}` — только своя | 204; чужая/нет → 404 | B5/OD-01 |
| R06 | users/sessions/notes in-memory | один `Store` + mutex, без БД | B2 |
| R07 | пароль: соль + hash | PBKDF2-HMAC-SHA256, соль 16B, 210k | B3/OD-02 |
| R08 | bearer-токен | 32B `crypto/rand`, `Authorization: Bearer` | B4/OD-03 |
| R09 | A не видит/не удаляет B | owner-scoped `List`/`Delete` | B5/OD-01 |
| R10 | без авторизации — 401 | auth раньше method/id/body | B4/B5 |
| R11 | без утечки паролей/хэшей | `json:"-"`, нет логов кредов, тест тела | B3/B6 |
| R12 | данные живут в процессе | рестарт = очистка, принято для dev | B2 |
| R13 | статическая страница | статические HTML, без SSR/сборки | B7/OD-08 |
| R14 | регистрация | `/register` → `POST /api/register` → `/login` | B7 |
| R15 | логин | `/login` → `POST /api/login` → `/notes` | B7/OD-10 |
| R16 | список заметок | `/notes` ← `GET /api/notes` + empty state | B7 |
| R17 | добавление | форма → `POST /api/notes`, строка в DOM | B7 |
| R18 | удаление | Delete → `DELETE /api/notes/{id}` | B7 |
| R19 | токен в памяти/localStorage | `localStorage["notebook.token"]`, reload жив | B7/OD-10 |
| R20 | ошибки 401/400 показывать | inline `role=alert`; 401 → очистка + `/login` | B6/B7 |
| R21 | без React/Vue, HTML/JS/CSS или embed | чистый JS + `go:embed web/` | B7/OD-08 |
| R22 | не ломать path10 adapter | `stand_command`/`preview-deploy.sh` не меняем | B8 |
| R23 | обновить `path1.project.json` | `frontend_dir=web`, e2e-preview, `audit.mode=app`, `database=false`, `require_dsn=false` | B8 |
| R24 | `path1.ui.json: platform: web` | выставляем `web` | B8/OD-15 |
| R25 | UI-граф login/register/notes | `arch/structure/ui-pages/*.yaml` (без второго графа) | B9/OD-11 |
| R26 | Playwright + 7 сценариев | `web/e2e/auth-notes.spec.js`, E2E-1..7 | B8/B10 |
| R27 | s21 gate не скипать | актуализация графа по коду на s21 | B9/OD-15 |
| R28 | не prod/main/stage/push | только `dev/f-v3-auth-notes` | B8 |
| R29 | без s45/s46 и canary rollout | audit-canary допустим | B8 |
| R30 | не трогать E2495, lk-agena-v2, kh_pg, E1320 | новая v3-фича, чужое не меняем | B8 |
| R31 | без force/skip/waiver | гейты штатно | B9 |
| R32 | без direct-кода вне ORC | только артефакты шагов | B8 |

## Где домыслили / что добавили от себя

Эти пункты **не** входят в сырой запрос; они вынесены из `items[]` и требуют
подтверждения человеком на s08 (решения приняты по рекомендации s05/s06).

| ID | Добавили | Почему | OD |
|---|---|---|---|
| AN-01 | 409 на занятый username | в запросе код не задан | OD-06 |
| AN-02 | 405 + `Allow`; auth раньше метода | стабильный контракт, canary/оракулы | — |
| AN-03 | поле Confirm password | защита от опечатки, только клиент | — |
| AN-04 | строгая валидация 3–32 / ≥8 / 1–4096 | в запросе лишь «пустые/битые поля» | OD-07, OD-13 |
| AN-05 | TTL токена 24h fixed | TTL не задан | OD-03 |
| AN-06 | чужая заметка → 404, не 403 | анти-энумерация | OD-01 |
| AN-07 | единый JSON `{"error":...}` на все коды | стабильные литералы для тестов | — |
| AN-08 | `WWW-Authenticate: Bearer` на 401 | HTTP-семантика | — |
| AN-09 | тело 201 register = `{id,username}` | состав тела не задан | OD-05 |
| AN-10 | кнопка Logout только клиентская | logout-API в запросе нет | OD-04 |
| AN-11 | порядок заметок = порядок вставки | не менять контракт | OD-14 |
| AN-12 | лимит тела 1 MiB | защита от мусора | — |
| AN-13 | выбран `go:embed` | запрос допускает embed и файлы | OD-08 |
| AN-14 | переписать `main_test.go` под auth | старые тесты безавторизационные | — |
| AN-15 | empty/loading/submitting, `data-testid`, `aria-live` | нужны для E2E и UI-инвариантов | — |

Не добавляли: БД/DSN, refresh/sliding TTL, logout-API, password reset,
rate limiting/lockout (OD-16 — принятый риск dev), фреймворки/сборку,
multi-tenant роли. См. «Out of scope» в feature-brief.

## Прототипы

- **s03 wireframes** — [feature-brief.md](./feature-brief.md#ui-wireframes-s03):
  ASCII-схемы login/register/notes, состояния idle/submitting/error(400,401,409)/
  empty/list/loading, mobile <640px, потоки переходов.
- **s04 UI-граф** — `arch/structure/ui-pages/login.yaml`, `register.yaml`,
  `notes.yaml` (route/auth/nodes/states/api/transitions/a11y; на s21 —
  `status: implemented` по факту кода).

## Open questions для человека (s08)

Решения ниже **уже приняты по рекомендации** аналитики и заложены в дизайн;
человеку нужно подтвердить или переопределить. Ни один пункт не закрывается
молча.

1. **OD-01. DELETE чужой заметки: 404 или 403?** Принято 404 (анти-энумерация).
2. **OD-07/OD-13. Строгая валидация** (username `[A-Za-z0-9_-]{3,32}`, password
   ≥8, text 1–4096, trim, case-sensitive) — оставить или упростить до non-empty?
3. **OD-03. TTL токена 24h fixed** — приемлемо? Нужен ли refresh/sliding?
4. **OD-04. Нужен ли серверный logout** (`POST /api/logout`)? Принято: нет,
   только клиентская очистка localStorage.
5. **OD-08. Раздача UI: `go:embed` или файлы `web/` с диска?** Принято embed.
6. **OD-09/OD-11. 3 отдельных HTML vs SPA**, и формат графа
   (`ui-pages/*.yaml` vs `UI-GRAPH.yaml`). Принято: 3 HTML + `ui-pages/*`.
7. **OD-12. Playwright обязателен на стенде** (fail-close без браузеров) или
   опционален с curl-префлайтом? Принято: обязателен.
8. **OD-05/OD-06. Ответ register**: 201 `{id,username}` без auto-login; 409 на
   дубль username (enumeration через register принят для dev) — ок?

Второстепенные, не блокирующие: порядок заметок (OD-14, принят порядок
вставки), rate limiting (OD-16, вне scope), переписывание `main_test.go`
(AN-14).
