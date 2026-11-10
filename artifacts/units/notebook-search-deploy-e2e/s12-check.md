# s12 unit check — notebook-search-deploy-e2e (U03)

- **Execution:** `E6636-s20.sde_5fexecution-u03`
- **Step:** `s12.unit_check` · role `sde-infra`
- **Unit:** `notebook-search-deploy-e2e` · domain `notebook-e2e` · `change_class: plain`
- **Branch:** `orc-exec-E6636-s20.sde_5fexecution-u03`
- **Base:** `1722a1e51b3734284c6a9103a4ed2e5ab5793386`
- **Checked:** s11 execution commit `2467e12cb5e1740ef4332d036a02d67179852708`
- **Inputs:** `unit-plan.md` (s10), `steps/s11.md` (s11), `orc_ctx` package
- **Stand policy:** `test2` only under the E6636 lease; no stand run in this step (s20c).

## Result: PASS

The unit deliverables at `2467e12` satisfy the four scope items. No defect
required a fix (`fixed_confirmed = true`); two non-blocking observations are
recorded below.

## Scope matrix

| # | Scope item | Evidence | Verdict |
|---|---|---|---|
| 1 | 20 Playwright scenarios `SEARCH-E2E-1..20` + `CR-01..CR-03`, no skips | C1–C4 | PASS |
| 2 | API smoke incl. 512-byte `400` and 512 accepted | C6–C8 | PASS |
| 3 | `scenarios.json` 20 + `scenario-evidence.json` 20/20 screenshot/sha256/pngdiff | C5, C9 | PASS (evidence by design at s20c) |
| 4 | `test2` only under E6636 lease; no prod/main/test1/canary | C10–C11 | PASS |

## Checks

| # | Check | Command | Result |
|---|---|---|---|
| C1 | Test count | `grep -cE '^test\(' web/e2e/notes-search.spec.js` | 23 |
| C2 | Scenario IDs | `grep -oE 'test\("(SEARCH-E2E-[0-9]+\|CR-[0-9]+)' … \| sort \| uniq -c` | `SEARCH-E2E-1..20` ×1, `CR-01..03` ×1 |
| C3 | Screenshot per scenario | `grep -oE 'shot\(page, "(SEARCH-E2E-[0-9]+\|CR-[0-9]+)"' … \| sort -u \| wc -l` | 23 |
| C4 | No skip/fixme/only | `grep -nE '\.(skip\|fixme\|only)\(' web/e2e/notes-search.spec.js` | no matches |
| C5 | Manifest ↔ spec mapping | loop over `SEARCH-E2E-*` ids from `scenarios.json`, `grep` test title in spec | missing = 0 |
| C6 | Shell syntax | `bash -n deploy/path1/e2e-preview.sh` | exit 0 |
| C7 | API smoke contract | `grep -nE 'q512\|q513\|expect_status 400\|WWW-Authenticate' deploy/path1/e2e-preview.sh` | 401 + `WWW-Authenticate` before query (L83–88); `q512` → 200 (L135–136); `q513` → 400 (L140–142); delete `400` (L191) |
| C8 | Fail-close entry | `grep -nE 'E2E_BASE_URL\|fail-close\|playwright test' deploy/path1/e2e-preview.sh` | `E2E_BASE_URL` required (L10–11); node/npm/chromium missing → `exit 1`, never skip (L217–235) |
| C9 | Manifest completeness | `grep -c '"given"\|"when"\|"then"\|"e2e_ref"' scenarios.json` | 20 each |
| C10 | No forbidden stand refs | `grep -nE 'prod\|test1\|canary\|main\.' deploy/path1/e2e-preview.sh` | no matches |
| C11 | Scope isolation | `git diff --name-only base..HEAD` | only `artifacts/**`; unit files unchanged vs base, protected paths (`main.go`, `web/*`, `design/`, `arch/`) empty |

## Evidence status

- `doc/идеи/f-v4-note-search/scenario-evidence.json` is **absent by design**:
  it is written only by a real green s20c run (screenshot path + sha256 +
  `pngdiff`). Pre-writing `pass` before the run would be fabricated evidence.
- `scenarios.json` entries stay `status: planned` until s20c flips them on a
  real run. `check-scenario-coverage` / `check-evidence-authentic` run at s20c,
  not at this step.

## Non-blocking observations

1. `deploy/path1/e2e-preview.sh` fail-close guard checks `auth-notes.spec.js`
   but not `notes-search.spec.js` (L220). Mitigated: the spec is tracked in this
   branch and s20c invokes `playwright test web/e2e/notes-search.spec.js`
   explicitly, which errors if the file is missing. Left unchanged to keep the
   verification plane at base.
2. The authoring container has no `go`/`node` on `PATH`, so `go build ./...`
   and `playwright test --list` cannot run here. The unit touches no Go source
   (C11), and the Playwright run is s20c's responsibility.

## Handoff

s13 (architect verify) can accept this PASS; the first executable proof of the
suite is s20c on `test2`.
