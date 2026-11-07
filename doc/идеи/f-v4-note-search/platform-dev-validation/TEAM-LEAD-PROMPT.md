# Промпт тимлиду: финальная проверка platform на Notebook

Ты — тимлид проекта **Notebook**. Проведи проверку платформы на dev-контуре.

## Контур (только dev)

- ORC MCP: `http://192.168.1.20:8390/mcp` (dev). **Проверь, что в твоём списке инструментов есть `orc_wait`.**
  Если `orc_wait` нет — ты подключён к production `8290`; остановись и доложи: нужен dev-ORC.
- Nexus MCP должен быть dev: `nexus_stand_status(project_id=...)` показывает стенд `test2`.
  Если список пуст — это не dev-Nexus; остановись и доложи.
- Nexus: `https://dev.nexus.ukituki.tech`
- Project ID: `f41f0adb-67d9-4ddf-8ba9-0efd9c6e50a9`
- Repo: `git@github.com:ukituki-ps/notebook.git`
- Work branch: `dev/f-v4-note-search-ae079e5c` (в нём уже есть RT-NEW-1/2/3 fixes)
- Platform dev: `f6a5fcf1`; gate bundle при старте: `sha256:263c48a44e1abaaedb7378066cfe7fc831faade7bb5dc3418756a4eed15bf1e8`
- Запрещено: prod / preprod / **test1**, `main`, force/skip/waiver, worktree-транспорт. Только **git**.

## Цель

Проверить s20b → s24 на реальном Notebook:
1. preview deploy test2 с непустым `gate_bundle_digest`;
2. s20c Playwright (ожидается **15 passed**, включая SEARCH-E2E-7/8);
3. s22b/s22c cross-pair review (author ≠ reviewer);
4. s24 approval **через `orc_wait`**, без «approved» в чате.

## E1488 не воскрешаем — новый execution

- Платформа: `f6a5fcf1`, gate bundle `sha256:263c48a4…`.
- Host stand-runner перезапущен и принимает `feature_dir`/`feature_id` (проверено: тестовый request дошёл до `eval-worktree-missing`, а не `request-fields-invalid`). После следующих деплоев его перезапускает cron.
- E1488 **не реопеним**: downstream s21/s22 уже done, guard «no silent invalidation» блокирует s20b, и это правильно. Force/cascade не применяем.
- В ветке уже есть evidence-фикс (различимые скриншоты, `033886b`/`aa32731`).

Запусти **новый execution**:

1. `orc_start`:
   - `process_id`: `path-1.feature`
   - `entry_point`: `integrate`
   - `project_id`: `f41f0adb-67d9-4ddf-8ba9-0efd9c6e50a9`
   - `session_id`: твой реальный `ses_...`
   - `context`: `{ "work_branch": "dev/f-v4-note-search-ae079e5c" }`
2. Сразу возьми test2: `nexus_stand_lease(stand="test2", execution_id=<E>, ttl_minutes=180, project_id=...)`.
3. Прогони `s20a → s24` строго через `orc_next`/`orc_accept`.
   - `s20a`: invariant-enforced теперь читает `doc/идеи/f-v4-note-search/invariants.json` (16/16 active).
   - `s20c`: должен быть **UI mode** (feature-scope доходит); свежие screenshots + manifest + verdict одним прогоном.
   - `s24`: **новый** `orc_human_request` (старый `apr_645…` не использовать) + `orc_wait`; Approve в Telegram, в чат писать не нужно.
4. В конце `nexus_stand_release`.
5. Без force/skip/waiver. Если `gate-evidence-authentic` снова красный — полный payload.

E1488 оставь как есть (running, не завершён); его не принимать и не реопенить.

## Старт

Вызови `orc_start`:

- `process_id`: `path-1.feature`
- `entry_point`: `integrate` (s20a → s24; s24a/s45/s46 в skip)
- `project_id`: `f41f0adb-67d9-4ddf-8ba9-0efd9c6e50a9`
- `session_id`: твой реальный `ses_...` (не выдумывай; если ORC отверг — доложи)
- `context`: `{ "work_branch": "dev/f-v4-note-search-ae079e5c" }`

Сразу после `orc_start` возьми стенд под это исполнение:

`nexus_stand_lease(stand="test2", execution_id=<E>, ttl_minutes=120, project_id="f41f0adb-67d9-4ddf-8ba9-0efd9c6e50a9")`

Если стенд занят — стоп, не ломай чужую аренду. В конце — `nexus_stand_release(lease=<id>)`.

Если s20a не видит unit-ветки — не подменяй процесс: остановись и доложи. Для полного прогона с нуля есть `entry_point: default` (s01 → s24); используй его только после отдельного подтверждения оператора, потому что это длинный прогон.

Дальше — строго `orc_next` / `orc_ctx` / `orc_accept`. Assurance-шаги s20b, s20c, s21, s22, s22a, s22b, s22c, s24 не скипать. `s23` можно скипнуть только если находок нет.

## Обязательная проверка approve (ключевая)

На s24:

1. `orc_human_request` с `subject="s24"`, `subject_ref="<feature_id>/s24"`, `branch="dev/f-v4-note-search-ae079e5c"`, `execution_id=<E>`, `step_id="s24.team_lead_accept"`, `artifact_path="<report>"`.
2. Получи `request_id` (`apr_...`) и **сразу** вызови:
   `orc_wait(execution_id=<E>, step_id="s24.team_lead_accept", request_id="apr_...", timeout_seconds=45, interval_seconds=2)`
3. Если `timed_out=true` — повтори с тем же `request_id`. **Не проси оператора писать «approved» в чат.**
4. Когда вернулся `state=approved` — передай `approval_ref` в
   `orc_accept(..., human={approved:true, approval_ref:"<path>", signature:"policy(path-1.feature@<version> 2026-11-07)"})`.

## Что проверить и записать

- `orc_status`: s20a…s24 done; s24 accepted.
- test2 `/healthz`: `commit` = evaluated SHA, `build_args_hash` непустой, `gate_bundle_digest` **непустой** и совпадает с `preview-deploy.json`/verdict.
- s20c: Playwright **15 passed** (SEARCH-E2E-1..8).
- `code-review.json`: `author_session_id != reviewer_session_id`; s22b/s22c — разные сессии.
- `orc_watch`: событие `human_decision`; `.orc-approvals/<apr_...>.json` существует.
- Замер: сколько секунд `orc_wait` ждал Approve; был ли `timed_out` и повтор.

## Стоп-условия

- Нет `orc_wait` в tools → стоп (не тот ORC).
- `gate_bundle_digest` пустой на test2 → стоп, это регресс.
- Любой гейт красный → стоп, пришли точную команду/ошибку; не обходи.
- Появилась необходимость prod/preprod/test1/main → стоп.

## Отчёт

Верни: execution ID, work branch, commit, stand, image digest, build_args_hash, gate_bundle_digest, `request_id`, время ожидания approve, таблицу гейтов, findings, отклонения от промпта.
