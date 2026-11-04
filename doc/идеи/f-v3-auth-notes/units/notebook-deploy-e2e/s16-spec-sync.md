# s16 — SPEC-SYNC: notebook-deploy-e2e (U03)

- drift_count: **0**
- verified_by: architect
- commit: 28c47402c3ea40168733f2d4da1b04e6318fe2e9

## Сверка adapter/spec ↔ файлы

| Spec/T0009 | Реализация |
|---|---|
| graph.source_roots=["web"] | path1.project.json |
| graph.artifact_globs ui-pages/*.yaml | path1.project.json |
| e2e.frontend_dir="web" | path1.project.json |
| e2e.command=deploy/path1/e2e-preview.sh | path1.project.json |
| deploy.stand_command path10 | не изменён |
| audit.mode=app, database=false, require_dsn=false | path1.project.json |
| path1.ui.json platform=web | path1.ui.json |
| Dockerfile COPY web до go build | deploy/Dockerfile |
| E2E auth/isolation/401/400/404/204 | deploy/path1/e2e-preview.sh |
| CANARY-DELETE-STATUS | сохранён |

Drift: 0.
