# s11a — ARCH-APPROVE: notebook-deploy-e2e (U03)

- verdict: **approved**
- reviewed_commit: 7b2676729249118cd7ca4d65fedebafad911ffcc
- base: e2436c9d022cf66240ecbba15b4c82d6f13a6605

## Проверено

- `deploy/Dockerfile`: `COPY *.go ./` → `COPY web/ ./web/` → `go build`;
  runtime-stage/ENTRYPOINT/EXPOSE/NEXUS_BUILD_* не изменены.
- `.dockerignore`: исключает `web/e2e/`, `web/node_modules/`; embed-файлы
  (`web/index.html`, `web/app.js`, `web/app.css`) включены.
- `deploy/path1/preview-deploy.sh` — без diff от base.
- `path1.project.json`: `graph.source_roots=["web"]`,
  `e2e.frontend_dir="web"`, `audit.mode="app"`, `audit.database=false`,
  `canaries.require_dsn=false`, `CANARY-DELETE-STATUS` сохранён,
  `deploy.stand_command` path10 без изменений.
- `path1.ui.json`: `platform="web"`.
- `e2e-preview.sh`: health JSON, 401, register 201/409, login, authed
  GET/POST/DELETE, A/B isolation, чужая 404, invalid id 400, 204, Playwright
  chromium с fail-close без браузеров.
- Проверки: `bash -n`, JSON, порядок COPY web до go build, diff
  preview-deploy.sh — PASS (PR-0982be42e099).

## Замечания

Docker build выполняется на s20b после merge U02 (web/ появляется в контексте).
