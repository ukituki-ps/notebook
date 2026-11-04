# Platform request: s20c run-artifact sync (E4312)

- project_id: `f41f0adb-67d9-4ddf-8ba9-0efd9c6e50a9`
- execution: `E4312` (f-v3-auth-notes)
- step: `s20c.preview_verify` (`gate-e2e-preview`)
- branch: `dev/f-v3-auth-notes`
- scenarios source commit: `b7ca01354063a8aee436c7bda204f9c10ec00a81`
- stand: `test2` (build `60c0943`, /healthz 200, unauth /api/notes 401)

## Симптом

При `orc_accept(s20c)` ORC пересоздаёт eval-worktree
`.orc-eval/E4312/<sha>` и синхронизирует в него только
`preview-deploy.json` и `preview-verdict.json`.
Per-run артефакты E2E исчезают:

- `doc/идеи/f-v3-auth-notes/scenario-evidence.json`
- `doc/идеи/f-v3-auth-notes/screenshots/E2E-1..7*.png`

`gate-e2e-preview` (`/opt/gate-tools/tools/check-preview-verified.sh`)
читает их через `idea_file` из feature-dir gate-worktree и падает:

```
gate-e2e-preview: FAIL — нет scenarios.json
```

(в текущем прогоне `scenarios.json` уже закоммичен как source; следующий
FAIL будет на `scenario-evidence.json`/скриншотах, если sync не расширить).

Текущий `preview-verdict.json` подтверждает реальный UI-прогон:

```
result=pass, status=verified, mode=ui, ref=60c0943, bundle=/app.js
out_dir=.../.orc-eval/E4312/60c0943.../doc/идеи/f-v3-auth-notes/screenshots
evidence_manifest_sha256=sha256:b8a5417e...
```

Но после пересоздания worktree этого каталога уже нет.

## Текущий код (platform, не менялся)

`/app/repo/orc/acceptance/run_artifacts.go`:

```go
var runArtifactAllowlist = []string{"preview-deploy.json", "preview-verdict.json"}
```

`syncRunArtifacts` копирует только allowlist-имена из execution root
(`RepoPath`) в `manifest.eval_root`.

## Точный запрос (не ослабляя гейты)

1. Расширить `runArtifactAllowlist`:
   - `scenario-evidence.json`;
   - `screenshots` (каталог, рекурсивно) либо `screenshots/*.png`.
2. Копировать их не только в `eval_root`, а в
   `<eval_root>/<feature_dir>/` (`doc/идеи/f-v3-auth-notes/`), потому что
   `idea_file` резолвит именно оттуда.
   Альтернатива: `check-preview-verified.sh` читает эти два артефакта из
   `ORC_EXECUTION_ROOT/<feature_dir>/` как fallback.
3. Не коммитить per-run артефакты в git: `check-run-artifacts.sh` остаётся
   строгим (fail, если `scenario-evidence.json`/`screenshots/**` tracked).
4. Не отключать hash-pin и не расширять allowlist на произвольные файлы:
   только `scenario-evidence.json` + `screenshots/**` для s20c.
5. `scenarios.json` — source-артефакт, уже в git (commit `b7ca013`), sync не
   нужен.

## Проверка после фикса

1. Выкатить/оставить preview `60c0943` на test2 (build_ref=60c0943, health 200).
2. Прогнать UI E2E (7/7), получить scenario-evidence.json + screenshots.
3. `orc_resume(E4312)` → accept s20c; gate должен увидеть:
   - `doc/идеи/f-v3-auth-notes/scenarios.json` (git);
   - `doc/идеи/f-v3-auth-notes/scenario-evidence.json` (synced);
   - `doc/идеи/f-v3-auth-notes/screenshots/E2E-*.png` (synced).
4. Затем s21 → s22/s22a/s22b/s22c → s23 → s24.

Без platform-фикса s20c не обходится: fake evidence, symlink, commit
per-run артефактов, self-sign, force/skip/waiver запрещены.
