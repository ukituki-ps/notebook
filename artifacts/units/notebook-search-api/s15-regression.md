# s15 regression — notebook-search-api

- Feature: `f-v4-note-search`
- Execution: `E8363-s20.sde_5fexecution-u01`
- Unit: `notebook-search-api`
- Worktree: `/workspace/projects/notebook-e8363-u01`
- Branch: `orc-exec-E8363-s20.sde_5fexecution-u01`
- HEAD audited: `f6396ad42f913b4fba70882d2dbba66e03f48515`
- Auditor: independent (read-only; no git write commands)
- Date: 2026-11-06 (UTC)

## Verdict: PASS — no regression, no out-of-scope source change

## Regression commands and results

Run from the worktree root, toolchain `go1.24.4 linux/amd64`.

| # | Command | Exit | Result |
|---|---|---|---|
| 1 | `go test -count=1 ./...` | `0` | `ok github.com/ukituki-ps/notebook 2.732s` — full suite |
| 2 | `go test -count=1 -run '^TestAuthRequired$' ./...` | `0` | PASS |
| 3 | `go test -count=1 -run '^TestNotesIsolation$' ./...` | `0` | PASS |
| 4 | `go test -count=1 -run '^TestNotesMethodNotAllowed$' ./...` | `0` | PASS |
| 5 | `go test -count=1 -run '^TestWireContract$' ./...` | `0` | PASS |
| 6 | `go test -count=1 -run '^TestHTTPTransport$' ./...` | `0` | PASS |
| 7 | combined `-v` regression group (15 tests, see below) | `0` | 15/15 PASS, `ok ... 0.730s` |

Combined focused group (`-v`,
`TestAuthRequired|TestNotesIsolation|TestNotesMethodNotAllowed|TestWireContract|TestHTTPTransport|TestAuthMethodOrder|TestNotesSearch*|TestUISemantics`):

```
--- PASS: TestNotesMethodNotAllowed
--- PASS: TestAuthRequired
--- PASS: TestNotesIsolation
--- PASS: TestWireContract
--- PASS: TestHTTPTransport
--- PASS: TestAuthMethodOrder
--- PASS: TestNotesSearchFinds
--- PASS: TestNotesSearchNotFound
--- PASS: TestNotesSearchCaseInsensitive
--- PASS: TestNotesSearchIsolation
--- PASS: TestNotesSearchAuthRequired
--- PASS: TestNotesSearchEmptyQuery
--- PASS: TestNotesSearchWhitespaceQuery
--- PASS: TestNotesSearchEncoding
--- PASS: TestUISemantics
PASS
ok  github.com/ukituki-ps/notebook  0.730s
```

The full suite also covers registration/login, note create/delete, delete error
envelopes, token expiry/no-leak/password hashing, prefix boundaries, and the
unknown-API 404 path; all green.

## Out-of-scope check

- Worktree source status vs HEAD: **clean** — only `artifacts/units/**` files
  differ (executor/verification records); no source file is dirty.
- Branch delta vs feature base `9ceafdb` (committed):
  `s10-unit-plan.md` (A), `s11-execution.md` (A), `s12-check.md` (M) —
  artifact files only.
- Feature code delta (base `dev/f-v3-auth-notes` → `9ceafdb`/validation-zero)
  for unit u01: `main.go`, `main_test.go` — **exactly the allowed scope**.
- `main.go` delta is additive handler-local filtering; `main_test.go` delta is
  `+183` lines of new search tests (no existing test modified or weakened).
- No dependency, `go.mod`, deploy, package, or spec/source out-of-scope change.

## Regression/out-of-scope findings

None. No new findings.

## Residual risk

- Live browser E2E for the API contract is covered indirectly by Go
  `httptest` transport tests; the browser path is owned by u02/u03 and s20c.
- `strings.ToLower` is not a locale/collation guarantee; the brief explicitly
  scopes matching to ASCII case-insensitivity.
