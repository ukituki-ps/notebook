# F-DEV-V1 — план

## Цель
Добавить удаление заметки в backend «Записной книги» без изменения существующего контракта List/Add.

## Единственный unit
- `unit_id`: `notebook.delete-note`
- `domain`: `notebook-api`
- `sde`: `sde-backend`
- `change_class`: `plain`
- `scope`: `DELETE /api/notes/{id}` + тесты
- `files`: `main.go`, `main_test.go`

## Шаги
1. Store.Delete(id int) bool.
2. Роут DELETE /api/notes/{id}: 204/400/404.
3. Тесты: существующая, отсутствующая, нечисловой id, список после удаления.
4. `go test ./...`.

## Критерии готовности
- Все тесты зелёные.
- List/Add не меняются.
- Нет новых зависимостей.

---
Artifact: `f-dev-v1/plan.md` (approved in dev Nexus).
