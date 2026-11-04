# Unit integration report — notebook

## f-v3-auth-notes (E4312, s20a.unit_integrate)

- Repo: `/workspace/projects/notebook`
- Branch: `dev/f-v3-auth-notes` @ `109127c29cb407793086c304a294679619a9ab74`
- Base: `8e0e949`
- Все три unit смерджены; конфликтов в рабочем дереве нет.

### 1. Units / merges

| Unit | Branch | Merge commit | Status |
|---|---|---|---|
| U01 `notebook-auth-api` | `orc-exec-E4312-s20.sde_5fexecution-u01` | `a1a9ad8` | merged |
| U03 `notebook-deploy-e2e` | `orc-exec-E4312-s20.sde_5fexecution-u03` | `c1b210a` | merged |
| U02 `notebook-web-ui` | `orc-exec-E4312-s20.sde_5fexecution-u02` | `109127c` (промежуточный `e17e812`) | merged |

U01 и U03 вошли machine merge без конфликтов. U02 смерджен последним,
поверх уже интегрированных U01/U03.

### 2. Разрешённые конфликты

| Файл | Причина | Разрешение | Проверено |
|---|---|---|---|
| `main.go` | U01 добавил auth-бэкенд (PBKDF2, сессии, owner-scope, JSON-envelope); U02 добавил `go:embed` и static-раздачу UI | В `e17e812` сохранены обе стороны: auth-маршруты и guard-порядок из U01 + `webFS`/`go:embed web/index.html web/app.js web/app.css` и `serveAsset`/`serveIndex` из U02. Статические пути не перехватывают `/api/*`. | `go build`/`go vet`/`go test` на merged HEAD — PASS; DELETE-обработчик и литерал `http.StatusNoContent` остались в `main.go`; embed собирает только `web/` (без `web/e2e`). |

Других текстовых конфликтов при интеграции не было.

### 3. Интеграционные проверки (merged HEAD)

- `go build ./...` — PASS
- `go vet ./...` — PASS
- `go test ./...` — PASS (включая `main_test.go` и `web_ui_test.go`)
- `bash tools/gate-l1-unit.sh` — PASS, evidence `PR-5386aac82ddf`
- UI testids: **27/27** декларированных в `arch/structure/ui-pages/{login,register,notes}.yaml` присутствуют в `web/` (28-й литерал — динамический `data-testid` для `note-item`)
- Playwright: **7** тестов в `web/e2e/auth-notes.spec.js` (list):
  1. `E2E-1 register: valid account redirects to /login with username prefilled`
  2. `E2E-2 login and token: 200 stores notebook.token and opens /notes`
  3. `E2E-3 create note: Add renders #id text in notes-list`
  4. `E2E-4 reload: note stays visible after page.reload()`
  5. `E2E-5 delete note: 204 removes the row and empty state appears`
  6. `E2E-6 isolation: user B cannot see or delete user A's note`
  7. `E2E-7 unauthenticated GET /api/notes returns 401 with WWW-Authenticate`
- Adapter assertions (`path1.project.json` / `path1.ui.json`):
  - `graph.source_roots = ["web"]`
  - `e2e.frontend_dir = "web"`
  - `platform = "web"` (UI-граф применим)
  - `audit.mode = "app"`, `audit.database = false`
  - `canaries.require_dsn = false`
  - `deploy.stand_command = "bash deploy/path1/preview-deploy.sh {stand} {ref}"` (path-10)
  - canary `CANARY-DELETE-STATUS` сохранён: seed `sed s/http.StatusNoContent/http.StatusOK/ {worktree}/main.go`, detect `go test -run TestDeleteNote ./...`
- Canary literal: `main.go:578` — `w.WriteHeader(http.StatusNoContent)`; DELETE-тесты ассертят ровно `204` (`main_test.go:196,524,824,840`).

### 4. Contract parity

- Внешний контракт `notebook-api`: **5 операций**
  - `POST /api/register`
  - `POST /api/login`
  - `GET /api/notes`
  - `POST /api/notes`
  - `DELETE /api/notes/{id}`
- `drift_count`: **0**
- `items`: 5/5 совпадают (метод, путь, статусы, envelope — по `spec/contract-matrix.md`; покрыты Go-тестами)
- `divergent`: `[]`

### 5. Counts

- baseline drift: **0**
- model: **8** change-definition items (`C1`–`C8`; C1 Store/PBKDF2/сессии, C2 register, C3 login, C4 notes, C5 delete, C6 UI, C7 тесты, C8 adapter/deploy)
- code diff: **~1500** строк нового кода в U02 (`109127c`: 1493 insertions); суммарно по фиче `8e0e949..109127c` — 2851 insertions / 238 deletions (~3.1k changed lines)
- drifted: **0**

### 6. Новые findings

Нет.

### 7. Риски / переносы

- Playwright 7/7 против preview-стенда и сквозной preview — **s20b/s20c** (не входят в s20a).
- UI-граф: перевод `arch/structure/ui-pages/*.yaml` в `status: implemented` по коду — **s21**.
- `docker build` с `web/` после merge — проверить на preview/deploy шаге (Dockerfile обновлён в U03, статика теперь есть в контексте сборки).
- Runtime-поведение `/login`, `/register`, `/notes` (history fallback) проверяется только Playwright на стенде, не Go-тестами.

### 8. Вердикт

**integrated, ready for preview.** Все три unit смерджены, конфликт `main.go` разрешён с сохранением auth-бэкенда и embed-статики, тяжёлые проверки на merged HEAD зелёные, контракт без drift.

---

## f-dev-v1 (notebook.delete-note)

### Units
- `notebook.delete-note` (sde-backend) — merged via machine merge.

### Result
- `DELETE /api/notes/{id}` implemented with 204/400/404.
- `Store.Delete(id int) bool`; id space remains monotonic.
- Tests cover existing, missing, non-numeric and list-after-delete.
- No contract drift (no OpenAPI modules in this app repo).
- No new dependencies; List/Add unchanged.

### Verification
- `go build ./...` — OK
- `go test ./...` — OK
- `go vet ./...` — OK

## Counts semantics (s20a)

- `code=2851` — строки diff (U01+U02+U03), не drift.
- `delta=0`, `drifted=0` — ни одна модель-единица не разошлась с кодом.
- `model=8` — C1–C8 change-definition.

## Re-integration after s23 refinement (E4312)

- s23 refinement: CR-5 fixed; Playwright pinned **1.64.1** with committed lock
  (`package-lock.json`); `e2e.command` = host-local
  `npm ci --no-audit --no-fund && npx --no-install playwright test`.
- 1.53.0 непригоден: `fill()` textarea остаётся пустым (4 E2E fail); 1.64.1 — 7/7.
- Units U01/U02/U03 и runtime-код не переделывались; re-run gates:
  go build/vet/test, API-smoke на test2, 7/7 E2E native/host-local.

## s24 — Final acceptance (E4312)

- Feature: f-v3-auth-notes (регистрация, логин, заметки, per-user isolation, web UI).
- Base: `8e0e949` (path-10); branch `dev/f-v3-auth-notes`.
- Preview: test2, build `ea1e61f`, health 200, unauth `/api/notes` 401.
- E2E: Playwright **1.64.1**, 7/7 (E2E-1..7), pngdiff OK,
  preview-verdict `result=pass`, `status=verified`.
- Accepted: s20a → s20b → s20c → s21 → s22 → s22a → s22b → s22c → s23 → s24a.
- UI audit A–L: 0 blockers/majors; red-team 15 attacks, 0 critical/high;
  code review pass, 0 critical/high; fault catalog 15 covered/5 na/0 gap.
- s45/s46 skipped; prod/main/stage/canary не затрагивались; E1320 не тронут.
- Residual: no rate-limit/lockout (dev), token localStorage XSS-residual,
  in-memory persistence, no logout revocation.
