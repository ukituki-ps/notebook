# s13 — VERIFY: notebook-deploy-e2e (U03)

- verdict: **pass**
- architect ≠ executor: да
- commit: 8b2b0a1793ba3d55bb19036604f9bfaf0dc090f1

## Проверено

- Dockerfile: `COPY *.go` → `COPY web/` → `go build`; runtime не изменён.
- `.dockerignore` сохраняет embed-файлы и исключает web/e2e, web/node_modules.
- `deploy/path1/preview-deploy.sh` — без diff.
- adapter: graph.source_roots=["web"], e2e.frontend_dir="web",
  audit.mode="app", audit.database=false, canaries.require_dsn=false,
  CANARY-DELETE-STATUS сохранён, stand_command path10 не изменён.
- e2e-preview: 401/auth/CRUD/A-B isolation/404/400/204 + Playwright fail-close.
- path1.ui.json platform="web".

## Блокеры

Нет. Docker build/E2E — на s20b/s20c после merge U02.
