# Coverage audit — f-v4-note-search (s17)

- Execution: **E8363**, step **s17.coverage_audit**
- Verdict: **pass**
- Coverage: **45 / 45** raw-request items resolved; **0** gaps
- Task briefs: **10 / 10** (`T0001`–`T0010`) present, plus `M01/brief.md`
- Contract rows: **41 / 41** (`C-01..C-30` API + `U-01..U-11` UI) have an
  executable oracle; `drift_count = 0`
- Sources: `feature-request.md`, `intent-trace.json`, `feature-brief.md`,
  `change-definition.md`, `spec/core.md`, `spec/contract-matrix.md`, `plan.md`,
  `M01/brief.md`, `T0001..T0010/brief.md`, `invariants.json`,
  `fault-verdicts.json`.

## Coverage by area

| Area | Raw items | Resolved by |
|---|---|---|
| Process / constraints | R01–R11, R41–R45 | E8363 execution contract, skip list, limits, s01–s10 validation; this audit |
| API behaviour | R12–R18 | `spec/core.md` §1; C1; `TestNotesSearch*` |
| Backend tests | R19–R23 | `T0001`, `T0004`; `spec/contract-matrix.md`; 8 Go tests |
| UI | R24–R30 | `spec/core.md` §3; C2; `TestUISemantics`; `SEARCH-E2E-1..6`; s21 graph |
| Deploy / E2E | R31–R40 | C3/C4; 6 Playwright search scenarios + 7 auth scenarios; s20b/s20c |
| Auth / persistence freeze | R41 | unchanged contract; existing auth/isolation tests and `INV-AUTH-REQUIRED`, `INV-USER-ISOLATION` |

## Task-brief coverage

All ten task briefs are present and mapped to the three units:

| Unit | Tasks | Status |
|---|---|---|
| `notebook-search-api` | T0001, T0004 | PRESENT |
| `notebook-search-ui` | T0002, T0005, T0006, T0007 | PRESENT |
| `notebook-search-deploy-e2e` | T0003, T0008, T0009, T0010 | PRESENT |

`T0003` is the unit-level brief; its stale details about a search API smoke and
user-B search scenario are superseded by the task-level `T0008`/`T0009` and
`spec/core.md`/`contract-matrix.md`. No task brief is missing. See "Non-blocking
drift" below.

## Contract coverage

`spec/contract-matrix.md` records 41 rows: 30 API (`C-01..C-30`) + 11 UI
(`U-01..U-11`). Every row has an executable Go/Playwright oracle at this head;
no row is oracle-free and `contract_parity.drift_count = 0` (OpenAPI is not used
in this app repo; `spec/core.md` §0).

All Go test functions referenced by the matrix exist in `main_test.go` or
`web_ui_test.go` (verified: `TestNotesSearch*`, `TestAuthRequired`,
`TestAuthMethodOrder`, `TestNotesMethodNotAllowed`, `TestAddNote`,
`TestDeleteNote`, `TestDeleteInvalidID`, `TestDeleteForeignNote`,
`TestDeleteMissing`, `TestUnknownAPINotFound`, `TestWireContract`,
`TestHTTPTransport`, `TestRegister`, `TestLogin`, `TestLoginInvalid`,
`TestUISemantics`). All E2E refs (`SEARCH-E2E-1..6`, auth E2E-5/6/7) exist in
`web/e2e/notes-search.spec.js` and `web/e2e/auth-notes.spec.js`.

## Gaps

None. `gaps_has_blocking = false`. The machine mirror
`coverage-audit.json` is valid and remains:

```json
{"verdict":"pass","coverage":{"total":45,"resolved":45},"gaps":[]}
```

`OD-6` (reload query persistence) is a needs-human design question, not a raw
request item: R28 requires only that reload keeps working, and the spec treats
`sessionStorage` restore as non-contractual. It therefore creates no coverage
gap.

## Fault catalog verdicts

Machine mirror: `fault-verdicts.json` — **20 catalog ids: 15 `covered`, 5 `na`**.

- All **15 covered** entries have an `evidence` reference.
- All **5 `na`** entries (`CONTRACT-DATE-BOUNDARY`, `DATA-CURSOR-STABLE-KEY`,
  `DATA-HASMORE-OVERSCAN`, `DATA-DESCRIPTION-DERIVATION`, `UI-DATE-BOUNDARY`)
  have a `justification`.
- All **10 inherited** proofs carry `inherited_from`
  (`f-v3-auth-notes/E4312` or the base + f-v4 extension).
- The five non-inherited covered entries are new/extended oracles:
  `CONTRACT-STATUS-CODE` (contract-matrix evidence),
  `DATA-SCOPE-VALIDATION` (new `TestNotesSearchIsolation` oracle, hybrid with the
  base isolation tests), `UI-E2E-PREVIEW` (s20c preview verdict),
  `UI-EMPTY-STATE-CONTROLS`, `UI-FILTER-SERIALIZATION`.

No verdict is wrong and `fault-verdicts.json` was not modified. Two non-blocking
metadata observations are recorded in the s17 review:

1. `UI-E2E-PREVIEW` cites `s20c:preview-verdict/pass-verified`; at s17 this is a
   forward/prior-run reference, and the E8363 s20c run must produce the fresh
   preview verdict before that evidence is current.
2. `path1.project.json` exposes 17 audit oracles; `SEC-AUTH-REQUIRED` and
   `SEC-USER-ISOLATION` are path1 oracle IDs without a fault-verdict key, while
   five `na` catalog ids are not path1 audit oracles. This is a registry-set
   difference, not a missing proof for the catalog verdicts.

## Non-blocking drift (not gaps)

- **T0003 vs T0008/T0009.** T0003 still asks for a search find/not-found API
  smoke and lists user-B isolation as one of the six search scenarios; T0008
  defines the actual six search scenarios (find, not-found, case, clear,
  create-active, delete-active), T0009 forbids a search `q=` smoke, and user-B
  isolation remains auth E2E-6. Raw R31–R40 are still covered.
- **T0002 vs T0005/T0006/spec.** T0002 uses the lowercase empty-state text and
  omits the non-empty-collection guard; T0005/T0006/T0007 and `spec/core.md`
  record the exact copy `Ничего не найдено.` and the full guard
  `hasQuery && !noNotes && visible.length === 0`.
- **R23 / T0004 / contract-matrix edge bullet.** The trace, T0004, and the
  matrix's negative-edge bullet mention emoji/Cyrillic coverage, but
  `TestNotesSearchEncoding` actually exercises `%`, space, `&`, and `+`. Raw R23
  (URL-encoding + special characters) is covered; the emoji/Cyrillic phrasing is
  an overclaim to narrow or extend at s18/s20.
- **R37 scenario reference.** The trace says "s20c isolation scenario"; the
  actual user-B isolation oracle is auth E2E-6 (plus
  `TestNotesSearchIsolation`). Coverage is intact; the reference should be
  tightened.
- **UI-E2E-PREVIEW evidence timing** and the path1/fault-verdict registry
  difference described above.

## Notes

- `q` whitespace decision is closed in `expertise-report.md` (OD-1) and covered
  by `TestNotesSearchWhitespaceQuery`.
- Owner scope is covered by the pre-existing isolation tests and the new
  `TestNotesSearchIsolation`.
- OpenAPI is not used in this app repo; contract parity is 0 drift, as recorded
  in `spec/core.md` §0/§5.
- No platform, path-1, source, UI, spec, or fault-verdict file was changed by
  this audit; the only audit artifacts touched are `coverage-audit.md` and
  `platform-dev-validation-zero/s17-coverage-audit.md`.
