# s14 unit quality — notebook-search-deploy-e2e (U03)

- **Execution:** `E6636-s20.sde_5fexecution-u03`
- **Step:** `s14.unit_quality` · role `architect`
- **Unit:** `notebook-search-deploy-e2e` · domain `notebook-e2e` · `change_class: plain`
- **Branch:** `orc-exec-E6636-s20.sde_5fexecution-u03`
- **Base:** `1722a1e51b3734284c6a9103a4ed2e5ab5793386`
- **Baseline:** s13.unit_verify (PASS, commit `775f8e4db4a3815f2d23a8c798180de6ebdeec52`)
- **Independent of executor:** s11/s12 were `sde-infra`; this step is `architect`.
- **Runtime proof:** intentionally at s20c on `test2` under the E6636 lease; not claimed here.

## crutch_density_grew: **false**

The unit execution (s11 → s14) changed **no source file**: `git diff --stat
1722a1e5..HEAD -- web/e2e/notes-search.spec.js deploy/path1/e2e-preview.sh
doc/идеи/f-v4-note-search/scenarios.json` is empty. The s11–s13 commits only
added reports under `artifacts/**`. Crutch density of the verified tree is
therefore unchanged relative to the step baseline.

## Marker scan (unit files at baseline `775f8e4`)

| Marker | `notes-search.spec.js` (945 lines) | `e2e-preview.sh` (243 lines) |
|---|---|---|
| `test.skip` / `test.fixme` / `test.only` / `xit` | 0 | n/a |
| `waitForTimeout` | 0 | n/a |
| `force: true` | 0 | n/a |
| `sleep(` / `setTimeout` | 0 / 1 (documented, see below) | 0 |
| `TODO` / `FIXME` / `HACK` / `XXX` | 0 | 0 |
| `|| true` | 0 | 2 (`pw_chromium` probe) |
| `set +e` | n/a | 0 |

## Judgement on the two non-zero markers

1. **`setTimeout` (spec, CR-02, line 868).** `page.route("**/login", …)` holds
   the login navigation for 6 s so the transient 401/locked window is
   inspectable, then calls `route.continue()`. This is a deterministic
   test-only network hold (standard Playwright `page.route`), not a
   product hook, not a pass-forcing workaround, and it does not weaken any
   assertion: the test still asserts disabled search, `aria-disabled`, hidden
   `notes-empty`, and `aria-describedby` target. It is a documented timing
   control for a transient state, not a crutch. It is pre-existing in the
   verified tree (`f17a5a4`, part of base `1722a1e5`), not introduced by this
   execution.
2. **`|| true` (script, lines 232 and 236).** Only used to probe a chromium
   binary path; the result is then checked fail-close
   (`[ -n "$chromium" ] && [ -f "$chromium" ] || fail …`, line 238). Failure
   is never swallowed.

## Structural quality

- No second E2E runner, no duplicated deploy path, no new dependency:
  `package.json` / `package-lock.json` are unchanged vs base.
- `E2E_API_ONLY=1` only short-circuits Playwright for the s20a API gate; the
  s20c run does not set it and remains fail-close (`node`/`npm`/browser/spec
  missing → non-zero exit, never skip).
- 23 real `test()` bodies, no placeholders, one unique screenshot id per
  scenario; assertions are behavioural, not hardcoded state injection.
- No fabricated evidence: `scenario-evidence.json` is absent by design and is
  produced only by a real green s20c run; `scenarios.json` stays `planned`.

## Residual (non-blocking)

- Runtime flakes and screenshot/`pngdiff` authenticity can only be judged at
  s20c on `test2`; this step makes no runtime claim.
- The 6 s login hold slightly lengthens CR-02 runtime; acceptable for a
  transient-window test and bounded by the Playwright timeout.

## Verdict

**pass — crutch density did not grow; no new workaround, bypass, or duplicated
path was introduced by this unit execution.**
