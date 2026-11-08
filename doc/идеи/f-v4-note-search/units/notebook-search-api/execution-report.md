# Execution report — notebook-search-api (U01)

- **Execution:** E0809-s20.sde_5fexecution-u01 (child)
- **Step:** s11.unit_execution
- **Unit:** notebook-search-api · domain notebook-api · sde-backend · change_class plain
- **Branch:** `orc-exec-E0809-s20.sde_5fexecution-u01`
- **Base:** `7ff3204` (`docs(u01): unit plan notebook-search-api`)
- **Scope files:** `main.go`, `main_test.go`
- **Commit:** not made — coordinator commits.

## Result

`main.go` already implements the `spec/core.md` §1 `GET /api/notes?q=` contract
(auth → decode → 512-byte cap → trim → owner-scoped `ListNotes` → case-insensitive
substring → `[]` not `null`), so no production change was required. The missing
invariant coverage was added to `main_test.go`. No test was weakened or renamed,
and no build tags were added.

## Files changed

| File | Change |
|---|---|
| `main_test.go` | +52 lines: extended `TestNotesSearchAuthRequired` (auth before the query cap) and `TestNotesSearchQueryTooLong` (whitespace-only >512 → 400, exactly-512 accept, bytes-not-runes accept/reject). Added `net/url` import for multibyte query encoding. |

`main.go`: **unchanged**. `web/`, `design/`, e2e, auth, sessions, persistence and
the wire schema: **unchanged**.

## Contract verification (spec/core.md §1)

| Requirement | Where | Covered by |
|---|---|---|
| `TrimSpace(q)`; empty/whitespace → all own notes | `main.go:546` | `TestNotesSearchEmptyQuery`, `TestNotesSearchWhitespaceQuery` |
| Case-insensitive substring (`strings.ToLower` both sides) | `main.go:546,551` | `TestNotesSearchFinds`, `TestNotesSearchCaseInsensitive` |
| Owner predicate before text predicate; `q` narrows, never widens | `main.go:547-556` | `TestNotesSearchIsolation` |
| 512-byte cap on decoded value, bytes not runes, before trim/scan | `main.go:541-545` (cap) precedes `main.go:547` (`ListNotes`) | `TestNotesSearchQueryTooLong` |
| `>512` → `400 {"error":"query too long"}` | `main.go:542-544` | `TestNotesSearchQueryTooLong` |
| Exactly 512 bytes accepted (single-byte and multibyte) | `main.go:542` (`>` not `>=`) | `TestNotesSearchQueryTooLong` (new) |
| `>512` whitespace-only → `400` before scan (cap precedes trim) | `main.go:541-546` | `TestNotesSearchQueryTooLong` (new) |
| Auth (401 + `WWW-Authenticate: Bearer`) before method/query, incl. oversized `q` | `main.go:531-534` | `TestNotesSearchAuthRequired` (new case), `TestAuthMethodOrder` |
| No match → `200 []`, never `null` | `ListNotes`/filtered slice are non-nil | `TestNotesSearchNotFound`, `TestNotesSearchEmptyQuery` |
| `UserID` not serialized; wire keys `id`/`text` | `Note.UserID json:"-"` | `TestNotesSearchIsolation`, `TestWireContract` |

The "before scan" guarantee is structural: the `len(rawQuery) > maxQueryBytes`
check and its `writeErr` return sit above `a.store.ListNotes(session.UserID)`;
the oversized branch returns without touching the store.

## Commands and results

All commands run from `/workspace/projects/notebook` on the unit branch.

### `gofmt -l .`

```
(no output)
EXIT:0
```

### `go build ./...`

```
BUILD_OK
```

### `go vet ./...`

```
VET_OK
```

### `go test -count=1 -run 'TestNotesSearch' -v .`

```
=== RUN   TestNotesSearchFinds
--- PASS: TestNotesSearchFinds (0.05s)
=== RUN   TestNotesSearchNotFound
--- PASS: TestNotesSearchNotFound (0.05s)
=== RUN   TestNotesSearchCaseInsensitive
--- PASS: TestNotesSearchCaseInsensitive (0.05s)
=== RUN   TestNotesSearchIsolation
--- PASS: TestNotesSearchIsolation (0.10s)
=== RUN   TestNotesSearchAuthRequired
--- PASS: TestNotesSearchAuthRequired (0.00s)
=== RUN   TestNotesSearchEmptyQuery
--- PASS: TestNotesSearchEmptyQuery (0.05s)
=== RUN   TestNotesSearchWhitespaceQuery
--- PASS: TestNotesSearchWhitespaceQuery (0.05s)
=== RUN   TestNotesSearchEncoding
--- PASS: TestNotesSearchEncoding (0.05s)
=== RUN   TestNotesSearchQueryTooLong
--- PASS: TestNotesSearchQueryTooLong (0.05s)
PASS
ok  	github.com/ukituki-ps/notebook	0.436s
```

9/9 `TestNotesSearch*` pass.

### `go test -count=1 -v .`

```
PASS_COUNT:32
FAIL_COUNT:1
--- FAIL: TestUISemantics (0.00s)
FAIL	github.com/ukituki-ps/notebook	2.816s
```

32 tests pass, 1 fails: `TestUISemantics` at `web_ui_test.go:264`
(`app.css missing "min-height: 44px"`). This failure is **pre-existing on the
untouched base commit** and is the documented base blocker **R-1** in
`spec/core.md` §3.6: the oracle expects a literal `min-height: 44px` while
`web/app.css` uses `min-height: var(--control-height)` (`--control-height: 44px`).
It belongs to the UI unit **U02/T0008**, is out of scope for this backend unit,
and neither `web/app.css` nor `web_ui_test.go` was modified here
(`git status` shows only `main_test.go`).

### `go test -count=1 -skip 'TestUISemantics' ./...`

```
ok  	github.com/ukituki-ps/notebook	2.805s
EXIT:0
```

Whole suite green once the pre-existing, out-of-scope UI oracle is excluded.

## Diff summary

```
 main_test.go | 52 ++++++++++++++++++++++++++++++++++++++++++++++++++++
 1 file changed, 52 insertions(+)
```

New test coverage:

- `TestNotesSearchAuthRequired`: unauthenticated `GET /api/notes?q=<513 bytes>`
  returns `401` + `WWW-Authenticate: Bearer` + `{"error":"unauthorized"}`
  (auth wins over the `400 query too long` cap).
- `TestNotesSearchQueryTooLong`:
  - `%20` × 513 decoded bytes → `400 {"error":"query too long"}` (whitespace-only,
    rejected before trim/scan);
  - exactly 512 `b` bytes → `200` and returns the seeded 512-byte note;
  - 256 × `ж` (512 bytes) → `200` and matches the seeded multibyte note;
  - 257 × `ж` (514 bytes) → `400 {"error":"query too long"}` (bytes, not runes).

## Explicit confirmations

- **Auth unchanged:** no edit to `requireAuth`, bearer parsing, session store, or
  the 401 path.
- **Persistence unchanged:** no edit to `Store`, `ListNotes`, `AddNote`,
  `DeleteNote`, or the data model.
- **Wire schema unchanged:** `Note` still serializes only `id`/`text`; `UserID`
  remains `json:"-"`.
- **Scope unchanged:** `web/`, `design/`, `e2e`, `go.mod` untouched; no new
  dependency added.

## Evidence list

| # | Command | Result |
|---|---|---|
| 1 | `gofmt -l .` | no output, exit 0 |
| 2 | `go build ./...` | success |
| 3 | `go vet ./...` | success |
| 4 | `go test -count=1 -run 'TestNotesSearch' -v .` | 9/9 PASS |
| 5 | `go test -count=1 -v .` | 32 PASS / 1 FAIL (`TestUISemantics`, pre-existing R-1) |
| 6 | `go test -count=1 -skip 'TestUISemantics' ./...` | `ok`, exit 0 |
| 7 | `git diff --stat` | only `main_test.go`, +52/-0 |
| 8 | `git status --short` | `M main_test.go` only |

## Handoff

Coordinator should commit `main_test.go` together with this report. The
`TestUISemantics` failure must be resolved by U02/T0008 per `spec/core.md` §3.6
and is not attributable to this backend unit.
