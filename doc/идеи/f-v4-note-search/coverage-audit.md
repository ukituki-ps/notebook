# Coverage audit — f-v4-note-search (s17, E6636)

- Execution: **E6636** · step **s17.coverage_audit** · role **architect**
- Branch: `dev/path10-runner-13` · base `9e7fae353c61e717505dc40019627a1d7ab48820`
- Design System: **Notebook DS 1.0.1** (`ds/v1.0.1`, digest
  `sha256:4e0ef1052a1401a928588445f921f7d231b7c0e7c9b10c181fdbbb439108c85e`)
- Verdict: **pass_with_gaps** (2 minor, 0 major/critical, `gaps_has_blocking = false`)
- Coverage: **45 / 45** raw-request items resolved; **0** unresolved
- Sources: `feature-request.md`, `intent-trace.json` (45/45), `feature-brief.md`,
  `intent-brief.md`, `change-definition.md`, `spec/core.md`,
  `spec/contract-matrix.md`, `plan.md`, `M01/brief.md`,
  `T0101..T0103/brief.md`, `invariants.json`, `ds.lock.json`,
  `design-gaps.json`, `fault-verdicts.json`.
- Machine mirror: `coverage-audit.json` (same verdict/gaps).

## Coverage by area

| Area | Raw items | Resolved by |
|---|---|---|
| Process/constraints | R01–R11, R41–R45 | `s01`–`s17` execution contract, skip list (s45/s46), test2-only limits; this audit |
| API behavior | R12–R18 | `spec/core.md` §1; C1; `TestNotesSearch*` (`/app/orc-repos/.../main_test.go`) |
| Backend tests | R19–R23 | `T0101` oracles; `spec/contract-matrix.md` rows |
| UI | R24–R30 | `spec/core.md` §3 (AOD-1..AOD-7); C2; `TestUISemantics`; s21 graph |
| Deploy/E2E | R31–R40 | C3/C4; `web/e2e/notes-search.spec.js` 20 scenarios + CR-01..CR-03; s20b/s20c |
| DS 1.0.1 contract | C5 | `ds.lock.json`, `component-refs.json`, `design-gaps.json`; s22a/s24 |
| Auth/persistence freeze | R41 | unchanged auth/session/persistence; existing isolation tests |

Every raw-request item in `intent-trace.json` maps to a planned brief, spec
section, contract-matrix row or gate; no item is `missing`/`dropped`.

## Contract / spec coverage

- `contract-matrix.md` has 10 rows (endpoint/method/status/envelope/test) and
  5+ negative/edge cases, each with an executable `go test` oracle.
- Backend surface at base `9e7fae35` already satisfies `spec/core.md` §1:
  `maxQueryBytes = 512`, owner-first `ListNotes`, auth before query, `[]` not
  `null`.
- OpenAPI modules are not used in this app repo (`spec/core.md` §0); contract
  parity drift is 0 (`items = []`).

## Invariants

19 active invariants are covered by executable oracles (`invariants.json`):
`INV-AUTH-REQUIRED`, `INV-USER-ISOLATION`, `INV-SEARCH-OWNER-SCOPE`,
`INV-SEARCH-CASE-INSENSITIVE`, `INV-SEARCH-EMPTY-Q`, `INV-SEARCH-NOT-FOUND`,
`INV-SEARCH-ENCODING`, `INV-SEARCH-Q-MAX`, `INV-WIRE-CASING`,
`INV-REAL-TRANSPORT`, `INV-NO-SKIP-TAGS`, `INV-UI-TRUTH`, `INV-UI-LABEL`,
`INV-UI-A11Y-NAME`, `INV-XSS-ESCAPE`, `INV-UI-ORACLE`,
`INV-SEARCH-UI-FILTER`, `INV-SEARCH-UI-EMPTY`, `INV-SEARCH-UI-TESTIDS`.
`INV-UI-E2E-PREVIEW` is proposed; its oracle materializes at s20c (minor gap).

## Gaps

| ID | Severity | Owner | Description |
|---|---|---|---|
| `E2E-PREVIEW-PENDING-S20C` | minor | `sde-infra/T0103` | 20-scenario + CR evidence on `test2` is defined but official run lands at s20c. |
| `GRAPH-ACTUALIZATION-PENDING-S21` | minor | `graph-builder/s21` | `UI-GRAPH.yaml` is actualized from code at s21; planned graph is s04 input. |

Both gaps are verification-pending, non-blocking, and scheduled by the process;
no major/critical gap and no unresolved raw item. `gaps_has_blocking = false`.

## Fault catalog verdicts

Machine mirror `fault-verdicts.json`: **16 catalog ids, all `covered`** with
detector checks and inherited base proofs (`INV-*`), including search-specific
oracles for auth-before-query and owner-scope. No `na` entry is needed for this
surface.

## Notes

- `q` whitespace decision (R18) is closed as "all notes" and covered by
  `TestNotesSearchWhitespaceQuery`.
- Owner-scope is covered by the pre-existing isolation tests and by
  `TestNotesSearchIsolation`.
- R-1 (44px oracle) is closed at base: `web_ui_test.go:360-365` asserts
  `min-height: var(--control-height)` with `--control-height: 44px`.
- No OpenAPI module is added; contract parity stays 0 drift.
