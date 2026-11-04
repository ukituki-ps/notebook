# s16 — SPEC-SYNC: notebook-auth-api (U01)

- drift_count: **0**
- verified_by: architect
- commit: f00a5089f4318e3d5252c5831d0e32282db06495

## Сверка spec/core.md ↔ main.go

| Spec | Реализация |
|---|---|
| POST /api/register 201/400/409/405 | handleRegister, writeErr, Allow |
| POST /api/login 200/400/401/405 | handleLogin, dummy-PBKDF2, WWW-Authenticate |
| GET /api/notes 200 own/401/405 | handleNotes + owner list |
| POST /api/notes 201/400/401/405 | handleNotes + text validation |
| DELETE /api/notes/{id} 204/400/401/404/405 | handleNoteItem, http.StatusNoContent |
| JSON envelope | writeJSON/writeErr (нет http.Error) |
| PBKDF2 16B/210k/32B constant-time | store.go-часть main.go |
| token 32B/TTL 24h | createSession/lookupSession |
| UserID не сериализуется | Note.UserID `json:"-"` |

Drift: 0. OpenAPI не ведётся (spec/core.md §Contract).
