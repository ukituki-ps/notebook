# T0008 — brief

- unit_id: **notebook-deploy-e2e**
- domain: **notebook-deploy**
- sde: **sde-infra**
- change_class: **security**
- task: `deploy/path1/e2e-preview.sh` — auth-smoke + Playwright runner
- files: `deploy/path1/e2e-preview.sh`
- depends_on: T0007

## Scope

1. **Вход/health (сохранить).** `E2E_BASE_URL` (fallback `PREVIEW_BASE_URL`),
   fail-fast при отсутствии; проверка `/healthz` стенда — **nginx JSON**
   (`build_ref`, `commit` 40hex), а не app-`ok\n`; сообщения/exit-коды
   осмысленные.
2. **Auth-smoke (API).**
   - `GET /api/notes` без токена → `401` + `WWW-Authenticate: Bearer`;
   - `POST /api/register` для двух пользователей A/B (уникальные имена на
     прогон) → `201` (повтор → `409`, не маскировать);
   - `POST /api/login` A/B → `200` + непустой `token`;
   - authed `POST /api/notes` A → `201`; `GET /api/notes` A содержит заметку;
   - `GET /api/notes` B **не** содержит заметку A (изоляция);
   - authed `DELETE` note A → `204`; повторно → `404`; чужая (из B) → `404`;
     `abc` → `400`;
   - неавторизованный `GET /api/notes` → `401` (порядок auth раньше прочего).
3. **Playwright.** После API-smoke запустить Playwright (`chromium`) с
   `baseURL` из `E2E_BASE_URL` (скрипт T0006 `web/e2e/auth-notes.spec.js`),
   из корня репозитория. При отсутствии Playwright/браузеров/`node` —
   **fail-close** с явной ошибкой и ненулевым exit, не skip и не «зелёный» E2E
   (платформа web).
4. **Совместимость.** Сохранить `set -euo pipefail`, переменные и стиль
   сообщений; скрипт остаётся единственным входом `e2e.command`/
   `integration.command`; body можно переписать, строку в adapter не менять.
5. Полный прогон на стенде test2 — s20c (нужны merge U01+U02, s20b deploy,
   браузеры на runner).

## Acceptance / оракулы

```sh
bash -n deploy/path1/e2e-preview.sh
grep -q 'E2E_BASE_URL' deploy/path1/e2e-preview.sh
grep -q 'healthz' deploy/path1/e2e-preview.sh
grep -q '/api/register' deploy/path1/e2e-preview.sh
grep -q '/api/login' deploy/path1/e2e-preview.sh
grep -q 'Authorization' deploy/path1/e2e-preview.sh
grep -q 'playwright' deploy/path1/e2e-preview.sh
grep -q 'WWW-Authenticate\|401' deploy/path1/e2e-preview.sh
```

- `bash -n` — синтаксис валиден.
- Скрипт содержит 401-проверку, register/login A/B, authed GET/POST/DELETE,
  проверку изоляции A/B и запуск Playwright.
- Нет ветки, которая при отсутствии браузеров выходит с `0`/skip.
- `E2E_BASE_URL`/`PREVIEW_BASE_URL` и health-контракт nginx сохранены.

## Зависимости

- **T0007** (образ с `web/`). Реальный прогон — s20b (deploy test2) → s20c.

## Что НЕ делать

- Не менять `e2e.command`/`integration.command` в `path1.project.json` и
  `deploy/path1/preview-deploy.sh`.
- Не проверять app-`/healthz` как JSON и не подменять nginx-health.
- Не «зеленить» E2E при отсутствии Playwright/браузеров (никакого skip/tolerant).
- Не добавлять безавторизационные вызовы `/api/notes*` как успешный путь.
- Не деплоить и не собирать образ здесь (s20b).
- Не менять `web/*`, `main.go`, `main_test.go`, `deploy/Dockerfile`.
- Не трогать prod/canary rollout, `s45/s46`.
