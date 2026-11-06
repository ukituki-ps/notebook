# Coverage audit review — f-v4-note-search (s17.coverage_audit)

- **Step:** `s17.coverage_audit`
- **Execution:** `E8363`
- **Feature:** `f-v4-note-search`
- **Platform:** `web` (`path1.ui.json.platform = "web"`, `feature_profile = full`)
- **Branch (this pass):** `dev/f-v4-note-search-validation-zero`
- **Base:** `5935e148` (`5935e148584b5fef28bd77ac4e45b800f10da03b`)
- **Pass type:** fresh E8363 coverage re-audit. Only `coverage-audit.md` and this
  review were written; `fault-verdicts.json` was inspected but not modified.

## Verdict

**PASS** — coverage is **45 / 45** raw-request items resolved with **0 gaps**,
all **10 / 10** task briefs (`T0001`–`T0010`) are present, and all **41 / 41**
contract rows (`C-01..C-30`, `U-01..U-11`) have an executable oracle. The fault
catalog has **20 ids: 15 covered, 5 `na`**, with evidence/justification and
`inherited_from` present where required. No verdict is wrong.

Residual findings are non-blocking documentation/trace precision issues, not
coverage gaps.

## Inputs reviewed

All paths relative to `/workspace/projects/notebook-valzero/`.

| Input | Role | Observation |
|---|---|---|
| `doc/идеи/f-v4-note-search/feature-request.md` | Immutable raw request | 45 numbered items; R01–R11 process, R12–R23 API/tests, R24–R30 UI, R31–R40 deploy/E2E, R41–R45 constraints |
| `doc/идеи/f-v4-note-search/intent-trace.json` | Machine trace | `execution_id: E8363`; 45 items; all `verdict: match`; `added: true` = 0; 1 open question (OD-6); every item has `decision_ref`/`scenario_ref` |
| `doc/идеи/f-v4-note-search/feature-brief.md` | Final brief | FINAL/s06; API contract, 10-state wireframes, AC 1–6, invariants; OD-6 not contractual |
| `doc/идеи/f-v4-note-search/change-definition.md` | Domain change definition | E8363; 5 domains; C1–C4 with before/after/files/acceptance; "Not in scope" matches R41–R45 and OD-6 |
| `doc/идеи/f-v4-note-search/spec/core.md` | Spec | 41 contract rows; handler-level filter over `ListNotes`; UI contract; invariants; drift 0 |
| `doc/идеи/f-v4-note-search/spec/contract-matrix.md` | Contract matrix | 30 API + 11 UI rows; every row has a Go/Playwright oracle |
| `doc/идеи/f-v4-note-search/plan.md` | Plan | 3 units, T0001–T0010; prior-run metadata E9294/406fa965 (see drift) |
| `doc/идеи/f-v4-note-search/M01/brief.md` | Milestone brief | E8363; T0001–T0010; search scope, 6 search E2E, OD-6 non-contractual |
| `doc/идеи/f-v4-note-search/T0001..T0010/brief.md` | Task briefs | 10/10 present; T0003 has stale details superseded by T0008/T0009 |
| `doc/идеи/f-v4-note-search/invariants.json` | Invariants | E8363; 16 active + 2 proposed; all active have `test_ref` |
| `doc/идеи/f-v4-note-search/fault-verdicts.json` | Fault catalog | 20 ids; 15 covered, 5 `na`; no missing evidence/justification; 10 inherited entries carry `inherited_from` |

Supporting cross-checks: `main_test.go`, `web_ui_test.go`,
`web/e2e/notes-search.spec.js`, `web/e2e/auth-notes.spec.js`,
`path1.project.json`, `s14-spec.md`.

## Coverage counts

| Metric | Result |
|---|---|
| Raw-request items resolved | **45 / 45** |
| Gaps | **0** (`gaps: []`) |
| Task briefs present | **10 / 10** (`T0001`–`T0010`), plus `M01` |
| Contract rows with oracle | **41 / 41** (30 API + 11 UI) |
| Contract drift | **0** |
| Fault catalog ids | **20** (15 covered, 5 `na`) |

## Coverage by raw-request area

| Area | Raw items | Resolving evidence |
|---|---|---|
| Process / constraints | R01–R11, R41–R45 | E8363 execution contract, skip list, scope limits, s01–s10 validation; this audit |
| API behaviour | R12–R18 | `spec/core.md` §1; C1; 8 `TestNotesSearch*` tests |
| Backend tests | R19–R23 | T0001/T0004; `spec/contract-matrix.md`; Go tests |
| UI | R24–R30 | `spec/core.md` §3; C2; `TestUISemantics`; `SEARCH-E2E-1..6`; s21 graph |
| Deploy / E2E | R31–R40 | C3/C4; 6 search + 7 auth Playwright scenarios; s20b/s20c |
| Auth / persistence freeze | R41 | unchanged auth/isolation contract and existing tests |

## Task-brief coverage

All ten briefs are present:

- `notebook-search-api`: T0001, T0004.
- `notebook-search-ui`: T0002, T0005, T0006, T0007.
- `notebook-search-deploy-e2e`: T0003, T0008, T0009, T0010.

T0003 (unit-level) still contains the earlier search-API-smoke and user-B-search
scenario wording. The task-level T0008/T0009, M01, `spec/core.md`, and
`contract-matrix.md` supersede it: the integration smoke is auth/notes only, the
six search scenarios are find/not-found/case/clear/create-active/delete-active,
and user-B isolation remains auth E2E-6. Raw R31–R40 remain covered; no task
brief is missing and no raw item is unaddressed.

## Contract / spec coverage statement

`spec/contract-matrix.md` records **41 rows**: 30 API (`C-01..C-30`) and 11 UI
(`U-01..U-11`). Every row has an executable oracle at this head:

- all referenced Go test functions exist in `main_test.go` or `web_ui_test.go`
  (`TestNotesSearch*`, `TestAuthRequired`, `TestAuthMethodOrder`,
  `TestNotesMethodNotAllowed`, `TestAddNote`, `TestDeleteNote`,
  `TestDeleteInvalidID`, `TestDeleteForeignNote`, `TestDeleteMissing`,
  `TestUnknownAPINotFound`, `TestWireContract`, `TestHTTPTransport`,
  `TestRegister`, `TestLogin`, `TestLoginInvalid`, `TestUISemantics`);
- all E2E refs (`SEARCH-E2E-1..6`, auth E2E-5/6/7) exist in the Playwright specs;
- `spec/core.md` §0/§5 records `contract_parity.drift_count = 0`, because this
  app repo has no OpenAPI/generated pipeline; the checked matrix is the contract
  source of truth.

Every contract row is oracle-backed; none is oracle-free.

## Gap list

**Empty.** `coverage-audit.json` remains valid:

```json
{"verdict":"pass","coverage":{"total":45,"resolved":45},"gaps":[]}
```

`OD-6` (reload query persistence) is a needs-human design question, not a raw
item: R28 requires only that reload keeps working, and `sessionStorage` restore
is explicitly non-contractual. It does not create a coverage gap.

## Fault-catalog summary

`fault-verdicts.json` contains **20 catalog ids**:

| Verdict | Count |
|---|---:|
| `covered` | **15** |
| `na` | **5** |
| **total** | **20** |

Checks performed:

- **Covered → evidence:** 15/15 covered entries have an `evidence` reference.
- **`na` → justification:** 5/5 `na` entries have a `justification`.
- **Inherited → `inherited_from`:** the 10 entries that are inherited from
  `f-v3-auth-notes/E4312` (or a base + f-v4 extension) carry `inherited_from`.
- The five non-inherited covered entries are
  `CONTRACT-STATUS-CODE` (contract-matrix evidence),
  `DATA-SCOPE-VALIDATION` (new search-isolation oracle, hybrid with the base
  isolation tests), `UI-E2E-PREVIEW` (s20c preview verdict),
  `UI-EMPTY-STATE-CONTROLS`, and `UI-FILTER-SERIALIZATION`.
- No covered entry lacks evidence; no `na` entry lacks justification; no verdict
  is wrong. `fault-verdicts.json` was not modified.

Non-blocking metadata observations:

1. `UI-E2E-PREVIEW` cites `s20c:preview-verdict/pass-verified`. At s17 this is a
   forward/prior-run reference; the E8363 s20c run must produce the fresh
   `test2` preview verdict before that evidence is current for this execution.
2. `path1.project.json` exposes 17 audit oracles. `SEC-AUTH-REQUIRED` and
   `SEC-USER-ISOLATION` are path1 oracle ids without a direct `fault-verdicts`
   key; five `na` catalog ids are not path1 audit oracles. This is a registry-set
   difference, not a missing proof for the 20 catalog verdicts.
3. `DATA-SCOPE-VALIDATION` is a hybrid (base isolation + new search isolation)
   but has no `inherited_from`; this is optional metadata consistency, not an
   invalid verdict.

## Non-blocking drift (not gaps)

1. **T0003 vs T0008/T0009** — stale unit-brief wording about a search API smoke
   and user-B search scenario. T0008/T0009, M01, and the spec are authoritative;
   raw coverage is intact.
2. **T0002 vs T0005/T0006/spec** — T0002 uses the lowercase empty-state text and
   omits the non-empty-collection guard; T0005/T0006/T0007 and the spec record
   the exact `Ничего не найдено.` copy and the full guard.
3. **R23/T0004/matrix edge bullet** — the trace and matrix mention emoji/Cyrillic
   encoding cases, but `TestNotesSearchEncoding` actually covers `%`, space,
   `&`, and `+`. Raw R23 (URL-encoding + special characters) is covered; the
   emoji/Cyrillic claim should be narrowed or the test extended at s18/s20.
4. **R37 scenario reference** — the trace says "s20c isolation scenario"; the
   actual oracle is auth E2E-6 plus `TestNotesSearchIsolation`.
5. **Metadata** — `plan.md` still carries prior-run E9294/`dev/f-v4-note-search`/
   `406fa965`; this audit and the change definition use E8363 / base `5935e148`.
   This is historical metadata, not a coverage defect.

## Verdict and conditions

**PASS.** Coverage is 45/45 with no gaps; all ten task briefs and all 41 contract
rows are accounted for; the fault catalog is internally valid at 20 ids
(15 covered / 5 `na`).

Conditions for later steps:

- s18/s20 should correct or extend the emoji/Cyrillic encoding claim so the
  trace/matrix and `TestNotesSearchEncoding` agree.
- s20c must produce fresh E8363 preview/E2E evidence for `UI-E2E-PREVIEW`.
- s18/s20 should treat T0008/T0009 and `spec/core.md` as authoritative over the
  stale T0003/T0002 wording.

## Limitations

- Per instruction, **no git commands were run**; checks are against the working
  tree at this head, not a base diff.
- `fault-verdicts.json` was not modified; it is reported as found.
- Only `coverage-audit.md` and this review were written. `coverage-audit.json`
  was verified as the required valid mirror and left unchanged.
