# s15 — REGRESSION: notebook-search-api (U01)

- **Execution:** `E0809-s20.sde_5fexecution-u01` (parent `E0809`)
- **Step:** `s15.unit_regression` · **Unit:** `notebook-search-api` (domain `notebook-api`)
- **Branch:** `orc-exec-E0809-s20.sde_5fexecution-u01`
- **Base:** `f5943f5` · **Reviewed HEAD:** `506dc8a` (== `origin/orc-exec-E0809-s20.sde_5fexecution-u01`)
- **Auditor session:** `ses_e4438a87fffeyy6huTcLWCXF0g` (role `auditor`, independent; run `c85a0714-39fe-41b5-959b-3ac8b4841925`)
- **Date:** 2026-11-08
- **regression_status:** **pass**
- **new_findings:** `[]`

```json
{ "new_findings": [] }
```

## 1. Verdict

No regression was found in auth, isolation, wire contract, delete/add, or the
web/design surface. The unit introduces **no production-code change**: the
diff `f5943f5..HEAD` contains only `main_test.go` (+52/−0) and unit docs, and
`main.go` has a **zero-line** diff against the base. Runtime behaviour is
therefore byte-identical to the base; the added tests are additive oracle
coverage, not a behaviour change.

R-1 (`TestUISemantics` / `app.css` missing literal `min-height: 44px`) is
**pre-existing and external** (U02). It is reported below only as a known
external condition, **not** as a new finding.

## 2. Diff scope (independent)

```
$ git diff --name-status f5943f5..HEAD
M	artifacts/units/notebook-search-api/unit-plan.md
A	doc/.../units/notebook-search-api/check-report.md
A	doc/.../units/notebook-search-api/execution-report.md
A	doc/.../units/notebook-search-api/plan.md
A	doc/.../units/notebook-search-api/quality.md
A	doc/.../units/notebook-search-api/verify.md
M	main_test.go

$ git diff --numstat f5943f5..HEAD -- main.go
(empty)                       # 0 production lines changed

$ git diff --stat f5943f5..HEAD -- web design frontend web_ui_test.go package.json playwright.config.js
(empty)                       # no web/design/e2e changes
```

The search implementation itself (`main.go`, commits `adccfcc`, `e0d41a0`) is
an ancestor of the unit base, as already documented in `execution-report.md`;
the unit's own delta is test hardening only.

## 3. Commands and results

All commands run from `/workspace/projects/notebook`, Go `go1.24.4 linux/amd64`.

| # | Command | Exit | Result |
|---|---|---|---|
| 1 | `go build ./...` | 0 | build OK |
| 2 | `go vet ./...` | 0 | vet OK |
| 3 | `gofmt -l .` | 0 | no output (formatted) |
| 4 | `go test -count=1 -run 'TestNotesSearch' ./...` | 0 | `ok ... 0.458s` — 9/9 PASS |
| 5 | `go test -count=1 -run 'TestAuthRequired\|TestAuthMethodOrder\|TestTokenExpiry\|TestNotesIsolation\|TestDeleteForeignNote\|TestWireContract\|TestDeleteNote\|TestAddNote\|TestListAfterDelete\|TestNotesLifecycle\|TestDeleteMissing\|TestDeleteExisting\|TestNotesMethodNotAllowed\|TestNotesPrefixBoundary' -v ./...` | 0 | 14/14 PASS |
| 6 | `go test -count=1 ./...` | **1** | FAIL **only** `TestUISemantics` (`web_ui_test.go:264`: `app.css missing "min-height: 44px"`) |
| 7 | `go test -count=1 -skip 'TestUISemantics' ./...` | 0 | `ok ... 2.860s` — whole suite green minus external R-1 |
| 8 | base-tree control: archive `f5943f5`, `go test -count=1 -run TestUISemantics ./...` | **1** | same failure at base → R-1 is pre-existing, not unit-caused |

`TestNotesSearch*` detail (command 4): Finds, NotFound, CaseInsensitive,
Isolation, AuthRequired, EmptyQuery, WhitespaceQuery, Encoding, QueryTooLong —
all PASS.

Full-suite count (command 6): 32 tests pass, 1 fails (`TestUISemantics` only).
The failure exists identically on the untouched base tree (command 8), matching
the documented external R-1 owned by U02/T0008/T0102.

No test was skipped, renamed, weakened, or build-tagged by this unit:

```
$ grep -nE 'go:build|t\.Skip|testing\.Short' main_test.go web_ui_test.go
none
```

## 4. Regression matrix

| Area | Check | Evidence | Result |
|---|---|---|---|
| **Auth** | unauth and bad-token `GET /api/notes` and `GET /api/notes?q=` → `401` + `WWW-Authenticate: Bearer` + `{"error":"unauthorized"}`; auth precedes the 512-byte cap | `TestAuthRequired`, `TestNotesSearchAuthRequired` (incl. oversized-q → 401), `TestAuthMethodOrder`, `TestTokenExpiry` | PASS |
| **Isolation** | `ListNotes(session.UserID)` runs before the text predicate; `q` narrows, never widens; B's note never appears in A's search; `UserID` not serialized | `TestNotesIsolation`, `TestNotesSearchIsolation`, `TestDeleteForeignNote` | PASS |
| **Wire contract** | notes are `{"id":N,"text":"..."}` (`UserID` `json:"-"`); empty result is `[]`, never `null`; errors use `{"error":"..."}` | `TestWireContract`, `TestNotesSearchNotFound`, `TestNotesSearchIsolation`, `TestHTTPTransport` | PASS |
| **Delete/add** | `POST /api/notes` → 201; `DELETE` own → 204; foreign/missing → 404; list-after-delete intact; prefix/invalid ids → 400 | `TestAddNote`, `TestNotesLifecycle`, `TestDeleteNote`, `TestDeleteForeignNote`, `TestDeleteMissing`, `TestDeleteExisting`, `TestListAfterDelete`, `TestNotesPrefixBoundary` | PASS |
| **Web/design** | zero diff for `web/`, `design/`, `frontend/`, `web_ui_test.go`, `package.json`, `playwright.config.js` | `git diff --stat f5943f5..HEAD -- …` empty | PASS |
| **Production code** | `main.go` zero diff vs base | `git diff --numstat f5943f5..HEAD -- main.go` empty | PASS |

## 5. Residual risks

1. **R-1 (external, pre-existing).** `TestUISemantics` fails at `web_ui_test.go:264`
   because `web/app.css` uses `min-height: var(--control-height)` instead of the
   literal `min-height: 44px` the oracle expects. Reproduced on the untouched
   base `f5943f5`; owned by U02/T0008/T0102. **Not** attributable to this unit and
   **not** counted as a new finding.
2. **Malformed `q` encoding (pre-existing, low).** `r.URL.Query().Get("q")`
   silently drops an unparsable query pair (e.g. `q=%zz`), so such a request is
   treated as "no query" and returns `200` with all own notes instead of `400`.
   This is net/http baseline behaviour, present at the unit base, outside the
   spec's 512-byte contract, and unchanged by the unit. Not a regression.
3. **Scope of the unit.** Because the production handler predates the unit base,
   this unit cannot exercise a production diff; its regression value is the
   added oracle coverage over the existing contract. This matches the recorded
   execution report and the verify/quality/spec-sync findings.
4. **Performance shape (unchanged).** Search remains `O(notes × text)` per
   request; the cap bounds only `q`, not the note count. Acceptable for the
   in-memory service and identical to base behaviour; no regression.
5. **Stale pre-existing artifact (documentation only).**
   `artifacts/units/notebook-search-api/s15-regression.md` is a tracked stub
   from an earlier execution (`E1546` era, unchanged in this diff) and claims a
   clean full-suite run without the R-1 caveat. Downstream steps should treat
   **this** document as the current s15 evidence; the stale artifact is not a
   code regression and is not counted as a new finding.

## 6. Context source

- ORC context package read via `orc_ctx` (project `f41f0adb-67d9-4ddf-8ba9-0efd9c6e50a9`,
  step `s15.unit_regression`), plus direct inspection of `main.go`,
  `main_test.go`, unit docs, and the git diff `f5943f5..HEAD`.
- No code changes and no commit were made at this step (verify-only).
