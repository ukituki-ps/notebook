# F-DEV-V1 — change-definition

Feature: удаление заметки в «Записной книге» (backend-only).

## Домены и поверхности
- `notebook-api` — HTTP-слой и in-memory Store (`main.go`, `main_test.go`).

## Изменения
### C1. DELETE /api/notes/{id}
- До: только `GET /api/notes`, `POST /api/notes`.
- После: `DELETE /api/notes/{id}`.
  - `204 No Content` — заметка удалена;
  - `400 Bad Request` — id не является целым числом;
  - `404 Not Found` — заметки с таким id нет;
  - успешное удаление отражается в `GET /api/notes`.
- Store: `Delete(id int) bool`.

### C2. Тесты
- `go test ./...` покрывает: удаление существующей, 404, 400, отражение в списке.
- Контракт List/Add не меняется.

## Вне scope
Аутентификация, персистентность, UI, preview-деплой, миграции.

## Риски
- Низкий: обратимое локальное изменение одного файла + тесты.
