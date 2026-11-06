# s13 independent verification — notebook-search-api

- Feature: `f-v4-note-search`
- Execution: `E8363-s20.sde_5fexecution-u01`
- Unit: `notebook-search-api`
- Worktree: `/workspace/projects/notebook-e8363-u01`
- Branch: `orc-exec-E8363-s20.sde_5fexecution-u01`
- HEAD tested (commands executed at): `f6396ad42f913b4fba70882d2dbba66e03f48515`
- Branch tip at report time: `94daa77202623290dd7067ab001f7d69102703a9`
  (`chore(notebook-search-api): s15 independent regression (E8363)`, artifacts
  only; `git diff f6396ad..94daa77 -- main.go main_test.go web web_ui_test.go`
  is empty)
- Evidence HEAD in `s13-verify-input.md`: `9ceafdbd1bede428097d784539093092d0c9156f`
- Source equivalence: `git diff --stat 9ceafdb..HEAD` contains only
  `artifacts/units/notebook-search-api/{s10,s11,s12,s15}`; `main.go` and
  `main_test.go` are byte-identical to the evidence HEAD.
- Verified by: `architect` (independent verifier; read-only source inspection,
  fresh local commands, no git write commands)
- Toolchain: `go1.24.4 linux/amd64`
- Verdict: **PASS**

## Commands reproduced

| # | Command (cwd = worktree) | Exit | Result |
|---|---|---|---|
| 1 | `go build ./...` | `0` | no output |
| 2 | `go vet ./...` | `0` | no output |
| 3 | `go test -count=1 ./...` | `0` | `ok github.com/ukituki-ps/notebook 2.736s` |
| 4 | `go test -count=1 -run 'TestNotesSearch' -v ./...` | `0` | 8/8 PASS, `ok ... 0.377s` |
| 5 | `go test -count=1 -v -run 'TestAuthMethodOrder\|TestAuthRequired\|TestNotesIsolation\|TestNotesMethodNotAllowed\|TestWireContract\|TestHTTPTransport\|TestUISemantics' ./...` | `0` | 7/7 PASS, `ok ... 0.361s` |

Focused search output:

```
--- PASS: TestNotesSearchFinds
--- PASS: TestNotesSearchNotFound
--- PASS: TestNotesSearchCaseInsensitive
--- PASS: TestNotesSearchIsolation
--- PASS: TestNotesSearchAuthRequired
--- PASS: TestNotesSearchEmptyQuery
--- PASS: TestNotesSearchWhitespaceQuery
--- PASS: TestNotesSearchEncoding
PASS
ok  github.com/ukituki-ps/notebook  0.377s
```

## Contract checks (independent code read)

1. **Query parsing/trimming** — `query := strings.ToLower(strings.TrimSpace(r.URL.Query().Get("q")))`
   in `main.go:538`; `q` is read via `r.URL.Query().Get("q")`.
2. **Absent / `q=` / whitespace-only** — the filter block is guarded by
   `if query != ""` (`main.go:540`), so all three return the unfiltered
   `ListNotes(session.UserID)` result; `TestNotesSearchEmptyQuery` also asserts
   the body is byte-identical to the no-`q` response, and
   `TestNotesSearchWhitespaceQuery` covers `%20%20%09` and `%20`.
3. **Case-insensitive substring** — both query (`main.go:538`) and each note text
   (`main.go:543`) are lower-cased and compared with `strings.Contains`;
   `TestNotesSearchCaseInsensitive` (`q=HeLLo` → `Hello World`, `hello there`).
4. **Owner predicate first** — `notes := a.store.ListNotes(session.UserID)`
   (`main.go:539`) runs before filtering; `ListNotes` (`main.go:194-205`) selects
   only `note.UserID == userID`, so `q` can only narrow. `TestNotesSearchIsolation`
   proves A/B separation with a shared query.
5. **No match → `200 []`** — `ListNotes` returns `make([]Note, 0)` and the filter
   returns `make([]Note, 0, len(notes))` (`main.go:540-548`).
   `TestNotesSearchNotFound` asserts the exact trimmed body `[]`.
6. **Auth order** — `handleNotes` calls `a.requireAuth(w, r)` before the method
   switch (`main.go:529-534`); `requireAuth` sets `WWW-Authenticate: Bearer` and
   `401 {"error":"unauthorized"}`. Covered by `TestNotesSearchAuthRequired`
   (no token and unknown token) and `TestAuthMethodOrder`.
7. **Wire/envelope stability** — `Note.UserID` is `json:"-"` (`main.go:66-70`);
   `TestNotesSearchIsolation` also rejects `user_id` / `UserID` / `"userId"`
   substrings. Existing status/envelope paths stay green through
   `TestNotesMethodNotAllowed`, `TestWireContract`, `TestHTTPTransport`.
8. **Real transport** — all search oracles go through `newTestServer` /
   `httptest.Server` (`main_test.go:17-37`), not direct `Store` calls.
9. **Encoding safety** — `TestNotesSearchEncoding` exercises `100%25`,
   `100%25%20juice`, `%26`, and `a%2Bb`, all returning `200` with the expected
   note; no panic/500.

## Test inventory

- `main_test.go`: 31 top-level tests, of which 8 are `TestNotesSearch*` (exact
  count `grep -c '^func TestNotesSearch'` = 8).
- `web_ui_test.go`: 1 test (`TestUISemantics`).
- No build tags and no `t.Skip` in `main_test.go` / `web_ui_test.go`
  (`grep -nE '^//go:build|t\.Skip'` = 0 matches).

## Notes

- No source file was modified; only these s13/s14/s16 records were written by
  the verifier.
- One non-blocking oracle nuance: `spec/contract-matrix.md` C-08 names raw `+`
  (space) while `TestNotesSearchEncoding` covers `%20` (space) and `%2B`
  (literal plus). The decoding path is shared `net/http` behavior and is not a
  code defect; recorded in `s14-quality.md`.
- No FAIL and no blocking finding.
