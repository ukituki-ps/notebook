# T0003 — brief

- unit_id: **notebook-auth-api**
- domain: **notebook-api**
- sde: **sde-backend**
- change_class: **security**
- task: owner-scoped notes (GET/POST/DELETE) + миграция `main_test.go` + canary
- files: `main.go`, `main_test.go`
- depends_on: T0001, T0002

## Scope

1. **`GET /api/notes`** (auth): `200` JSON-массив **только своих** заметок
   (`Note.UserID == session.UserID`), при пустом списке — `[]`, не `null`;
   `Note.UserID` не сериализуется; порядок — порядок вставки (без сортировки).
   `405 + Allow: GET, POST` для авторизованного неверного метода на коллекции.
2. **`POST /api/notes`** (auth): владелец берётся **только** из сессии
   (`user_id` в теле отсутствует/игнорируется); `201 {"id":N,"text":"..."}`;
   пустой/whitespace-only/`>4096` байт `text` → `400 text required`;
   битый JSON/тело `>1 MiB` → `400 invalid request body`;
   `405 + Allow: GET, POST`.
3. **`DELETE /api/notes/{id}`** (auth): порядок auth → method → path/id;
   - своя существующая → `204` без тела и без `Content-Type`;
   - нечисловой/пустой/overflow id → `400 invalid id`; отрицательный →
     `404 not found` (или `400`), без паники;
   - несуществующая **или чужая** → `404 {"error":"not found"}` (не 403/204);
   - `/api/notes/1/extra` → `400`, note 1 не удаляется;
   - неверный метод на item-пути → `405 + Allow: DELETE`.
   - **Canary:** DELETE-обработчик остаётся в `main.go`; литерал
     `http.StatusNoContent` присутствует в успешной ветке; успех ассертится
     ровно как 204. Обработчик не переносить в другой файл.
4. **Миграция `main_test.go` под auth.**
   - Сохранить **имена** `TestDeleteNote`, `TestDeleteErrorEnvelope`,
     `TestNotesMethodNotAllowed` и проверяемые литералы `invalid id`/`not
     found`/`method not allowed` (canary/audit-оракулы).
   - Перевести существующие тесты (`TestNotesLifecycle`, `TestAddNote`,
     `TestDeleteExisting`, `TestDeleteMissing`, `TestDeleteInvalidID`,
     `TestListAfterDelete`, `TestDeleteNote`, `TestDeleteErrorEnvelope`,
     `TestNotesMethodNotAllowed`) на `seedUser`/`authedRequest`; `mustSeedNote`
     получает токен.
   - Добавить/закрепить: `TestNotesIsolation` (A не видит и не удаляет note B),
     `TestDeleteForeignNote` (чужая → 404), `TestNotesPrefixBoundary`
     (пустой id/`1/extra`/границы префикса), а также все Test* из
     `invariants.json` и contract-matrix (включая созданные в T0001/T0002).
   - Никаких build-тегов `integration/e2e/manual`; тесты через HTTP-транспорт.

## Acceptance / оракулы

```sh
go build ./...
go vet ./...
go test -count=1 -run 'TestDeleteNote|TestDeleteErrorEnvelope|TestNotesMethodNotAllowed' ./...
go test -count=1 -run 'TestNotesIsolation|TestDeleteForeignNote' ./...
go test -count=1 -run 'TestDeleteInvalidID|TestNotesPrefixBoundary' ./...
go test -count=1 -run 'TestNotesLifecycle|TestAddNote|TestListAfterDelete|TestDeleteExisting|TestDeleteMissing' ./...
go test -race ./...
grep -n 'http.StatusNoContent' main.go
sh -c "! grep -R -E '^//go:build.*(integration|e2e|manual)' --include='*_test.go' ."
git diff --exit-code go.mod
```

- `GET` нового пользователя — `200 []` (не `null`), `UserID` в JSON отсутствует.
- Чужая заметка неотличима от несуществующей: `404 not found`.
- После seed-замены canary (`sed s/http.StatusNoContent/http.StatusOK/ main.go`)
  `TestDeleteNote` падает (`200 != 204`); на базе — зелёный.
- Весь `go test -race ./...` зелёный.

## Зависимости

- **T0001** (Store, сессии), **T0002** (auth-guard, envelope, helpers).
  Выполняется последней в U01 в том же worktree.

## Что НЕ делать

- Не менять имена `TestDeleteNote`, `TestDeleteErrorEnvelope`,
  `TestNotesMethodNotAllowed`.
- Не переносить DELETE из `main.go`; не заменять `http.StatusNoContent`
  константой/`204`/алиасом.
- Не возвращать `403` на чужую заметку; не раскрывать `UserID`.
- Не отдавать `null` вместо `[]`; не сортировать список на сервере.
- Не добавлять БД/DSN/миграции, logout, refresh TTL, rate limiting.
- Не менять `web/*`, `deploy/*`, adapter-файлы; не добавлять зависимости.
- Не добавлять build-теги `integration/e2e/manual`.
- Не трогать E1320 и артефакты других исполнений.
