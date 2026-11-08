# Result audit — f-v4-note-search (E0809)

- Verdict: **pass** (decision: **pass**)
- Execution: **E0809** · step **s22.result_audit** · role **architect (independent)**
- Branch: `dev/f-v4-note-search-e2e` · base `e6aeb44e` · audited result on stand `test2`
- Deployed build: **`5785dc0`** (`5785dc0aefbb2ba3e46f42095e5c8d34d6e052f6`)
- Stand image: `sha256:1990befb2cbfe44935c4f3a682671be8ea637da8f0d9ec6d9a02227b4edce86e`
- Audited: E2E **20/20**, UI audit **24/24**, UX audit **22/22**, fault catalog **16/16 with
  verdicts (0 gaps)**, active invariants green, DS pins consistent.
- No code changes and no commit were made by this audit; only this artifact was written.

## Verdict rationale

The delivered result is accepted. Every claimed outcome was re-verified from the stored
artifacts, from the live stand (`/healthz`, served `app.js`/`app.css`/`/login` byte-identical
to commit `5785dc0`), and from the repository gates. No blocker and no open
critical/high finding was found. Residual risks below are documentation/evidence-hygiene
items and two accepted UX minors; none changes the product outcome.

## Acceptance criteria and oracles

| ID | Criterion | Oracle | Proof |
|---|---|---|---|
| AC-1 | Search E2E passes on the deployed preview stand | `E2E_BASE_URL=https://test2.nexus.ukituki.tech npx playwright test web/e2e/notes-search.spec.js` | `scenario-evidence.json`: 20/20 pass, `pngdiff=OK`; `preview-verdict.json`: `result=pass`, `status=verified` |
| AC-2 | Deployed artifact identity is bound to the audited result | `curl -fsS https://test2.nexus.ukituki.tech/healthz` + `git merge-base --is-ancestor 5785dc0 HEAD` | healthz returns `build_ref=5785dc0`, image `1990befb…`, `build_args_hash=3f74c563…`, `gate_bundle_digest=42f4ba6f…`; ancestor exit 0 |
| AC-3 | Served UI is the committed build, not a drifting stand | `sha256sum` of live `/app.js`, `/app.css`, `/login` vs `git show 5785dc0:web/...` | all three hashes identical (`ba458011…`, `749b9108…`, `322312ed…`) |
| AC-4 | API query cap and auth path hold on the stand | `doc/идеи/f-v4-note-search/e2e-api-smoke.log`; `go test -run 'TestNotesSearchQueryTooLong|TestNotesSearchAuthRequired'` | `q48 200`, `q512 200`, `q513 400 {"error":"query too long"}`, no-token `401`; tests green |
| AC-5 | Screenshots are real, distinct, and match the recorded evidence | `python3` sha256 compare + `python3 tools/pngdiff.py --thresh 0.005` | 20/20 PNG present and sha256 match `scenario-evidence.json`; pngdiff `OK` (no near-duplicates) |
| AC-6 | UI audit covers blocks A–L with 0 DS violations | `ORC_FEATURE_DIR=… python3 tools/ui-audit-check.py --root . --platform web --expect-sha 5785dc0` | gate `PASS` (exit 0); `ui-audit.json` 24/24 `ok`, 0 blockers, 0 DS violations; designer review `ACCEPT` |
| AC-7 | UX result is accepted with no blocking defects | `doc/идеи/f-v4-note-search/ux-audit.json` (independent product/UX audit) | 22/22 `ok`, 0 blockers, 0 critical/high, 0 majors, 2 residual minors; verdict `pass` |
| AC-8 | Every fault-catalog class has a verdict with proof | `python3 tools/fault-catalog-check.py --mode verdicts --require-proof --catalog audit/fault-catalog --verdicts …/fault-verdicts.json` | `PASS`: items=16, covered=10, gaps=0; 6 `na` with justification; catalog validate `PASS` 16 unique ids |
| AC-9 | Active invariants execute green | `GOWORK=off go test -count=1 ./...` + `go test -list '.*'` + build-tag grep | `ok` exit 0 (3.450s); all named invariant tests exist; 0 `integration|e2e|manual` build tags |
| AC-10 | UI runtime invariants are evidenced before activation | Playwright 20 scenarios (s20c) + `invariants.json` | 8 UI invariants remain `proposed` (activation bookkeeping) and are evidenced by SEARCH-E2E-1..20; no untested claim |
| AC-11 | Design System pins and usage are consistent | `check-design-gates.py ds-usage|design-integrate|ds-drift` | all three gates `PASS`; release 1.0.0, digest `02f027a8…`; 14/14 registry components, 0 local instances, 0 Kubiki imports in delivered UI |
| AC-12 | UI graph and integration inputs are actualized | `ORC_FEATURE_DIR=… bash tools/path1-gate.sh graph-actualized E0809` | `gate-graph-actualized: OK`; integrated units 3/3, no conflict markers, full Go suite green |

## Findings

- Open confirmed **critical/high**: **0**
- **Blockers**: **0**
- New findings from this result audit: **0**
- Prior E1546 review findings in the folder are `low`/`info` only (8 code-review, 7 red-team),
  verdict `pass`; none is critical/high and none is a blocker for E0809.

## Evidence

| ID | Command | File |
|---|---|---|
| EV-1 | `python3 tools/fault-catalog-check.py --mode verdicts --require-proof --catalog audit/fault-catalog --verdicts doc/идеи/f-v4-note-search/fault-verdicts.json` | `fault-verdicts.json`, `audit/fault-catalog/notebook.yaml` |
| EV-2 | `ORC_FEATURE_DIR="doc/идеи/f-v4-note-search" bash tools/path1-gate.sh fault-catalog E0809` | `fault-verdicts.json` |
| EV-3 | `ORC_FEATURE_DIR="doc/идеи/f-v4-note-search" python3 tools/ui-audit-check.py --root . --platform web --expect-sha 5785dc0` | `ui-audit.json` |
| EV-4 | `python3 tools/check-design-gates.py ds-usage --root . --feature-dir "doc/идеи/f-v4-note-search"` | `ds.lock.json`, `ds-pin.json`, `component-refs.json` |
| EV-5 | `python3 tools/check-design-gates.py design-integrate --root .` | `design-gaps.json` |
| EV-6 | `python3 tools/check-design-gates.py ds-drift --root .` | `ds.lock.json` |
| EV-7 | `GOWORK=off go test -count=1 ./...` | `main_test.go`, `web_ui_test.go` |
| EV-8 | `go test -list '.*'` and `grep -R -E '^//go:build.*(integration|e2e|manual)' --include='*_test.go' .` | invariant tests |
| EV-9 | Python sha256 comparison of 20 screenshots vs `scenario-evidence.json` | `screenshots/SEARCH-E2E-1..20.png` |
| EV-10 | `python3 tools/pngdiff.py --thresh 0.005 doc/идеи/f-v4-note-search/screenshots/SEARCH-E2E-*.png` | `screenshots/` |
| EV-11 | `curl -fsS https://test2.nexus.ukituki.tech/healthz` | live stand provenance |
| EV-12 | `sha256sum` of live `/app.js`, `/app.css`, `/login` vs `git show 5785dc0:web/...` | deployed assets |
| EV-13 | `git merge-base --is-ancestor 5785dc0 HEAD` + `git diff --stat 5785dc0..HEAD -- web main.go main_test.go web_ui_test.go` | deployed SHA lineage (no code delta) |
| EV-14 | `sha256sum doc/идеи/f-v4-note-search/scenario-evidence.json` | `preview-verdict.json` (digest `7fe1559f…` matches) |
| EV-15 | `ORC_FEATURE_DIR="doc/идеи/f-v4-note-search" bash tools/path1-gate.sh graph-actualized E0809` | `UI-GRAPH.yaml` |

## Residual risks

1. **Fault verdicts are stale for six UI classes (low, documentation).** `fault-verdicts.json`
   still marks `UI-EMPTY-STATE-CONTROLS`, `UI-FILTER-SERIALIZATION`, `UI-LOADING-ERROR-STATES`,
   `UI-E2E-PREVIEW`, `UI-A11Y-LABEL`, `UI-XSS-ESCAPE` as `na` with s17-era justification. The
   gate passes (16/16 verdicts, 0 gaps), and the classes are now independently proven by
   s20c/s22a, but the file should be upgraded to `covered` with the new proof in a later revision.
2. **Legacy `evidence-manifest.json` is stale (low).** It lists only 6 screenshots with hashes
   from an older E1546/E8363 run. The authoritative chain is intact: `preview-verdict.json`
   binds `scenario-evidence.json` (`sha256:7fe1559f…`), and all 20 current screenshot hashes
   match that file. The stale manifest is misleading, not load-bearing.
3. **No local `preview-deploy.json` (low).** Deployment provenance was re-checked from the live
   `/healthz` (build/image/build-args/gate-bundle) and from `preview-verdict.json`; the
   `bundle` field is empty. No separate preview-deploy artifact exists in the repo.
4. **SEARCH-E2E-11/12 screenshots do not depict the loading/error state they evidence (low).**
   The `shot()` call runs after the state is released/recovered; the states themselves are
   proven by the passing assertions (`role=status`/`role=alert`, disabled search). Recapture is
   recommended, but it is an evidence-artifact defect, not a UI defect.
5. **Legacy Kubiki kit remains in the repo but is not shipped (low).** `frontend/src/ui/kit/**`
   (31 tracked files) still carries `@kubiki/ui` naming; nothing under `web/` imports it,
   `package.json` has no such dependency, and the Go binary embeds only `web/*`. “0 Kubiki
   imports” is accurate for the delivered UI.
6. **Deploy note SHA differs from the build SHA (low).** `s20b-deploy.md` names source commit
   `20e0fe9`; the deployed/verified build is `5785dc0`. `git diff 20e0fe9 5785dc0` is docs-only,
   so the deployed code is byte-identical and the `5785dc0` binding holds.
7. **Accepted DS token drift (low, DS 1.0.1 backlog).** Only two literal values are not
   `var(--…)` (`border-radius: 8px`, `color:#fff`), both documented and accepted in
   `design-impact.md` / `coverage-audit.json`; the pinned DS 1.0.0 digest is unchanged.
8. **Viewport declaration vs stored PNG (low, evidence precision).** `scope.viewports` declares
   `1200x900`, while most stored PNGs are 1280×720; E2E-18 still executes the 1200/900 overflow
   and row-layout assertions, and `.app{max-width:640px}` makes 1200 and 1280 render identically.
9. **Accepted UX minors (non-blocking).** Offline with an active query cannot clear the filter
   until reconnect, and the zero-note disabled input relies on UA styling (GAP-2); both are
   documented in `ux-audit.md`, recoverable, and consistent with the mandated rules.
10. **UI runtime invariants remain `proposed` (process bookkeeping).** 8 UI invariants are still
    `status=proposed`; their enforcement evidence exists at s20c/s22a, but activation has not
    been recorded. This is bookkeeping, not a missing check.
11. **Prior E1546 review artifacts are stale (low).** `code-review.json` and
    `red-team-review.json` reference E1546/`a95876d`; their findings are low/info only. They do
    not describe E0809 and should not be cited as E0809 evidence.

## Independence

- UI audit reviewer `ses_e440dc342ffe0cyPYnyr57Rk2D` / UX auditor
  `ses_e44094ddfffeZsHroFCFnDiUWh` are distinct from the UI author
  `ses_e4433e6faffeDGXVi4lKO4t3W8`; `ui-audit.json` and `ux-audit.json` both record
  `distinct=true`.
- This result audit is performed by the `architect` role at `s22.result_audit`, after the
  independent s22a/s22e reviews, and re-runs the gates rather than trusting the author's claims.

## Re-audit after s23 (build 7026b7e)

- Reason: s23 refinement invalidated integration; no product changes, but process requires re-deploy/verify.
- Re-deployed HEAD 7026b7e to test2 (image sha256:8302078e…, build_args sha256:d16f8c44…).
- E2E re-run: 20/20 pass; API smoke 512→200, 513→400, no-token 401.
- UI/UX audits re-run and pass (stand.sha 7026b7e); canaries 3/3 genuinely detected after detector fix.
- Verdict remains **pass**; residuals unchanged (CR-01 medium, CR-02/03 low, DS token drift).
