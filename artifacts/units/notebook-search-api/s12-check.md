# s12 unit check — notebook-search-api

- Feature: `f-v4-note-search`
- Execution: `E8363-s20.sde_5fexecution-u01`
- Unit: `notebook-search-api`
- Worktree: `/workspace/projects/notebook-e8363-u01`
- Branch: `orc-exec-E8363-s20.sde_5fexecution-u01`
- Checked HEAD: `9ceafdbd1bede428097d784539093092d0c9156f`
- Toolchain: `go1.24.4 linux/amd64`

## Result: PASS

## Build / vet / test

| Command | Exit | Output |
|---|---|---|
| `go build ./...` | `0` | no output |
| `go vet ./...` | `0` | no output |
| `go test -count=1 ./...` | `0` | `ok github.com/ukituki-ps/notebook 2.749s` |
| `go test -count=1 -run 'TestNotesSearch' -v ./...` | `0` | 8/8 PASS, `ok ... 0.379s` |
| targeted guard suite (`-v`) | `0` | 15/15 PASS, `ok ... 0.734s` |

Top-level test inventory: 31 tests in `main_test.go` + 1 in `web_ui_test.go`
(32 total). Search tests: 8 (`grep -c '^func TestNotesSearch' main_test.go`).

## Contract check

- `q` read via `r.URL.Query().Get("q")` and `strings.TrimSpace` — `main.go:538`.
- Empty/whitespace query leaves `ListNotes(session.UserID)` unchanged —
  `main.go:538–548`.
- Case-insensitive substring filter via `strings.ToLower` on query and note text
  — `main.go:538, 543`.
- Owner predicate first: `ListNotes` selects `note.UserID == userID` and the
  handler filters its result — `main.go:194–205, 539–548`.
- Empty result is `[]`, not `null`: `make([]Note, 0)` in `ListNotes` and
  `make([]Note, 0, len(notes))` in the filter — asserted by
  `TestNotesSearchNotFound` (`strings.TrimSpace(res.body) == "[]"`).
- Auth before method/query: `requireAuth` runs before the switch —
  `main.go:530–534`; pinned by `TestNotesSearchAuthRequired` and
  `TestAuthMethodOrder`.
- Envelope/status unchanged for existing paths: `TestNotesMethodNotAllowed`,
  `TestWireContract`, `TestHTTPTransport`, `TestNotesIsolation` pass.
- `UserID` not serialized (`json:"-"`) and explicitly checked in
  `TestNotesSearchIsolation` for `user_id` / `UserID` / `"userId"` substrings.

## Search test evidence

- `TestNotesSearchFinds` — substring find.
- `TestNotesSearchNotFound` — exact `[]` body, `200`.
- `TestNotesSearchCaseInsensitive` — `q=HeLLo` matches `Hello World` and
  `hello there`.
- `TestNotesSearchIsolation` — A/B `q=shared` isolation + no `UserID` leak.
- `TestNotesSearchAuthRequired` — no token and unknown token → `401` +
  `WWW-Authenticate: Bearer`.
- `TestNotesSearchEmptyQuery` — `q=` output byte-equal to unfiltered output.
- `TestNotesSearchWhitespaceQuery` — `%20%20%09` and `%20` return all own notes.
- `TestNotesSearchEncoding` — `%25`, `%20`, `%26`, `%2B` decoded and matched.

## Verdict

PASS. No source change required. All in-scope clauses are implemented and
oracle-backed at HEAD; no regression observed.
