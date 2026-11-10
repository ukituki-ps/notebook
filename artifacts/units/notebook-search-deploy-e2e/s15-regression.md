# s15 unit regression — notebook-search-deploy-e2e (U03)

- **Execution:** `E6636-s20.sde_5fexecution-u03`
- **Step:** `s15.unit_regression` · role `auditor` (independent of `sde-infra`)
- **Unit:** `notebook-search-deploy-e2e` · domain `notebook-e2e` · `change_class: plain`
- **Branch:** `orc-exec-E6636-s20.sde_5fexecution-u03`
- **Base:** `1722a1e51b3734284c6a9103a4ed2e5ab5793386`
- **HEAD at audit:** `099e750873e1350442f490f9a0ac8ead6a050f01` (s14)
- **Baseline steps:** s13.unit_verify (PASS), s14.unit_quality (PASS)
- **Stand policy:** `test2` only under the E6636 lease; runtime E2E belongs to s20c.

## regression_status: **pass**

**new_findings: []** — this unit introduces no regression.

## 1. Diff scope — PASS

`git diff --name-status 1722a1e5..HEAD` contains **only artifacts** added by the
unit's own steps:

| File | Status |
|---|---|
| `artifacts/units/notebook-search-deploy-e2e/s12-check.md` | M |
| `artifacts/units/notebook-search-deploy-e2e/s13-verify.md` | M |
| `artifacts/units/notebook-search-deploy-e2e/s14-quality.md` | M |
| `artifacts/units/notebook-search-deploy-e2e/steps/s11.md` | A |
| `artifacts/units/notebook-search-deploy-e2e/unit-plan.md` | M |
| `artifacts/units/unit/unit-plan.md` | A |

Protected paths are byte-identical to base (empty diff):

```text
$ git diff --name-only 1722a1e5..HEAD -- main.go main_test.go web_ui_test.go \
    web/index.html web/app.js web/app.css web/e2e/auth-notes.spec.js \
    deploy/path1/preview-deploy.sh playwright.config.js package.json \
    package-lock.json design arch
(no output)
```

So the unit changed no product code, no dependency, no deploy/preview adapter,
no design-system artifact, and no pre-existing E2E spec.

## 2. Existing behaviour preserved — PASS

| Check | Result |
|---|---|
| `notes-search.spec.js` `test()` count | 23 (`SEARCH-E2E-1..20` + `CR-01..03`) |
| `auth-notes.spec.js` `test()` count | 7 (pre-existing spec intact) |
| `skip` / `fixme` / `only` in both specs + `playwright.config.js` | 0 |
| `playwright.config.js` `forbidOnly` | set when `CI` is truthy (line 20) |
| `bash -n deploy/path1/e2e-preview.sh` | exit 0 |
| `bash -n deploy/path1/preview-deploy.sh` | exit 0 |
| Protected files present/non-empty | `main.go`, `main_test.go`, `web_ui_test.go`, `web/index.html`, `web/app.js`, `web/app.css`, `web/e2e/auth-notes.spec.js` — all ok |

Because the unit tree is identical to base for every runtime file, the Go and
web oracle surface is unchanged by this unit; no existing test or adapter was
deleted, renamed, or weakened.

## 3. Go build — not executable here (environment), no unit delta

The authoring container has no Go (or Node/Python) toolchain: only `bash` is
present, and `GOWORK=off go build ./...` returns `go: command not found`.
This does not block the regression verdict because the unit has **zero Go
deltas** (`main.go`, `main_test.go`, `web_ui_test.go` unchanged vs base), so the
Go build result cannot be affected by it. The build/oracle must be re-run in a
toolchain-enabled step; no claim is made here beyond the empty Go diff.

## 4. Runtime regression — deferred to s20c

Browser-level regression (flake rate, screenshots, `pngdiff`, real
`playwright test` on `test2`) can only be judged at s20c on the leased stand.
This step records no runtime claim; a red s20c run reopens the unit via the
normal regression path.

## Verdict

**pass — `new_findings: []`; no product, dependency, deploy, or oracle file was
touched by this unit, and all protected paths are unchanged from base.**
