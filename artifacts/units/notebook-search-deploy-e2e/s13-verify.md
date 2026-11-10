# s13 independent verification — notebook-search-deploy-e2e (U03)

- **Execution:** `E6636-s20.sde_5fexecution-u03`
- **Step:** `s13.unit_verify` · role `architect` (independent; not the unit author)
- **Unit:** `notebook-search-deploy-e2e` · domain `notebook-e2e` · `change_class: plain`
- **Branch:** `orc-exec-E6636-s20.sde_5fexecution-u03`
- **Base:** `1722a1e51b3734284c6a9103a4ed2e5ab5793386`
- **Baseline:** s12.unit_check (executor `sde-infra`, commit `f22447e`)
- **Verified HEAD:** `f22447e9d00cf36f0a62ae399f983e94154f5349`
- **Gate `gate-unit-executor-distinct`:** satisfied — s12 was executed by `sde-infra`,
  this verify is by `architect`.
- **Stand policy:** `test2` only under the E6636 lease; no stand run here (s20c).

## Verdict: **pass**

The unit deliverables match the brief, the process scope, and the
architecture boundaries. Two non-blocking observations are recorded; neither
changes the verdict.

## Independent checks

| # | Criterion | Result |
|---|---|---|
| V1 | 23 real `test()`: `SEARCH-E2E-1..20` ×1 + `CR-01..03` ×1 | PASS |
| V2 | No skip/fixme/only/xit/xdescribe, no conditional early-return inside tests | PASS |
| V3 | One unique `shot()` id per scenario, no duplicates | PASS |
| V4 | Every scenario has assertions (min 1 direct `expect()` + helper assertions); no placeholder bodies | PASS |
| V5 | Manifest ↔ spec: all 20 `SEARCH-E2E-*` ids present, 20× `given/when/then/e2e_ref` | PASS |
| V6 | API smoke: auth 401 before query (L83–88), `q512` → 200 (L135–136), `q513` → 400 `query too long` (L140–142) | PASS |
| V7 | Fail-close: `E2E_BASE_URL` required (L10–11), node/npm/chromium missing → exit≠0 (L217–235), no skip path | PASS |
| V8 | No stale execution ids (`E0809`/`E8895`/`E6177`/`E4312`/`E1320`) in unit files | PASS |
| V9 | No fabricated evidence: no committed `scenario-evidence.json`, no tracked `screenshots/` | PASS |
| V10 | Scope isolation: `git diff base..HEAD` only `artifacts/**`; protected paths empty | PASS |
| V11 | DS/platform frozen: no `design/**`, `arch/**`, `web/**`, `main*.go` changes | PASS |

## Scenario assertion density (V4)

| Scenario | expects | Scenario | expects |
|---|---|---|---|
| SEARCH-E2E-1 | 4 | SEARCH-E2E-11 | 8 |
| SEARCH-E2E-2 | 5 | SEARCH-E2E-12 | 13 |
| SEARCH-E2E-3 | 3 | SEARCH-E2E-13 | 10 |
| SEARCH-E2E-4 | 7 | SEARCH-E2E-14 | 7 |
| SEARCH-E2E-5 | 7 | SEARCH-E2E-15 | 9 |
| SEARCH-E2E-6 | 14 | SEARCH-E2E-16 | 20 |
| SEARCH-E2E-7 | 3 | SEARCH-E2E-17 | 7 |
| SEARCH-E2E-8 | 1 | SEARCH-E2E-18 | 15 |
| SEARCH-E2E-9 | 9 | SEARCH-E2E-19 | 10 |
| SEARCH-E2E-10 | 6 | SEARCH-E2E-20 | 7 |
| CR-01 | 7 | CR-02 | 5 |
| CR-03 | 10 | | |

`SEARCH-E2E-8` has one direct assertion by design (legacy `sessionStorage`
query is cleared on the no-token path); navigation is asserted by `waitForURL`.

## Observations (non-blocking)

1. `scenarios.json` tracks the 20 user scenarios only; `CR-01..03` are regression
   tests in the spec and are not manifest entries. This matches the brief
   (“20 Playwright scenarios + CR-01..CR-03”) and `check-scenario-coverage`
   consumption, which keys on the 20 user scenarios.
2. The authoring container has no `go`/`node` on `PATH`; runtime proof
   (`playwright test` 23 green, screenshots + sha256 + `pngdiff`) is intentionally
   produced at s20c on `test2`, not here. Pre-writing it would be fabricated
   evidence.

## Verdict rationale

All unit-scope items are implemented and internally consistent; the executable
proof belongs to the preview gate (s20c). No fix is required to pass s13; a
failed s20c run would reopen the unit via the normal regression path.
