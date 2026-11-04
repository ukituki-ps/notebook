# s15 — REGRESSION: notebook-auth-api (U01)

- regression_status: **pass**
- verified_by: auditor
- commit: fc57b579854f68bbe219af924d097bfa07722375

## Прогон

- `go test -count=1 ./...` — PASS (23 теста, включая canary-имена).
- `go build ./...`, `go vet ./...` — PASS.
- Изменение поведения /api/notes (auth) — намеренное breaking change по
  change-definition C4/C5; старые неавторизованные сценарии заменены
  auth-тестами.
- `go.mod` не изменён; новых зависимостей нет; build-тегов нет.
- Canary CANARY-DELETE-STATUS: `http.StatusNoContent` в main.go, тест
  TestDeleteNote детектирует подмену на 200.

## Регрессии

Не обнаружено.
