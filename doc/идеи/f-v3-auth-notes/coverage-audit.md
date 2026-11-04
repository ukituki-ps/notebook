# f-v3-auth-notes — аудит покрытия (s17)

- Execution: **E4312**, шаг **s17.coverage_audit**
- Repo: `/workspace/projects/notebook`, ветка `dev/f-v3-auth-notes`
- Change class: **security**; `feature_profile=full`; `path1.ui.json.platform=web`
- Вход: `spec/core.md`, `spec/contract-matrix.md`, `feature-brief.md`,
  `invariants.json`, `change-definition.md`, `plan.md`, `T0001..T0009/brief.md`,
  `arch/structure/ui-pages/{login,register,notes}.yaml`, `main.go`/`main_test.go`
  (база `8e0e949`).
- Каталог отказов `audit/fault-catalog/*` на eval-хосте локально недоступен;
  вердикты вынесены по 20 id из задания — см. `fault-verdicts.json`.
- Границы шага: только аудит покрытия. Код, тесты, спеки, план и брифы не
  меняются; реализация — s20.

## Вердикт

**pass**

- gaps: **0** (major/critical: 0, minor: 0, info: 0).
- У каждого пункта контракта, acceptance-критерия и инварианта назначен
  исполнимый оракул (Go-тест, grep-команда или Playwright-сценарий).
- Каталог отказов: **15 covered / 5 na / 0 gap**; все `na` имеют обоснование.

## Покрытие

- **total: 31**
- **resolved: 31**
- Метрика `total` = число строк `spec/contract-matrix.md` (endpoint × method ×
  status/envelope). У каждой строки есть test-оракул; неразрешённых — 0.
- Дополнительно (не входят в total, чтобы не дублировать contract-строки):
  acceptance criteria **20/20**, инварианты **15/15**, E2E-сценарии **7/7**
  (оракул назначен; фактический прогон — s20c).

## Таблица: пункт контракта → оракул

Источник: `spec/contract-matrix.md` (31 строка).

| # | Endpoint × status / envelope | Оракул (test/E2E) |
|---|---|---|
| 1 | `POST /api/register` 201 `{id,username}` | `TestRegister` |
| 2 | `POST /api/register` 400 `username and password required` | `TestRegister` |
| 3 | `POST /api/register` 400 `invalid username` | `TestRegister` |
| 4 | `POST /api/register` 400 `invalid password` | `TestRegister` |
| 5 | `POST /api/register` 400 `invalid request body` | `TestRegister` |
| 6 | `POST /api/register` 409 `username taken` | `TestRegister` |
| 7 | `POST /api/register` 405 + `Allow: POST` | `TestRegister` |
| 8 | `POST /api/login` 200 `{token}` | `TestLogin` |
| 9 | `POST /api/login` 400 `username and password required` | `TestLogin` |
| 10 | `POST /api/login` 400 `invalid request body` | `TestLogin` |
| 11 | `POST /api/login` 401 + `WWW-Authenticate: Bearer` | `TestLoginInvalid` |
| 12 | `POST /api/login` 405 + `Allow: POST` | `TestLogin` |
| 13 | `GET /api/notes` 200 `[{id,text}]`, `[]` при пустом | `TestNotesLifecycle` |
| 14 | `GET /api/notes` 401 (нет/битый токен) | `TestAuthRequired` |
| 15 | `GET /api/notes` 401 (истёкший токен) | `TestTokenExpiry` |
| 16 | `PUT /api/notes` 405 + `Allow: GET, POST` | `TestNotesMethodNotAllowed` |
| 17 | `DELETE /api/notes` 405 + `Allow: GET, POST` | `TestNotesMethodNotAllowed` |
| 18 | `POST /api/notes` 201 `{id,text}` | `TestAddNote` |
| 19 | `POST /api/notes` 400 `text required` | `TestAddNote` |
| 20 | `POST /api/notes` 400 `invalid request body` | `TestAddNote` |
| 21 | `POST /api/notes` 401 | `TestAuthRequired` |
| 22 | `POST /api/notes` 405 + `Allow: GET, POST` | `TestNotesMethodNotAllowed` |
| 23 | `DELETE /api/notes/{id}` 204 без тела | `TestDeleteNote` |
| 24 | `DELETE /api/notes/{id}` 400 `invalid id` | `TestDeleteInvalidID` |
| 25 | `DELETE /api/notes/{id}` 401 | `TestAuthRequired` |
| 26 | `DELETE /api/notes/{id}` 404 `not found` (нет заметки) | `TestDeleteMissing` |
| 27 | `DELETE /api/notes/{id}` 404 `not found` (чужая) | `TestDeleteForeignNote` |
| 28 | `GET /api/notes/{id}` 405 + `Allow: DELETE` | `TestNotesMethodNotAllowed` |
| 29 | `POST /api/notes/{id}` 405 + `Allow: DELETE` | `TestNotesMethodNotAllowed` |
| 30 | `PUT /api/notes/{id}` 405 + `Allow: DELETE` | `TestNotesMethodNotAllowed` |
| 31 | `PATCH /api/notes/{id}` 405 + `Allow: DELETE` | `TestNotesMethodNotAllowed` |

## Acceptance criteria → оракул (20/20)

| AC | Проверка | Оракул |
|---|---|---|
| AC-01 | register 201, ровно `{id,username}`, JSON | `TestRegister` |
| AC-02 | register 400: пустые/битые/невалидные/`>1 MiB` | `TestRegister` |
| AC-03 | register 409, второй записи нет | `TestRegister` |
| AC-04 | login 200, токен 43 символа, TTL 24h | `TestLogin`, `TestTokenExpiry` |
| AC-05 | login 401 одинаков для нет/неверного пользователя | `TestLoginInvalid` |
| AC-06 | `/api/notes*` без/битый/истёкший → 401 до 405/400 | `TestAuthRequired`, `TestAuthMethodOrder` |
| AC-07 | owner-scoped GET, `[]` не `null` | `TestNotesIsolation`, `TestNotesLifecycle` |
| AC-08 | чужой/несуществующий DELETE → 404 | `TestDeleteForeignNote`, `TestDeleteMissing` |
| AC-09 | свой DELETE → 204, повторный → 404 | `TestDeleteNote` |
| AC-10 | единый envelope, `Allow`/`WWW-Authenticate` | `TestDeleteErrorEnvelope`, `TestNotesMethodNotAllowed` |
| AC-11 | нет `password`/`hash`/`salt`/`user_id`; token только login 200 | `TestNoSecretLeak` |
| AC-12 | PBKDF2 16B/210k/32B, constant-time, dummy | `TestPasswordHashed` |
| AC-13 | TTL 24h, lazy expiry, без sliding | `TestTokenExpiry` |
| AC-14 | username 3–32/trim/case-sensitive; password 8–128; text 1–4096 | `TestRegister`, `TestAddNote` |
| AC-15 | wire-ключи ровно `id`/`text`/`token`/`username`/`error` | `TestWireContract` |
| AC-16 | `/login`,`/register`,`/notes`; `/`→302; no-store; embed | `TestUISemantics`, E2E-1..3 |
| AC-17 | `data-testid`, `role=alert`, `aria-live=polite`, labels | `TestUISemantics` |
| AC-18 | loading/empty/list/submitting/delete-pending; 401→очистка+replace | `TestUISemantics`, E2E-2/4/5 |
| AC-19 | нет фантомных заметок; список = `GET /api/notes` | `TestUISemantics`, E2E-4 |
| AC-20 | canary `http.StatusNoContent`, HTTP-транспорт, нет build-тегов, race/vet | grep canary, `TestHTTPTransport`, `INV-NO-SKIP-TAGS`, `go test -race` |

## Инварианты → оракул (15/15)

| Invariant | Статус | Оракул |
|---|---|---|
| `INV-AUTH-REQUIRED` | active | `TestAuthRequired`, `TestLoginInvalid` |
| `INV-USER-ISOLATION` | active | `TestNotesIsolation`, `TestDeleteForeignNote` |
| `INV-NO-SECRET-LEAK` | active | `TestNoSecretLeak` |
| `INV-PASSWORD-HASHED` | active | `TestPasswordHashed` |
| `INV-VERB-REJECT` | active | `TestNotesMethodNotAllowed`, `TestAuthMethodOrder` |
| `INV-PREFIX-BOUNDARY` | active | `TestDeleteInvalidID`, `TestNotesPrefixBoundary` |
| `INV-WIRE-CASING` | active | `TestWireContract` |
| `INV-REAL-TRANSPORT` | active | `TestHTTPTransport` |
| `INV-NO-SKIP-TAGS` | active | `sh -c "! grep -R -E '^//go:build.*(integration\|e2e\|manual)' --include='*_test.go' ."` |
| `INV-UI-TRUTH` | active | `TestUISemantics`, E2E-4 |
| `INV-UI-LABEL` | active | `TestUISemantics` |
| `INV-UI-A11Y-NAME` | active | `TestUISemantics` |
| `INV-UI-EMPTY-STATE` | active | `TestUISemantics`, E2E-5 |
| `INV-UI-ORACLE` | proposed → s22a | `ui-audit.json` items[].oracle/evidence |
| `INV-UI-E2E-PREVIEW` | proposed → s20c/s21 | `e2e-preview.sh` + Playwright 7/7 + screenshots |

## E2E → оракул (7/7)

| ID | Сценарий | Оракул |
|---|---|---|
| E2E-1 | Регистрация → 201 → `/login` с prefill | `web/e2e/auth-notes.spec.js`, `e2e-preview.sh` |
| E2E-2 | Логин, `notebook.token` непустой → `/notes` | Playwright + API-smoke |
| E2E-3 | Создание заметки, строка в `notes-list` | Playwright + API-smoke |
| E2E-4 | Reload `/notes` сохраняет сессию и данные | Playwright |
| E2E-5 | Удаление → 204, строка убрана, `notes-empty` | Playwright |
| E2E-6 | A/B изоляция, чужой DELETE → 404 | Playwright (два context) + API-smoke |
| E2E-7 | Неавторизованный `GET /api/notes` → 401 | Playwright APIRequestContext + `e2e-preview.sh` |

## Gaps

Нет. Блокирующих, major, minor и info-gap не выявлено.

Замечания (не gaps, плановые состояния):

1. Реализация и Go-тесты отсутствуют на s17 по процессу: аудит подтверждает
   **назначение оракулов** спеке/брифам, а не их исполнение. Исполнение — s20,
   прогон — s20a/s20c.
2. `INV-UI-ORACLE` (`proposed`) закрывается на s22a через `ui-audit.json`;
   `INV-UI-E2E-PREVIEW` (`proposed`) — на s20c и становится `active` к s21.
   Это штатная последовательность, а не пробел покрытия.
3. `path1.project.json.audit.oracles` сейчас содержит три базовых оракула;
   расширение `SEC-AUTH-REQUIRED`/`SEC-USER-ISOLATION` входит в T0009 (s20),
   имена существующих оракулов не ломаются.
4. Каталог `audit/fault-catalog/*` локально не найден; использован выданный
   список из 20 id. При появлении каталога на eval-хосте набор id сверяется
   гейтом `gate-catalog-invariants`.

## Вывод

Спека `f-v3-auth-notes` покрыта оракулами полностью: 31/31 строк контракта,
20/20 acceptance criteria, 15/15 инвариантов, 7/7 E2E-сценариев. Все 20
отказов каталога получили вердикт: 15 `covered` с привязкой к
инварианту/тесту или спеке, 5 `na` с обоснованием (даты, пагинация, derived
descriptions в фиче отсутствуют). Вердикт — **pass**, gaps — **0**; s20 может
открываться.
