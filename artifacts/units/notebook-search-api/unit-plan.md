# Unit plan — notebook-search-api

- execution: E6636 (E6636-s20.sde_5fexecution-u01)
- step: s10.unit_plan (C-10)
- unit_id: notebook-search-api
- domain: notebook-api
- sde: sde-backend
- change_class: plain
- files: main.go, main_test.go
- base_sha: 1722a1e51b3734284c6a9103a4ed2e5ab5793386
- DS: Notebook DS 1.0.1 (ds_digest sha256:4e0ef1…85e)
- feature: f-v4-note-search (doc/идеи/f-v4-note-search)
- verification: `GOWORK=off go build ./...` + `GOWORK=off go test ./...`

## Цель

GET /api/notes?q= — owner-scoped, case-insensitive substring search.
База уже содержит реализацию и тесты; шаг верифицирует базовый контракт и
добавляет только отсутствующие Go-тесты. Ни одна продуктовая правка не
планируется без провала пункта верификации.

## Контракт (scope → реализация → тест)

| # | Требование | Реализация | Покрытие в базе |
|---|------------|------------|-----------------|
| 1 | `q` trim/empty/whitespace → полный список | `handleNotes`: `strings.TrimSpace`, `query == ""` | `TestNotesSearchEmptyQuery`, `TestNotesSearchWhitespaceQuery` |
| 2 | case-insensitive substring | `strings.ToLower` обеих сторон + `strings.Contains` | `TestNotesSearchCaseInsensitive` |
| 3 | `[]`, не `null`, при отсутствии совпадений | `ListNotes` возвращает `make([]Note, 0)`; `filtered` с cap 0 | `TestNotesSearchNotFound` |
| 4 | owner predicate ДО text predicate | `ListNotes(session.UserID)` затем фильтр | `TestNotesSearchIsolation` |
| 5 | `UserID` не сериализуется | `Note.UserID` → `json:"-"` | `TestNotesSearchIsolation` (leak scan) |
| 6 | cap 512 байт ДО скана; `>512` → 400 `query too long`; ровно 512 — ок | `maxQueryBytes = 512`, проверка `len(rawQuery) > maxQueryBytes` до `ListNotes` | `TestNotesSearchQueryTooLong` (bytes vs runes, exactly 512, multibyte) |
| 7 | auth 401 ДО обработки query (в т.ч. до cap) | `requireAuth` первым вызовом `handleNotes` | `TestNotesSearchAuthRequired` (oversized q без auth → 401) |

## План работ (unit_plan)

1. `V1` verify trim/empty/whitespace — прогнать `TestNotesSearchEmptyQuery`, `TestNotesSearchWhitespaceQuery`; убедиться, что whitespace-only `q` даёт тот же payload, что базовый GET.
2. `V2` verify case-insensitive substring — `TestNotesSearchCaseInsensitive`, `TestNotesSearchEncoding` (percent/space/ampersand/plus, кириллица).
3. `V3` verify `[]` not null — `TestNotesSearchNotFound`; проверить точный body `[]` без `null`.
4. `V4` verify owner-before-text — `TestNotesSearchIsolation`: поиск не расширяет scope, чужие note ID не попадают в выдачу.
5. `V5` verify UserID не утекает — leak-scan `user_id`/`UserID`/`"userId"` в filtered-ответе.
6. `V6` verify 512-byte cap — `TestNotesSearchQueryTooLong`: 513 → 400 `{"error":"query too long"}`; 512 → 200; 256 двухбайтных рун = 512 байт → 200; 257 → 400; whitespace-only >512 → 400 до скана.
7. `V7` verify auth-first — `TestNotesSearchAuthRequired`: без токена и с невалидным токеном → 401 + `WWW-Authenticate: Bearer`; oversized `q` без auth → 401 (не 400).
8. `V8` gap check — если при прогоне V1–V7 обнаружится непокрытая ветка, добавить ТОЛЬКО отсутствующий Go-тест в `main_test.go` (без изменения контракта; правки `main.go` — только при фактическом дефекте, с фиксацией в evidence).
9. `V9` финализация — `GOWORK=off go build ./...` и `GOWORK=off go test ./...` из корня worktree; артефакт плана в `artifacts/units/notebook-search-api/unit-plan.md`; commit в `orc-exec-E6636-s20.sde_5fexecution-u01`.

## Ожидаемый результат

- Пункты V1–V7 подтверждены существующими тестами (green).
- V8: новых тестов не требуется либо добавлен минимальный недостающий тест.
- Build/test зелёные; план и evidence закоммичены в work_branch.

## Вне scope

- web/UI, e2e, deploy (отдельные unit: notebook-search-ui, notebook-search-deploy-e2e).
- Изменение публичного контракта `/api/notes` (методы, коды, envelope).
- Изменение DS 1.0.1.
