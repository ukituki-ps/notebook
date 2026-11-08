---
unit_id: notebook-search-api
domain: notebook-api
sde: sde-backend
change_class: plain
scope:
  - "GET /api/notes?q=: trim; empty/whitespace -> all own notes; non-empty -> case-insensitive substring; [] not null"
  - "owner predicate (ListNotes(session.UserID)) before the text predicate; q narrows, never widens; UserID never serialized"
  - "512-byte cap on decoded q before any note scan: >512 -> 400 {\"error\":\"query too long\"}; exactly 512 accepted; bytes not runes"
  - "auth (401 + WWW-Authenticate: Bearer) before method/query handling"
  - "add missing Go tests (esp. exactly-512 accept); do not change auth, sessions, persistence or wire schema"
files:
  - main.go
  - main_test.go
---
# T0101 — notebook-search-api (U01)

## Goal

Ship the owner-scoped `GET /api/notes?q=` contract exactly as `spec/core.md` §1
defines it, with executable Go coverage, without touching authentication,
session/token handling, storage or note lifecycle.

## Task list

1. Verify/keep `q` handling order: `requireAuth` → decode `q` → 512-byte cap →
   `TrimSpace` → owner-scoped `ListNotes` → case-insensitive substring
   (`strings.ToLower` both sides). `q` absent/empty/whitespace → all own notes.
2. Keep the cap before `ListNotes`: `len(q) > 512` → `400
   {"error":"query too long"}`; exactly 512 bytes accepted; byte count, not
   runes; a >512-byte whitespace-only `q` is also `400`.
3. Keep the owner predicate first; never search across users; no match returns
   `200 []`, never `null`; wire keys stay `id`/`text` and `UserID` is not
   serialized.
4. Add only missing tests in `main_test.go`; required gap: exactly-512-byte
   accept (T0003). Do not weaken/rename existing tests or add build tags.
5. Do not change auth, register/login, POST/DELETE notes, persistence, or the
   response envelope.

## Oracles

`TestNotesSearchFinds`, `TestNotesSearchNotFound`,
`TestNotesSearchCaseInsensitive`, `TestNotesSearchIsolation`,
`TestNotesSearchAuthRequired`, `TestNotesSearchEmptyQuery`,
`TestNotesSearchWhitespaceQuery`, `TestNotesSearchEncoding`,
`TestNotesSearchQueryTooLong` (+ exactly-512 accept), `TestWireContract`,
`TestHTTPTransport`.

## DS constraints

Backend unit: no UI/CSS. Notebook DS 1.0.0 remains pinned and untouched; do not
edit `design/**`, `web/**`, DS files, or add dependencies.

## Out of scope

Auth/session/token/persistence changes; pagination, ranking, fuzzy matching,
highlighting; UI/E2E files; prod/main/stage/canary.

## Acceptance

`go build ./...`, `go vet ./...`, `go test -count=1 ./...` green; every
`TestNotesSearch*` passes, including exactly-512 accept; no auth, persistence or
wire-schema diff.

## Evidence required

Command + output digest for `go build`, `go vet`, `go test -count=1 ./...`;
the list of `TestNotesSearch*` results; `git diff` limited to `main.go` and
`main_test.go`; explicit confirmation that auth/persistence are unchanged.
