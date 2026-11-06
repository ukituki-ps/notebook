# s18 unit report — notebook-search-deploy-e2e

| Field | Value |
|---|---|
| Unit | `notebook-search-deploy-e2e` (T0008, T0009, T0010) |
| Feature | `f-v4-note-search` |
| ORC execution | `E8363-s20.sde_5fexecution-u03` (s20 fan-out, unit u03) |
| Worktree | `/workspace/projects/notebook-e8363-u03` |
| Branch | `orc-exec-E8363-s20.sde_5fexecution-u03` |
| HEAD | `9ceafdbd1bede428097d784539093092d0c9156f` |
| SDE / domain | `sde-infra` / `notebook-deploy` |
| Scenario ids | `SEARCH-E2E-1..SEARCH-E2E-6` |
| Live E2E | deferred to s20c (host runner) |
| Verdict | **PASS / clean** |

## Outcome

The deploy/E2E unit of f-v4-note-search is verified as complete and consistent
at this head. The six Playwright search scenarios exist, contain no bypasses,
and are discoverable through the unchanged `playwright.config.js`. The
integration smoke remains the auth/notes API check (`E2E_API_ONLY=1`) with no
search assertion. Playwright remains pinned at 1.64.1, `path1.project.json`
keeps its integration command and `UI-E2E-PREVIEW` oracle, and the UI graph is
the planned E8363 graph that s21 will actualize from code. No deploy script,
package file, or application source was changed.

## Files created/updated by this unit

Created:

- `artifacts/units/notebook-search-deploy-e2e/s10-unit-plan.md`
- `artifacts/units/notebook-search-deploy-e2e/s11-execution.md`
- `artifacts/units/notebook-search-deploy-e2e/s13-verify-input.md`
- `artifacts/units/notebook-search-deploy-e2e/s18-unit-report.md`

Updated in place (the s12/s14–s17 record names already existed from a prior
execution and were rewritten for E8363):

- `artifacts/units/notebook-search-deploy-e2e/s12-check.md`
- `artifacts/units/notebook-search-deploy-e2e/s14-quality.md`
- `artifacts/units/notebook-search-deploy-e2e/s15-regression.md`
- `artifacts/units/notebook-search-deploy-e2e/s16-spec-sync.md`
- `artifacts/units/notebook-search-deploy-e2e/s17-verdict.md`

Not touched: application sources, `web/e2e/*.spec.js`, `deploy/path1/*.sh`,
`package.json`, `package-lock.json`, `path1.project.json`, `UI-GRAPH.yaml`.
No `git add`/`commit`/`push`/`checkout`/`reset` was run; the coordinator owns
the commit.

## Code changed?

**No production or test code changed.** Only documentation artifacts under
`artifacts/units/notebook-search-deploy-e2e/` were written. `git status` before
the artifact writes was clean.

## Commands and results

| Command | Result |
|---|---|
| `go build ./...` | exit 0 |
| `go test -count=1 ./...` | `ok github.com/ukituki-ps/notebook 2.750s`, exit 0 |
| `node --check web/e2e/notes-search.spec.js` | exit 0 |
| pinned Playwright `test --list` (worktree config, `NODE_PATH=/workspace/projects/notebook/node_modules`) | `Total: 13 tests in 2 files`, exit 0 |
| pinned Playwright `test --list --grep SEARCH-E2E` with `E2E_BASE_URL=https://test2.nexus.ukituki.tech` | `Total: 6 tests in 1 file`, exit 0 |
| `npx --no-install playwright --version` (project repo) | `Version 1.64.1` |
| `python3` parse of `path1.project.json` | integration command and `UI-E2E-PREVIEW` present, OK |
| `git diff --stat` for protected package/deploy files | empty |
| `grep -nE 'q=\|search\|SEARCH' deploy/path1/e2e-preview.sh` | no matches |

### Discovery output (abridged)

```
[chromium] › auth-notes.spec.js:67:1   › E2E-1 ... 
...
[chromium] › auth-notes.spec.js:168:1  › E2E-7 ...
[chromium] › notes-search.spec.js:122:1 › SEARCH-E2E-1 search finds matching note
[chromium] › notes-search.spec.js:141:1 › SEARCH-E2E-2 non-matching query shows the search empty state
[chromium] › notes-search.spec.js:161:1 › SEARCH-E2E-3 match is case-insensitive
[chromium] › notes-search.spec.js:180:1 › SEARCH-E2E-4 clear restores the full list
[chromium] › notes-search.spec.js:204:1 › SEARCH-E2E-5 create while query active re-applies the filter
[chromium] › notes-search.spec.js:233:1 › SEARCH-E2E-6 delete while query active keeps the filter consistent
Total: 13 tests in 2 files
```

## Verification detail

- **Scenarios:** exactly six `test(...)` declarations, ids `SEARCH-E2E-1..6`;
  no `skip`/`fixme`/`only`; six scenario-specific `shot()` calls.
- **Test2 runnability:** all navigation/API calls are baseURL-relative and the
  config reads `E2E_BASE_URL` (default `http://127.0.0.1:9082`); listing with
  the test2 URL succeeds. Live pass/fail is s20c.
- **API smoke split:** `deploy/path1/e2e-preview.sh` contains no search `q=`
  logic and exits before Playwright when `E2E_API_ONLY=1`.
- **Pin:** `@playwright/test`/`playwright`/`playwright-core` all `1.64.1` in
  `package.json` and lock.
- **Graph:** `schema: ui-graph/v1`, `feature_id: f-v4-note-search`,
  `execution_id: E8363`, `status: planned`, `source: design`; s21 actualizes.
- **Protected files:** byte-identical at this head (empty diff).

## Findings and blockers

- **Blockers:** none.
- **Finding (environment, non-blocking):** a literal in-worktree
  `npx --no-install playwright test --list` fails (`npm ERR! canceled`) because
  the worktree has no `node_modules` (test-only deps are gitignored). Discovery
  was proven with the pinned repository dependency. The stand runner installs
  deps fail-close, so s20c is unaffected.
- **Finding (provenance, non-blocking):** the artifact directory still has
  tracked files from the prior E8895 execution (`unit-plan.md`, `evidence.txt`,
  `s13-verify.md`). They are not part of the E8363 record set; the coordinator
  may retire them when committing if the unit layout should contain only the
  E8363 files.
- **Residual risk:** live browser behaviour is unverified here by design; s20c
  is the authoritative gate and needs a stand built from an integrated tree
  containing the search UI.

## Handoff

1. Coordinator commits/pushes the E8363 artifact set; no code diff is expected.
2. s20c runs the full Playwright suite on `test2` (7 auth + 6 search).
3. s21 actualizes `UI-GRAPH.yaml` from code and closes T0010.
