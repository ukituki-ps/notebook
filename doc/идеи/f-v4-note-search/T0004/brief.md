# T0004 — search tests: not-found and encoding (s16 task brief)

- Unit: `notebook-search-api`
- Domain: `notebook-api`
- SDE: `sde-backend`
- Change class: `plain`
- Files: `main_test.go`

## Scope

1. Add/extend `TestNotesSearchNotFound`: a non-matching `q` returns `200` with
   `[]` (never `null`), no error envelope, and no foreign notes.
2. Add/extend `TestNotesSearchEncoding`: URL-encoded and special characters in
   `q` (`%20`, `+`, `%2B`, `&` and other special characters) are decoded by `net/http` and
   handled without panic or `500`.
3. Exercise cases through `httptest.Server` / the real HTTP transport, not
   direct `Store` calls (`INV-REAL-TRANSPORT`).
4. Keep the existing auth, lifecycle, method, and wire tests green; no build
   tags or excluded invariant set.

## Acceptance oracles

- `go test -count=1 -run 'TestNotesSearchNotFound|TestNotesSearchEncoding' ./...`
- `go build ./...`, `go vet ./...`, `go test -count=1 ./...`
- `TestHTTPTransport`, `TestWireContract`, `TestNotesMethodNotAllowed` stay green.
- Invariants: `INV-SEARCH-NOT-FOUND`, `INV-SEARCH-ENCODING`,
  `INV-REAL-TRANSPORT`, `INV-WIRE-CASING`, `INV-NO-SKIP-TAGS`.

## Forbidden

Production-code changes outside `main_test.go` for this task; changing existing
status codes/envelopes; asserting `null`; direct-`Store`-only checks instead of
the real transport; build tags; skipping or weakening encoding/not-found cases.
