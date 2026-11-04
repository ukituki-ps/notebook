# M01 — brief

- Веха: **M01** «v3 auth+notes: backend+UI+preview test2»
- Feature: `f-v3-auth-notes`, execution **E4312**, шаг **s15.brief_milestone**
- Репо/ветка: `/workspace/projects/notebook`, `dev/f-v3-auth-notes`, база `8e0e949`
- Change class: **security**; `feature_profile=full`; `path1.ui.json.platform=web`; стенд **test2**
- Нормативные входы: [feature-brief.md](../feature-brief.md),
  [change-definition.md](../change-definition.md), [plan.md](../plan.md),
  [spec/core.md](../spec/core.md), [spec/contract-matrix.md](../spec/contract-matrix.md),
  [invariants.json](../invariants.json)

## 1. Цель вехи

Дать нескольким пользователям работать с «Записной книжкой» на одном dev-инстансе
без доступа к чужим заметкам: register/login → непрозрачный bearer-токен →
owner-scoped CRUD заметок; статический web UI поверх same-origin `/api/*`;
раздача через `go:embed`; preview-прогон на test2. Всё in-memory, рестарт = очистка.

**Границы.** Входит: backend auth+notes (`main.go`, `main_test.go`), web UI
(`web/*`, `web_ui_test.go`), сборка образа с `web/`, preview deploy на **test2**
и E2E (auth-smoke + Playwright). **Не входит:** БД/персистентность/DSN/миграции,
prod-деплой, canary rollout, `s45.push_primary`/`s46.post_deploy_verify`, push в
`main`/`stage`/primary; `POST /api/logout`, refresh/sliding TTL, password
reset/change; rate limiting/lockout/CAPTCHA; фреймворки/сборщики/npm-рантайм;
multi-tenant роли/admin/sharing; второй UI-граф; force/skip/waiver.

## 2. Входы → выходы

| Уже есть (вход) | Должно появиться (выход вехи) |
|---|---|
| `doc/идеи/f-v3-auth-notes/{feature-brief,change-definition}.md`, `plan.md`, `spec/{core,contract-matrix}.md`, `invariants.json` | `main.go` — Store users/sessions/notes, PBKDF2, 5 эндпоинтов, auth-guard, JSON-envelope, embed/static |
| `arch/structure/ui-pages/{login,register,notes}.yaml` (planned) | `main_test.go` — миграция под auth + security-негативы (имена canary сохранены) |
| `path1.project.json`, `path1.ui.json` (целевые поля) | `web/index.html`, `web/app.js`, `web/app.css` |
| `deploy/Dockerfile`, `deploy/path1/e2e-preview.sh`, `deploy/path1/preview-deploy.sh` (base) | `web_ui_test.go` — `TestUISemantics` (embed/селекторы/a11y/empty) |
| `invariants.json` (13 active + 2 proposed) | `web/e2e/auth-notes.spec.js`, `playwright.config.js` — 7 сценариев |
| | `deploy/Dockerfile` (`COPY web/` до `go build`, `COPY *.go`), `.dockerignore` |
| | `deploy/path1/e2e-preview.sh` — auth-smoke + Playwright; adapter/oracles |
| | `preview-deploy.json` (s20b, из фактического деплоя), evidence E2E (s20c) |

## 3. Units M01

| Unit ID | Domain | SDE | Change class | Files |
|---|---|---|---|---|
| `notebook-auth-api` | `notebook-api` | `sde-backend` | `security` | `main.go`, `main_test.go` |
| `notebook-web-ui` | `notebook-web` | `sde-frontend` | `security` | `web/index.html`, `web/app.js`, `web/app.css`, `web/e2e/auth-notes.spec.js`, `playwright.config.js`, `web_ui_test.go`, `main.go` (только embed+static) |
| `notebook-deploy-e2e` | `notebook-deploy` | `sde-infra` | `security` | `deploy/Dockerfile`, `deploy/path1/e2e-preview.sh`, `path1.project.json`, `path1.ui.json`, `.dockerignore` |

- U01 — единый backend-unit (backend живёт в одном `main.go`; дробить по
  эндпоинтам параллельно нельзя — конфликт файла).
- U02 — три экрана в одном `index.html` + одном `app.js`; `main.go`-хук узкий
  (embed/static) и вливается после U01.
- U03 — Go-код не трогает; runtime-проверки после merge U01+U02.

## 4. Acceptance вехи

- [ ] `go build ./...`, `go vet ./...`, `go test -race ./...` — зелёные; без
      build-тегов `integration/e2e/manual`; без новых зависимостей `go.mod`.
- [ ] Все **15 INV-\*** из `invariants.json` имеют оракул: 13 `active` —
      зелёные Go-тесты; `INV-UI-ORACLE` → `ui-audit.json` (s22a),
      `INV-UI-E2E-PREVIEW` → стенд + screenshots (s20c).
- [ ] **7 Playwright** сценариев (`chromium`, `baseURL` из `E2E_BASE_URL`)
      зелёные на стенде: register, login+token, create, reload, delete,
      A/B isolation, 401.
- [ ] Preview **test2**: `/healthz` — nginx JSON (`build_ref`, `commit` 40hex);
      auth-smoke (401 → register/login A/B → authed GET/POST/DELETE → isolation);
      `preview-deploy.json.sha` = выкаченный ref, не локальный HEAD.
- [ ] s21: `arch/structure/ui-pages/*.yaml` актуализированы по коду
      (`status: implemented`, selectors/routes/api_calls); второго графа нет.
- [ ] s22a: `ui-audit.json` (блоки A–L, `open_critical_high=0`, `oracle`+`evidence`
      у каждого item); adapter в целевом состоянии.
- [ ] Canary **`CANARY-DELETE-STATUS`** валиден: DELETE-обработчик и литерал
      `http.StatusNoContent` остаются в `main.go` (`grep` непусто; seed
      `sed s/http.StatusNoContent/http.StatusOK/` ломает `TestDeleteNote`).
- [ ] **E1320 не трогается** — ни файлов, ни конфигов, ни артефактов исполнения.

## 5. Порядок merge (s20a) и прогоны

1. **U01 (`notebook-auth-api`)** → `go test -race ./...`, `go vet ./...`, canary-grep.
2. **U02 (`notebook-web-ui`)** → разрешить `main.go`: сохранить API/Store U01,
   добавить `//go:embed` + static handler; при конфликте embed **после** API.
3. **U03 (`notebook-deploy-e2e`)** → Dockerfile/`.dockerignore`/e2e-скрипт/adapter.
4. Сводный `artifacts/units/integration-report.md` + contract parity (5 эндпоинтов,
   envelope, 401-before-method).
5. s20b — `docker build` + `preview-deploy.sh test2 <ref>` (скрипт **не менять**)
   → `preview-deploy.json`. s20c — `e2e-preview.sh`: health → auth-smoke →
   Playwright 7/7, отсутствие браузеров = fail-close (не skip).

## 6. Риски

| Риск | Митигация | Шаг |
|---|---|---|
| Конфликт `main.go` U01/U02 | U02 — только embed/static; merge после U01; повторный `go test -race` | s20a |
| `go:embed` до появления `web/` | `web/*` и embed в одном unit; `COPY web/` до `go build` | s20a/s20b |
| Dockerfile без `web/`/`*.go` | `COPY web/ ./web/`, `COPY *.go`; `.dockerignore`; локальный build | s20b |
| Нет Playwright/браузеров на runner | API-smoke всегда; chromium ставит runner; fail-close | s20c |
| UI-граф расходится с кодом | один источник `ui-pages/*`; s21 сверка по факту | s21 |
| Sed canary не попадает | DELETE и `http.StatusNoContent` в `main.go`; grep-оракул | s20/s22b |
| Утечка `password`/`hash`/`salt`/`token` | response-структуры, `json:"-"`, `TestNoSecretLeak` | s20 |
| PBKDF2 под `Store.mu` / медленные тесты | hash вне lock, `regMu`, `pbkdf2Iterations` — `var` | s20 |
| 404 vs 403 / порядок auth | `TestDeleteForeignNote`, `TestAuthRequired`, `TestAuthMethodOrder` | s20 |
| `preview-deploy.json` с локальным HEAD | sha из фактического деплоя/provenance | s20b |
| Adapter path10 сломан | `stand_command` и `preview-deploy.sh` не менять; `git diff --exit-code` | s20a |
