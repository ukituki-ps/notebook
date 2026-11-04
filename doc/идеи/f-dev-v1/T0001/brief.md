# T0001 — brief

- unit_id: notebook.delete-note
- domain: notebook-api
- sde: sde-backend
- change_class: plain
- scope: DELETE /api/notes/{id} + тесты
- files: main.go, main_test.go

## Реализация
1. `Store.Delete(id int) bool` — удаляет по id под mutex.
2. Роут `DELETE /api/notes/{id}`: `strconv.Atoi`; ошибка → 400 `{"error":"invalid id"}`; нет записи → 404 `{"error":"not found"}`; успех → 204.
3. `GET /api/notes` отражает удаление.

## Acceptance / оракулы
- `go test ./... -run TestDeleteExisting` → 204 + отсутствует в List.
- `go test ./... -run TestDeleteMissing` → 404.
- `go test ./... -run TestDeleteInvalidID` → 400, без паники.
- `go test ./...` — весь пакет зелёный.
