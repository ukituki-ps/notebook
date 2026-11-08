# Unit plan — notebook-search-api (E0809 s20/u01)

- **Unit:** notebook-search-api · domain notebook-api · sde-backend · plain
- **Branch:** orc-exec-E0809-s20.sde_5fexecution-u01 · base_sha f5943f5
- **Files:** main.go, main_test.go

## Goal

Ship the owner-scoped `GET /api/notes?q=` contract of spec/core.md §1 with
executable Go coverage; no auth/session/persistence or wire-schema change.

## Tasks

### T0001 — q contract
Decode `q`, apply `TrimSpace`; absent/empty/whitespace → all own notes;
non-empty → case-insensitive substring (`strings.ToLower` both sides);
no match → `200 []`, never `null`.
Oracle: `TestNotesSearchFinds`, `TestNotesSearchCaseInsensitive`,
`TestNotesSearchNotFound`, `TestNotesSearchEmptyQuery`,
`TestNotesSearchWhitespaceQuery`, `TestNotesSearchEncoding`.

### T0002 — owner predicate
`ListNotes(session.UserID)` runs before the text predicate; `q` narrows,
never widens; `UserID` stays `json:"-"`.
Oracle: `TestNotesSearchIsolation`, `TestNotesIsolation`.

### T0003 — 512-byte cap incl. exactly-512
`len(q) > maxQueryBytes` → `400 {"error":"query too long"}` before any scan;
exactly 512 bytes accepted; bytes not runes; a >512 whitespace-only `q` is
also `400`. Gap: add the exactly-512 accept case to
`TestNotesSearchQueryTooLong`.
Oracle: `TestNotesSearchQueryTooLong`.

### T0004 — auth / wire tests
`requireAuth` before method/query → `401` + `WWW-Authenticate: Bearer`;
wire keys stay `id`/`text`; real httptest transport.
Oracle: `TestNotesSearchAuthRequired`, `TestWireContract`, `TestHTTPTransport`.

## Execution order
T0001 → T0002 → T0003 → T0004. Add only missing tests; do not rename or
weaken existing tests.

## DoD
`go build ./...`, `go vet ./...`, `go test -count=1 ./...` green; all
`TestNotesSearch*` pass incl. exactly-512 accept; diff limited to main.go and
main_test.go; auth/persistence/wire unchanged.

## Out of scope
Auth/session/token/persistence, pagination/ranking/fuzzy/highlighting,
dependencies, UI/E2E files, prod/main/stage/canary.
