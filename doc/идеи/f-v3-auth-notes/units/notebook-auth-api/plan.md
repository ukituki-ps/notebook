# Unit plan — notebook-auth-api (U01)

- unit_id: notebook-auth-api
- domain: notebook-api
- sde: sde-backend
- change_class: security
- files: main.go, main_test.go
- base_sha: e2436c9d022cf66240ecbba15b4c82d6f13a6605

## Tasks (порядок)

1. T0001 — Store: User/Session/Note, PBKDF2-HMAC-SHA256 (16B salt, 210k, 32B,
   constant-time, dummy-PBKDF2), opaque token 32B/TTL 24h, mutex; тесты
   TestPasswordHashed, TestTokenExpiry.
2. T0002 — POST /api/register (201/400/409/405), POST /api/login
   (200/400/401/405), auth guard (401 до method/id/body), JSON envelope,
   WWW-Authenticate/Allow; тесты TestAuthRequired, TestLoginInvalid,
   TestNoSecretLeak, TestWireContract.
3. T0003 — GET/POST /api/notes owner-scoped (200/201/400/401/405),
   DELETE /api/notes/{id} (204/400/401/404/405), миграция main_test.go,
   сохранение TestDeleteNote/TestDeleteErrorEnvelope/TestNotesMethodNotAllowed,
   TestNotesIsolation/TestDeleteForeignNote/TestHTTPTransport/
   TestNotesPrefixBoundary/TestAuthMethodOrder; `http.StatusNoContent` остаётся
   в main.go (canary).

## Acceptance

`go test -race ./...`, `go vet ./...`, все INV-* зелёные; без новых go.mod
зависимостей и build-тегов.
