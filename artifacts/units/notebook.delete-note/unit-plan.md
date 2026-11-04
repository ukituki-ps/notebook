# Unit plan — notebook.delete-note

1. `Store.Delete(id int) bool` (id space stays monotonic).
2. `DELETE /api/notes/{id}` → 204 removed, 400 non-integer id, 404 missing.
3. Tests: existing, missing, non-numeric, list after delete.
4. `go test ./...`.
