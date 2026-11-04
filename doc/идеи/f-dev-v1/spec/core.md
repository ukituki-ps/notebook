# F-DEV-V1 — spec/core

## Контракт API
Сервис «Записная книга» (backend-only, Go, in-memory).

### DELETE /api/notes/{id}
- `{id}` — целое положительное число.
- Успех: `204 No Content`, тело пустое.
- `400 Bad Request`: `{"error":"invalid id"}` — id не целое число.
- `404 Not Found`: `{"error":"not found"}` — заметки нет.
- Идемпотентность: повторное удаление отсутствующей заметки — `404`.
- `GET /api/notes` после удаления не содержит удалённую заметку.

## Инварианты
- `INV-NOTE-DELETE-1`: после успешного DELETE заметка отсутствует в List.
- `INV-NOTE-DELETE-2`: существующие List/Add не меняют контракт.
- `INV-NOTE-DELETE-3`: невалидный id не паникует и не удаляет данные.

## Оракулы
- `go test ./...`
- `go test ./... -run TestDelete`
