# U01 CHECK — notebook-search-api (E0809)

- unit tests: `go test -count=1 -run 'TestNotesSearch|TestWireContract|TestHTTPTransport|TestAuthRequired|TestNotesIsolation' ./...` -> ok
- full suite: `go test -count=1 ./...` -> FAIL only at web_ui_test.go:264 TestUISemantics (R-1, owned by U02/T0102); all API tests pass.
- go vet ./... -> ok
- fixed_confirmed: true (unit scope). R-1 is external to U01 and tracked in coverage-audit.
