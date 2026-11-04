# T0009 — brief

- unit_id: **notebook-deploy-e2e**
- domain: **notebook-deploy**
- sde: **sde-infra**
- change_class: **security**
- task: adapter `path1.project.json` + `path1.ui.json` (UI-граф, frontend, audit)
- files: `path1.project.json`, `path1.ui.json`
- depends_on: —

## Scope

1. **`path1.project.json` — целевое состояние:**
   - `graph.source_roots` = `["web"]`;
   - `graph.artifact_globs` — `arch/structure/ui-pages/*.yaml`,
     `arch/structure/ui-pages/*.yml`, `doc/идеи/*/UI-GRAPH.yaml` (один источник
     `ui-pages/*`; второй граф не создаётся);
   - `e2e.frontend_dir` = `"web"`; `e2e.command` =
     `"bash deploy/path1/e2e-preview.sh"` (строку **не менять**, меняется тело
     скрипта в T0008); `integration.command` — тот же вход;
   - `audit.mode` = `"app"`, `audit.database` = `false`;
   - `canaries.require_dsn` = `false`; `canaries.items` — сохранить
     `CANARY-DELETE-STATUS` (sed по `main.go` + `TestDeleteNote`);
   - `audit.oracles` — расширить, **не ломая** существующие имена
     `CONTRACT-STATUS-CODE`, `SEC-ERROR-LEAK`, `SEC-WRITE-VERB-REJECT`;
     добавить `SEC-AUTH-REQUIRED`, `SEC-USER-ISOLATION` (и при необходимости
     `SEC-PREFIX-BOUNDARY`, `SEC-WIRE-CASING`) на реальные имена тестов;
   - `deploy.stand_command` = `"bash deploy/path1/preview-deploy.sh {stand}
     {ref}"` — **не менять** (path10 adapter); `deploy.project_id`,
     `runtime_dir`, `dsn_command` сохранить.
2. **`path1.ui.json`:** `{"platform":"web", "note": <краткое описание UI
   login/register/notes, same-origin /api/*, токен в localStorage>}` — UI-пробы
   и UI-шаги (s21/s22a) включены.
3. **`preview-deploy.json`** (корень репо) в этом шаге **не** создаётся: он
   материализуется на s20b из фактического деплоя (`stand`, `url`, `sha`
   выкаченного ref, `commit`, `image_digest`, `build_ref`, `deployed_at`), не
   из локального HEAD.
4. Поля, уже совпадающие с целевыми, оставить как есть; не переписывать
   несвязанные секции (`no_self_mock`, `detectors`, `feature_dir`).

## Acceptance / оракулы

```sh
jq -e '.graph.source_roots == ["web"]' path1.project.json
jq -e '.e2e.frontend_dir == "web"' path1.project.json
jq -e '.e2e.command == "bash deploy/path1/e2e-preview.sh"' path1.project.json
jq -e '.integration.command == "bash deploy/path1/e2e-preview.sh"' path1.project.json
jq -e '.audit.mode == "app" and .audit.database == false' path1.project.json
jq -e '.canaries.require_dsn == false' path1.project.json
jq -e '.deploy.stand_command == "bash deploy/path1/preview-deploy.sh {stand} {ref}"' path1.project.json
jq -e '.canaries.items[] | select(.id=="CANARY-DELETE-STATUS")' path1.project.json
jq -e '.audit.oracles["CONTRACT-STATUS-CODE"] and .audit.oracles["SEC-ERROR-LEAK"] and .audit.oracles["SEC-WRITE-VERB-REJECT"]' path1.project.json
jq -e '.platform == "web"' path1.ui.json
git diff --exit-code deploy/path1/preview-deploy.sh
```

- Все поля adapter в целевом состоянии; `stand_command` — path10 без изменений.
- `CANARY-DELETE-STATUS` и три исходных audit-оракула сохранены; новые оракулы
  ссылаются на существующие имена тестов.
- `path1.ui.json` → `platform: "web"`.
- `deploy/path1/preview-deploy.sh` без diff; `preview-deploy.json` не подменён
  локальным HEAD.

## Зависимости

- Нет. Runtime-проверка adapter-гейтов (`e2e-preview`, UI) — после T0007/T0008
  и s20b/s20c.

## Что НЕ делать

- Не менять `deploy.stand_command` и `deploy/path1/preview-deploy.sh`.
- Не менять строку `e2e.command`/`integration.command` (только тело скрипта —
  T0008).
- Не удалять/переименовывать `CANARY-DELETE-STATUS` и существующие
  `audit.oracles`.
- Не создавать второй UI-граф (`arch/frontend/pages/*`, `UI-GRAPH.yaml`) и не
  править `arch/structure/ui-pages/*.yaml` (актуализация — s21).
- Не записывать `preview-deploy.json` с локальным HEAD (только s20b, из деплоя).
- Не менять `no_self_mock`, `detectors`, `feature_dir` и несвязанные секции.
- Не трогать prod/canary rollout, `s45/s46`.
