# s12 — CHECK: notebook-deploy-e2e (U03)

- fixed_confirmed: **true**
- commit: 34041eb80ddd876df5958036fe5d27e14afb6e95

## Выполненные проверки

| Проверка | Команда | Результат |
|---|---|---|
| shell syntax | `bash -n deploy/path1/e2e-preview.sh` | PASS |
| JSON | `python3 -c json.load(path1.project.json/ui.json)` | PASS |
| Docker order | `COPY web/` до `go build` | PASS |
| preview-deploy | `git diff --exit-code e2436c9 -- deploy/path1/preview-deploy.sh` | пусто |
| adapter | graph.source_roots=web, frontend_dir=web, audit.mode=app, database=false, require_dsn=false | PASS |
| canary | CANARY-DELETE-STATUS сохранён | PASS |
| stand_command | `bash deploy/path1/preview-deploy.sh {stand} {ref}` | не изменён |

Evidence: `PR-0982be42e099`.
