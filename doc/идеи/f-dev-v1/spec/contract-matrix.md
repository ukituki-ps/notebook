# F-DEV-V1 — contract matrix

| endpoint | method | status | envelope | test |
|---|---|---|---|---|
| /api/notes/{id} | DELETE | 204 | none | go test ./... -run TestDeleteExisting |
| /api/notes/{id} | DELETE | 400 | {"error":"invalid id"} | go test ./... -run TestDeleteInvalidID |
| /api/notes/{id} | DELETE | 404 | {"error":"not found"} | go test ./... -run TestDeleteMissing |
| /api/notes | GET | 200 | []Note | go test ./... -run TestListAfterDelete |
| /api/notes | POST | 201 | Note | go test ./... -run TestAddNote |

## Негативные и краевые кейсы
- DELETE нечисловой id → 400, `go test ./... -run TestDeleteInvalidID`
- DELETE отсутствующий id → 404, `go test ./... -run TestDeleteMissing`
- DELETE отрицательный id → 400/404 без паники, `go test ./... -run TestDeleteInvalidID`
- повторный DELETE → 404, `go test ./... -run TestDeleteMissing`
- GET после DELETE → пусто/без элемента, `go test ./... -run TestListAfterDelete`
