# Intent brief — f-v4-note-search (s07)

- Execution: **E0809** · step `s07.requirements_reconcile` · role: product
- Process: `path-1.feature` **4.0.0** · entry `default` · platform `web` · profile `full`
- Branch: `dev/f-v4-note-search-e2e` · base `e6aeb44e19f378811aa029fde1edf9ea42cbf73f`
- DS: **Notebook DS 1.0.0** (`ds/v1.0.0`, digest `02f027a8…da3d`)
- Trace: `intent-trace.json` — 45/45 raw items (37 match, 8 reinterpreted, 0 dropped, 0 missing)

## Goal

Найти заметку по тексту без перелистывания всего списка. Поиск owner-scoped,
работает поверх существующих notes API и notes view; auth, хранение и жизненный
цикл заметок не меняются.

## Просил → делаем

| Группа | Просил (пункты) | Делаем |
|---|---|---|
| **U01 backend** | R12–R18 | `GET /api/notes?q=` — trim, пустой/whitespace q → все свои заметки, иначе case-insensitive substring; owner predicate до текстового; без токена 401; нет совпадений → `200 []`; q > 512 байт → `400 {"error":"query too long"}` до сканирования. |
| **U01 tests** | R19–R23 | Go-тесты: находит / не находит / чужие не видны / 401 / URL-encoding и спецсимволы. |
| **U02 web** | R24–R30 | Поле `notes-search`, client-side фильтр загруженного списка, `notes-search-clear` возвращает полный список, `notes-search-empty` при непустом q без совпадений; create/delete/reload не ломаются; UI graph актуализируется на s21. |
| **U03 deploy/E2E** | R31–R40 | Preview только на `test2` под lease; Playwright 1.64.1; E2E: login, 2 заметки, найдено 1, не найдено, очистка, изоляция user B; `pngdiff` OK; lock-файлы не откатываются. |
| **Constraints** | R06–R11, R41–R45 | Без изменений auth/persistence; только scope поиска; f-v3, E4312, E1320 не трогаем; prod/main/stage/canary вне scope; без force/skip/waiver и фейковых evidence; fan-out s20 проверяется (3 child execution, 3 distinct session_id). |

## Superseding decisions (human-confirmed)

| Было в сыром запросе | Актуально (2026-11-08 team-lead task) | Статус |
|---|---|---|
| R02: `path-1.feature` 3.2.2 | `path-1.feature` **4.0.0**, entry `default`, web/full | `edited` |
| R03: base `dev/f-v3-auth-notes` @ `406fa965` | base `e6aeb44e…` + **Notebook DS 1.0.0** (`ds/v1.0.0`, digest `02f027a8`) | `edited` |
| R04: branch `dev/f-v4-note-search` | branch **`dev/f-v4-note-search-e2e`** | `edited` |
| R05: skip s45/s46 | skip s45/s46; в 4.0.0 также skipped s24a, s22d, s06a–s06e | `edited` |
| R09: s24 approval via `@nuxus_dev_bot` | s24 approval через Nexus human request + `orc_wait` (подписанный assertion), не «approved» в чате | `yes` |
| R11: fan-out «after s20» | проверка применяется к **s20 unit**-исполнениям | `yes` |
| R31: preview on `test2` | preview **только test2**, стенд под арендой E0809 | `yes` |
| R44: E4312/E1320 | не возобновляем, не принимаем, не изменяем; E0809 независим | `yes` |

## Assumptions / additions (в рамках запроса, не расширение scope)

- **Count**: `Найдено N` (`notes-search-count`) только для непустого trimmed q, `aria-live="polite"`, скрыт при пустом q (AOD-5).
- **Offline**: показываем только уже загруженные in-memory заметки; баннер «Нет сети…» и offline-zero вариант; без cache/service worker (AOD-4).
- **Retry**: кнопка «Повторить» в error state; search disabled при loading/error/offline/нуле заметок (AOD-1).
- **Delete label**: видимый «Удалить» + `aria-label="Удалить заметку #N"`; `Add`/`Logout` остаются English по DS-term policy (AOD-6).
- **E2E**: на test2 ожидается **15+ passed**, включая SEARCH-E2E-7/8 и user-B isolation.
- **Layout**: composer выше поля поиска (AOD-7); s03 ASCII search-first — устаревший референс.
- **Empty precedence**: при нуле заметок побеждает base `notes-empty`, search disabled.

## Prototype v6

Утверждён `prototypes/v6/prototype-review.json`: verdict **approved** (2026-11-08T14:49:20Z),
0 blockers / 0 majors / 0 open minors, 10/10 items fixed; 7 состояний + `normal`,
экспорты 390/1200; DS 1.0.0, 12 registry components, 0 local instances.

## Approval request

Прошу **явно подтвердить** на s08, что `intent-trace.json` (45/45) и этот brief
корректно отражают «что просил человек ↔ что делаем», включая 8 superseding
решений выше. Открытых вопросов нет; после подтверждения шаг закрывается.
