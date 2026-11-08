# s14 unit quality — notebook-search-deploy-e2e (E0809 s20, u03)

- **Execution:** `E0809-s20.sde_5fexecution-u03`
- **Step:** `s14.unit_quality` (architect)
- **Unit:** `notebook-search-deploy-e2e`
- **Branch:** `orc-exec-E0809-s20.sde_5fexecution-u03` at `5352d4e`
- **Verified by:** `architect` (independent from `sde-infra`)

## crutch_density_grew: **false**

- No new runtime code, no new dependencies (`package.json`/`package-lock.json`
  unchanged), no duplicated deploy paths, no second E2E runner.
- The spec reuses the existing Playwright setup and helper model (fresh user per
  test, unique note text, `testid` locators) and adds only deterministic helpers
  (`waitForNotesReady`, `expectNoHorizontalOverflow`, API request helpers).
- Test-only network control uses standard Playwright primitives
  (`page.route`, `context.setOffline`); no production hook, flag, or sleep-based
  workaround was added.
- `E2E_API_ONLY=1` short-circuits Playwright for the s20a API gate but does not
  skip or weaken the s20c run; failure paths remain fail-close (`node`/`npm`/
  browser/spec missing → non-zero exit).
- No hacks to make assertions pass: 20 real `test()` calls, no `skip`/`fixme`/
  `only`, no branching on environment to bypass a check.

## Evidence integrity

- No synthetic evidence: `scenario-evidence.json` has `run_at=null`,
  `status=pending-s20c`, and all 20 rows have `screenshot=null`, `sha256=null`,
  `pngdiff=null`. No pass entry, hash, or `pngdiff: OK` was pre-filled.
- No stale `E8895` data in `scenarios.json` or `scenario-evidence.json`.
- `scenarios.json` contains exactly 20 `planned` entries with
  `given/when/then/e2e_ref`; it describes intended behaviour, not observed results.
- The 96px per-scenario banner in `shot()` is a test-only annotation used so the
  s20c near-duplicate (`pngdiff`) gate can distinguish visually similar search
  states. It is not product state, does not fabricate a result, and is present
  only in the captured frame. Non-blocking note: s20c should confirm annotated
  frames are acceptable evidence or capture unannotated frames instead.
- Local pre-s20c smoke results mentioned in `execution-report.md` are explicitly
  labelled as local/temporary and are not used as unit evidence.

## Residual

Runtime quality (flake rate, stand/browser behaviour) can only be judged at s20c
on `test2`; this step records no runtime claim. The workspace-wide `go test`
failure is the pre-existing base oracle R-1 documented in `verify.md` §4 and is
fixed by U02, not by this unit.

**Verdict: pass — crutch density did not grow; no synthetic or fabricated evidence.**

- accepted: s14.unit_quality (E0809-u03)
