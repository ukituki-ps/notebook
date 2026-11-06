# Brief finalization — f-v4-note-search (s06.feature_brief_final)

- **Step:** `s06.feature_brief_final`
- **Execution:** `E8363`
- **Feature:** `f-v4-note-search`
- **Platform:** `web` (`path1.ui.json.platform = "web"`, `feature_profile = full`)
- **Branch (this pass):** `validation/platform-dev-20261106-zero`
- **Base SHA:** `5935e148584b5fef28bd77ac4e45b800f10da03b`
- **Platform under test:** `730d144a1e63837b590f3e95d01f67142ca3a699`
- **Pass type:** fresh re-validation. Only the finalization note of
  `feature-brief.md` was updated; all normative brief content is unchanged.

## Verdict

**PASS** — the brief is finalized for s07 traceability. Its API contract, search
semantics, UX, 10-state wireframes, acceptance criteria and invariant summary
still match the raw request and the E8363 s01–s05 re-validation. `invariants.json`
satisfies the s06 gate: 18 invariants, 16 active with executable `test_ref`, and
the core UI set at the correct status.

## Inputs reviewed

All paths relative to `/workspace/projects/notebook-valzero/`.

| Input | Role | Observed state |
|---|---|---|
| `doc/идеи/f-v4-note-search/feature-brief.md` | Final brief (s06, subject) | FINAL; API table, search semantics, UX, 10-state wireframes (s03, revalidated for E8363), AC 1–6, invariants, risks |
| `doc/идеи/f-v4-note-search/invariants.json` | Machine-readable invariants | 18 entries: 16 active, 2 proposed; all active have `test_ref`; search + UI sets present |
| `doc/идеи/f-v4-note-search/expertise-report.md` | Prior architect validation (s05) | B-1…B-9; OD-1/OD-2 closed; interface freeze; no blocking finding |
| `doc/идеи/f-v4-note-search/platform-dev-validation-zero/s05-architect-validation.md` | E8363 architect re-validation | PASS; 10 constraints hold; OD-1…OD-8 recorded, OD-6 needs-human (low); D-1…D-9 drift findings non-blocking |

Supporting cross-checks (read-only): `feature-request.md`,
`scope-report.md`, `UI-GRAPH.yaml`, `s01-product-review.md`,
`s02-scope-review.md`, `s03-proto-review.md`, `s04-graph-review.md`,
`spec/core.md`, `main_test.go`, `web_ui_test.go`,
`deploy/path1/e2e-preview.sh`.

## Brief change made at this step

Only the `## Finalization note (s06)` section changed. It now records:

- execution **E8363** and the fresh re-validation on platform `730d144a`
  with no platform/path-1 changes;
- the **10-state** wireframe schema (login, register, idle/list, filtering,
  search-results, search-empty, genuinely-empty, loading, error, unauthorized);
- the accurate invariant summary (16 active + 2 proposed, all active have an
  executable `test_ref`, proposed stay proposed until s22a/s20c);
- OD-6 carried to s08 as needs-human (low), not made contractual;
- the historical s06/E9294 finalization against `expertise-report.md`
  (`c1cf18c`), without re-stamping prior artifacts.

No API/UX/AC/wireframe text was modified.

## Invariants verification

Counts from `invariants.json`:

| Status | Count |
|---|---|
| active | **16** |
| proposed | **2** |
| **total** | **18** |

Gate `gate-invariant-present`: `invariants_key: invariants`, `min: 1`,
`require_test_ref_for: active` — **PASS** (18 ≥ 1; 16/16 active have `test_ref`).

### Active invariants and test_ref resolution

| Invariant | test_ref | Ref resolution |
|---|---|---|
| `INV-AUTH-REQUIRED` | `go test … -run 'TestAuthRequired\|TestNotesSearchAuthRequired'` | Both test funcs exist |
| `INV-USER-ISOLATION` | `go test … -run 'TestNotesIsolation\|TestNotesSearchIsolation'` | Both exist |
| `INV-SEARCH-OWNER-SCOPE` | `go test … -run 'TestNotesSearchIsolation'` | Exists |
| `INV-SEARCH-CASE-INSENSITIVE` | `go test … -run 'TestNotesSearchFinds\|TestNotesSearchCaseInsensitive'` | Both exist |
| `INV-SEARCH-EMPTY-Q` | `go test … -run 'TestNotesSearchEmptyQuery\|TestNotesSearchWhitespaceQuery'` | Both exist |
| `INV-SEARCH-NOT-FOUND` | `go test … -run 'TestNotesSearchNotFound'` | Exists |
| `INV-SEARCH-ENCODING` | `go test … -run 'TestNotesSearchEncoding'` | Exists |
| `INV-WIRE-CASING` | `go test … -run 'TestWireContract'` | Exists |
| `INV-REAL-TRANSPORT` | `go test … -run 'TestHTTPTransport\|TestNotesSearchEncoding'` | Both exist |
| `INV-NO-SKIP-TAGS` | `sh -c "! grep -R -E '^//go:build.*(integration\|e2e\|manual)' …"` | Runnable shell check |
| `INV-UI-TRUTH` | `go test … -run 'TestUISemantics'` | Exists |
| `INV-UI-LABEL` | `go test … -run 'TestUISemantics'` | Exists |
| `INV-UI-A11Y-NAME` | `go test … -run 'TestUISemantics'` | Exists |
| `INV-SEARCH-UI-FILTER` | `go test … -run 'TestUISemantics'` | Exists |
| `INV-SEARCH-UI-EMPTY` | `go test … -run 'TestUISemantics'` | Exists |
| `INV-SEARCH-UI-TESTIDS` | `go test … -run 'TestUISemantics'` | Exists |

Result: **16/16 active invariants have a non-empty, executable `test_ref`; 0
active invariants lack a ref; all referenced Go test functions exist in the
current tree.**

### Proposed invariants (must remain proposed)

| Invariant | test_ref | Why still proposed |
|---|---|---|
| `INV-UI-ORACLE` | `python3 tools/ui-audit-check.py --platform web --expect-sha <stand-sha>` | Oracle materializes at s22a; `tools/ui-audit-check.py` is not present in this authoring tree and `<stand-sha>` is a placeholder |
| `INV-UI-E2E-PREVIEW` | `bash deploy/path1/e2e-preview.sh` | Harness exists, but the E8363 stand/e2e-report/screenshot evidence is produced only at s20c |

Both remain **proposed**; neither was promoted at this step.

### Core UI invariant set — status check

| Invariant | Required status | Observed |
|---|---|---|
| `INV-UI-TRUTH` | active | active |
| `INV-UI-LABEL` | active | active |
| `INV-UI-A11Y-NAME` | active | active |
| `INV-SEARCH-UI-FILTER` | active | active |
| `INV-SEARCH-UI-EMPTY` | active | active |
| `INV-SEARCH-UI-TESTIDS` | active | active |
| `INV-UI-ORACLE` | proposed until s22a oracle | proposed |
| `INV-UI-E2E-PREVIEW` | proposed until s20c evidence | proposed |

Status assignment is correct; no UI invariant was prematurely promoted or
demoted.

## Result-schema fields (for ORC s06 acceptance)

- **change_class:** `plain`

### `do` — 5 items (source: brief "In scope")

1. `GET /api/notes?q=<text>` on the existing notes endpoint.
2. Case-insensitive substring search over note text.
3. Owner scoping: results always contain only the current user's notes.
4. Web UI search input, live list filtering, clear action, and dedicated
   `"ничего не найдено"` empty state.
5. Tests (Go + Playwright), preview on `test2`, UI graph actualization.

### `dont` — 6 items (source: brief "Out of scope" + raw-request constraints)

1. Do not change registration/login/session/token or auth guard order.
2. Do not change persistence/storage (notes stay in-memory) or the
   `POST /api/notes` / `DELETE /api/notes/{id}` contracts.
3. Do not change create/delete/reload behaviour or add a new lock/lock order.
4. Do not add runtime dependencies, a framework, or a bundler; do not roll back
   `package.json` / `package-lock.json`; Playwright stays 1.64.1.
5. Do not deploy to prod/main/stage, do not start canary, do not execute
   `s45.push_primary` / `s46.post_deploy_verify`.
6. Do not modify `f-v3-auth-notes`, `E4312`, `E1320`; no force/skip/waiver, no
   fake or self-signed evidence, no per-run artifact commits.

### `out_of_scope` — 5 items (source: brief "Out of scope")

1. Registration/login/session/token changes.
2. Persistence changes (notes stay in-memory).
3. Create/delete/reload behaviour changes.
4. Pagination, sorting, ranking, fuzzy matching, server-side highlighting.
5. Production/main/stage deployment and canary rollout (and non-web platforms:
   this feature is web-only).

### Counts summary

| Field | Count |
|---|---|
| `do` | **5** |
| `dont` | **6** |
| `out_of_scope` | **5** |
| `invariants` (active / proposed / total) | **16 / 2 / 18** |

`commit` / `evaluated_sha` are **not produced by this pass**: the step
instruction forbids git commands. The coordinator must commit and push the
brief + this review to `validation/platform-dev-20261106-zero` (descendant of
base `5935e148…`) and return that SHA as `commit` = `evaluated_sha`.

## Open questions

**No new open questions.** OD-1 (whitespace-only `q`) and OD-2 (client-side
filtering) remain closed and are reflected in the brief. The only carried human
decision is **OD-6** (query persistence across a full reload, low), already
recorded by s04/s05 and deferred to s08; it is not a contract item in this brief
and does not block finalization. The s05 drift findings D-1…D-9 remain
non-blocking and are unchanged.

## Limitations

- Per instruction, **no git commands were run**; all checks are against the
  working tree at this head, not a base diff. `commit`/`evaluated_sha` are
  therefore left to the coordinator.
- The ORC proof command `bash tools/path1-gate.sh test-ref-runnable` references a
  gate script not present in this authoring worktree; the test_ref check above
  was performed statically against the referenced test functions and shell
  commands.
- `expertise-report.md` and `invariants.json` still carry prior-run metadata
  (brief `a3d99d7`, graph `37648cb`, scope `41ae536`; `execution_id: E9294`).
  These are immutable prior artifacts and were intentionally not re-stamped.
- Only two files were written: the finalization note in `feature-brief.md` and
  this review. No other brief content, invariant, graph, spec, source, CSS, or
  path-1 file was modified.
