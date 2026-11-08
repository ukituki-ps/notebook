# Unit verify — notebook-search-api (U01)

- **Execution:** E0809-s20.sde_5fexecution-u01 (child of E0809)
- **Step:** s13.unit_verify
- **Unit:** notebook-search-api · domain notebook-api · plain
- **Branch:** `orc-exec-E0809-s20.sde_5fexecution-u01`
- **Base:** `f5943f5` · **Verified HEAD:** `a799630`
- **verified_by:** architect session (independent reviewer; executor was `sde-backend`)
- **Date:** 2026-11-08
- **Verdict:** **pass**

## 1. Diff review

`git diff --stat f5943f5..HEAD`:

```
 artifacts/units/notebook-search-api/unit-plan.md   |  60 +++++---
 .../units/notebook-search-api/check-report.md"     |   6 +
 .../units/notebook-search-api/execution-report.md" | 171 +++++++++++++++++++++
 .../units/notebook-search-api/plan.md"             |  50 ++++++
 main_test.go                                       |  52 +++++++
 5 files changed, 321 insertions(+), 18 deletions(-)
```

- `git diff f5943f5..HEAD -- main.go` → **0 lines** (production handler unchanged).
- `git diff --name-only f5943f5..HEAD -- web design frontend` → **empty** (no UI/DS edits).
- Only executable change: `main_test.go` **+52 / -0**.
- `git status --short` → clean; the reviewed content is committed at `a799630`.

## 2. Contract checklist (`spec/core.md` §1.1)

| Requirement | Implementation evidence | Independent result |
|---|---|---|
| Auth before method/query handling | `main.go:531-534` (`requireAuth` first); `main.go:450-459` sets `WWW-Authenticate: Bearer` | PASS / mutation-tested |
| Decode `q` (`r.URL.Query().Get`) | `main.go:541` | PASS |
| 512-byte cap on decoded value, before any scan | `main.go:542-545` returns `400 {"error":"query too long"}` above `ListNotes` at `main.go:547` | PASS / mutation-tested |
| Exactly 512 bytes accepted; bytes not runes | `>` (not `>=`) at `main.go:542`; multibyte fixture | PASS / mutation-tested |
| Cap evaluated before trim (whitespace-only >512 → 400) | cap `541-545` precedes `TrimSpace` `546` | PASS / mutation-tested |
| `TrimSpace`; absent/empty/whitespace → all own notes | `main.go:546`; empty match passes full owner-scoped slice | PASS |
| Case-insensitive substring, `ToLower` both sides | `main.go:546,551` | PASS / mutation-tested |
| Owner predicate first; `q` narrows, never widens | `ListNotes(session.UserID)` `main.go:547`; store filter `main.go:193-206`; text filter `548-556` | PASS / mutation-tested |
| No match → `200 []`, never `null` | non-nil slice `main.go:198` | PASS / mutation-tested |
| `UserID` not serialized; wire keys `id`/`text` | `Note` `main.go:67-71` (`json:"-"` on `UserID`) | PASS / mutation-tested |

## 3. Are the new tests real and can they fail?

Each check below was run on a **throwaway copy under `/tmp`** with a single
deliberate regression; the workspace itself was never modified.

| # | Mutation | Expected detection | Observed |
|---|---|---|---|
| M1 | cap `>` → `>=` | exactly-512 accept fails | `--- FAIL: TestNotesSearchQueryTooLong` at `main_test.go:1135` (`exactly max query: 400`) |
| M2 | cap moved after `TrimSpace` | 513-space query fails | `--- FAIL: TestNotesSearchQueryTooLong` at `main_test.go:1125` (got `200` + notes) |
| M3 | cap checked before auth | unauthenticated oversized `q` fails | `--- FAIL: TestNotesSearchAuthRequired` at `main_test.go:1037` (`400` instead of `401`) |
| M4 | owner predicate removed from `ListNotes` | isolation fails | `--- FAIL: TestNotesSearchIsolation` at `main_test.go:988` (2 notes, want 1) |
| M5 | `strings.ToLower(note.Text)` removed | case-insensitive search fails | `--- FAIL: TestNotesSearchCaseInsensitive` at `main_test.go:973` |
| M6 | empty result slice made `nil` | `[]` vs `null` fails | `--- FAIL: TestWireContract` at `main_test.go:700` (`"null"`) |
| M7 | `UserID` tag changed to `json:"userId"` | wire schema fails | `--- FAIL: TestWireContract` at `main_test.go:679` (3 keys, want 2) |

New coverage is functional, not decorative: exactly-512 accept seeds and matches
a 512-byte note; the multibyte case uses 256 × `ж` (512 bytes, accepted) and
257 × `ж` (514 bytes, rejected); the auth case sends a 513-byte `q` with no
token and asserts `401` + `WWW-Authenticate: Bearer` + body.

## 4. Commands and results (this reviewer, `/workspace/projects/notebook`)

| Command | Result |
|---|---|
| `go build ./...` | `BUILD_OK` |
| `go vet ./...` | `VET_OK` |
| `gofmt -l .` | no output |
| `go test -count=1 -run 'TestNotesSearch' -v ./...` | **9/9 PASS**, `ok ... 0.435s` |
| `go test -count=1 -v ./...` | **32 PASS / 1 FAIL**, exit 1; only `TestUISemantics` (`web_ui_test.go:264`) |
| `go test -count=1 -skip 'TestUISemantics' ./...` | `ok`, exit 0 |

The nine `TestNotesSearch*` tests: Finds, NotFound, CaseInsensitive,
Isolation, AuthRequired, EmptyQuery, WhitespaceQuery, Encoding, QueryTooLong —
all PASS.

## 5. No auth / persistence / wire changes

Confirmed by the empty `main.go` diff: `requireAuth`, bearer parsing, session
store, 401 path, `Store`/`ListNotes`/`AddNote`/`DeleteNote`, the `Note` model,
and the response envelope are byte-identical to the base. `web/`, `design/`,
`frontend/`, E2E and `go.mod` are untouched; no dependency added.

## 6. Caveat — R-1 (external)

The full suite has one pre-existing failure, `TestUISemantics` at
`web_ui_test.go:264` (`app.css missing "min-height: 44px"`), caused by
`web/app.css` using `min-height: var(--control-height)` (value `44px`). It is
documented as **R-1** in `spec/core.md` §3.6, belongs to the UI unit
**U02/T0008/T0102**, and is out of scope for this backend unit; neither
`web/app.css` nor `web_ui_test.go` is in the reviewed diff. The API suite is
green with it excluded.

No residual risk inside unit scope.
