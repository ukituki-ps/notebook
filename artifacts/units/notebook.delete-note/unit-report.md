# Unit report — notebook.delete-note

## Change
- `Store.Delete(id int) bool`.
- `DELETE /api/notes/{id}`: 204 / 400 / 404.
- Tests cover existing, missing, non-numeric and list-after-delete.
- List/Add contract unchanged; no new dependencies.

## Verification
- `go test ./...` → ok
- `go vet ./...` → clean

## Files
- `main.go`
- `main_test.go`
