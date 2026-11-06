# s11 execution — notebook-search-deploy-e2e

| Field | Value |
|---|---|
| Unit | `notebook-search-deploy-e2e` (T0008, T0009, T0010) |
| Feature | `f-v4-note-search` |
| ORC execution | `E8363-s20.sde_5fexecution-u03` |
| Worktree | `/workspace/projects/notebook-e8363-u03` |
| Branch | `orc-exec-E8363-s20.sde_5fexecution-u03` |
| HEAD | `9ceafdbd1bede428097d784539093092d0c9156f` |
| Date | 2026-11-06 (UTC) |
| Scenario ids | `SEARCH-E2E-1..SEARCH-E2E-6` |
| Code changes by this unit | **none** |
| Verdict | **PASS** |

## What was executed

1. Inspected the worktree git state:
   - `git status --short` → empty (clean working tree at start).
   - `git rev-parse HEAD` → `9ceafdbd1bede428097d784539093092d0c9156f`.
   - `git rev-parse --abbrev-ref HEAD` →
     `orc-exec-E8363-s20.sde_5fexecution-u03`.
2. Read all required inputs: feature brief, change definition, `spec/core.md`,
   `spec/contract-matrix.md`, T0008/T0009/T0010 briefs, both Playwright specs,
   `playwright.config.js`, `path1.project.json`, `deploy/path1/e2e-preview.sh`,
   `UI-GRAPH.yaml`, and the worktree application sources (`main.go`,
   `web/index.html`, `web/app.js`, `web/app.css`, `main_test.go`,
   `web_ui_test.go`).
3. Verified the search implementation at this head (observation only):
   - `main.go` trims/lowercases `q`, lists owner-scoped notes first, then
     filters — `q` can only narrow.
   - `web/index.html` has `notes-search`, `notes-search-clear`,
     `notes-search-empty`, `notes-empty`, `notes-list`, `note-item`.
   - `web/app.js` has a single `renderNotes()` used by load/create/delete and a
     search-empty guard `hasQuery && !noNotes && visible.length === 0`.
4. Ran the executable checks listed in s12.
5. Wrote the s10–s18 records under
   `artifacts/units/notebook-search-deploy-e2e/`.

No file outside `artifacts/units/notebook-search-deploy-e2e/` was written or
modified. No `git add`/`commit`/`push`/`checkout`/`reset` was run.

## Commands and results

| Command (cwd = worktree unless noted) | Result |
|---|---|
| `go build ./...` | exit 0 |
| `go test -count=1 ./...` | `ok github.com/ukituki-ps/notebook 2.750s`, exit 0 |
| `node --check web/e2e/notes-search.spec.js` | exit 0 (no output) |
| `node /workspace/projects/notebook/node_modules/@playwright/test/cli.js test --list` with `NODE_PATH=/workspace/projects/notebook/node_modules` | 13 tests in 2 files, exit 0 (7 auth + 6 search) |
| `cd /workspace/projects/notebook && NODE_PATH=/workspace/projects/notebook/node_modules npx --no-install playwright test --config /workspace/projects/notebook-e8363-u03/playwright.config.js --list --grep SEARCH-E2E` with `E2E_BASE_URL=https://test2.nexus.ukituki.tech` | 6 tests in 1 file, exit 0 |
| `npx --no-install playwright --version` (project repo, pinned dep) | `Version 1.64.1`, exit 0 |
| `python3` JSON parse of `path1.project.json` | `PATH1 JSON: OK`; integration command and `UI-E2E-PREVIEW` present |
| `git diff --stat -- package.json package-lock.json deploy/path1/e2e-preview.sh deploy/path1/preview-deploy.sh` | empty |
| `grep -nE 'q=|search|SEARCH' deploy/path1/e2e-preview.sh` | no matches |

### Environment caveat: in-worktree `npx`

`npx --no-install playwright test --list` run literally from the worktree fails
with `npm ERR! canceled` (exit 1) because the worktree has no `node_modules`
(the test-only dependency is gitignored and not installed here). This is a
dependency-resolution condition, not a spec/discovery failure. Discovery was
proven with the repository's pinned `@playwright/test@1.64.1`:
`NODE_PATH=/workspace/projects/notebook/node_modules` plus either the absolute
CLI or `npx --no-install` from the project directory with the worktree config.
The config's `testDir: "web/e2e"` resolves against the worktree config file, so
the listed specs are this worktree's files (line numbers 122/141/161/180/204/233
confirm the search spec).

## Scenario ids observed in execution

`SEARCH-E2E-1`, `SEARCH-E2E-2`, `SEARCH-E2E-3`, `SEARCH-E2E-4`,
`SEARCH-E2E-5`, `SEARCH-E2E-6` (6 tests in 1 file), plus auth `E2E-1..E2E-7`
(7 tests) for regression discovery.

## Not executed (by design)

- Live E2E against `test2` — s20c under the host runner.
- `E2E_API_ONLY=1 bash deploy/path1/e2e-preview.sh` against a stand — s20a/s20b;
  no stand was deployed or contacted by this unit.
- `go vet` — not requested by this unit's command list; `go build` and
  `go test` were run.

**Execution verdict: PASS** — all non-live checks green; no code changed.
