# s15 — REGRESSION: notebook-deploy-e2e (U03)

- regression_status: **pass**
- verified_by: auditor
- commit: 9885c61b204119e91f9f2eb050ffb78f6337be4d

## Прогон

- `bash -n deploy/path1/e2e-preview.sh` — PASS.
- JSON path1.project.json / path1.ui.json — PASS.
- Dockerfile: COPY web/ до go build — PASS; runtime/ENTRYPOINT/EXPOSE не изменены.
- `git diff --exit-code e2436c9 -- deploy/path1/preview-deploy.sh` — пусто.
- adapter: graph.source_roots=["web"], frontend_dir="web", audit.mode="app",
  audit.database=false, canaries.require_dsn=false, CANARY-DELETE-STATUS сохранён.
- stand_command path10 не изменён.
- e2e-preview.sh проверен на mock-стенде (auth/isolation/401/400/404/204) и
  fail-close сценариях (нет браузера/npx/конфига).

## Регрессии

Не обнаружено. Docker build/E2E — на s20b/s20c.
