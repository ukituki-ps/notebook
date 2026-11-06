# s12 unit check — notebook-search-deploy-e2e

| Field | Value |
|---|---|
| Unit | `notebook-search-deploy-e2e` |
| Feature | `f-v4-note-search` |
| ORC execution | `E8363-s20.sde_5fexecution-u03` |
| Worktree | `/workspace/projects/notebook-e8363-u03` |
| Branch | `orc-exec-E8363-s20.sde_5fexecution-u03` |
| Checked HEAD | `9ceafdbd1bede428097d784539093092d0c9156f` |
| Scenario ids | `SEARCH-E2E-1..SEARCH-E2E-6` |
| Verdict | **PASS** |

## Check matrix

| # | Check | Command / method | Result |
|---|---|---|---|
| 1 | Go build | `go build ./...` | exit 0 |
| 2 | Go tests | `go test -count=1 ./...` | `ok github.com/ukituki-ps/notebook 2.750s`, exit 0 |
| 3 | Spec syntax | `node --check web/e2e/notes-search.spec.js` | exit 0 |
| 4 | Exactly 6 search scenarios | `grep -nE '^test\(' web/e2e/notes-search.spec.js` | 6 declarations, ids SEARCH-E2E-1..6 |
| 5 | No bypasses | `grep -nE 'test\.(skip\|fixme\|only)\|describe\.(skip\|only)\|xit\(\|xdescribe\(' ...` | no matches |
| 6 | One screenshot per id | `grep -n 'await shot(' ...` | 6 calls: 138, 158, 177, 201, 230, 281 |
| 7 | Playwright discovery | pinned CLI `test --list` with `NODE_PATH=/workspace/projects/notebook/node_modules` | 13 tests / 2 files, exit 0 |
| 8 | Search-only discovery | `npx --no-install playwright test --config <worktree>/playwright.config.js --list --grep SEARCH-E2E`, `E2E_BASE_URL=https://test2.nexus.ukituki.tech` | 6 tests / 1 file, exit 0 |
| 9 | Playwright pin | `package.json`, `package-lock.json`, `npx --no-install playwright --version` | `1.64.1` in both files; CLI reports `Version 1.64.1` |
| 10 | Integration smoke auth/notes-only | read + grep `deploy/path1/e2e-preview.sh` | no `q=`/`search`/`SEARCH` strings; `E2E_API_ONLY=1` exits 0 before Playwright |
| 11 | path1 integration command/oracle | parse `path1.project.json` | integration = `E2E_API_ONLY=1 bash deploy/path1/e2e-preview.sh`; `UI-E2E-PREVIEW` = healthz + unauth 401 |
| 12 | No deploy/package changes | `git diff --stat -- package.json package-lock.json deploy/path1/e2e-preview.sh deploy/path1/preview-deploy.sh` | empty |
| 13 | UI graph is planned E8363 | read `UI-GRAPH.yaml` header | `schema: ui-graph/v1`, `feature_id: f-v4-note-search`, `execution_id: E8363`, `status: planned`, `source: design`; s21 actualization noted |
| 14 | Scenario preconditions | static review of spec | each test registers a unique user, logs in via the UI, creates its own notes; user-B isolation intentionally not in this spec |
| 15 | Test2 runnability | spec uses baseURL-relative `page.goto`/`request`; config `baseURL = E2E_BASE_URL` | `E2E_BASE_URL=https://test2.nexus.ukituki.tech ... --list` exit 0 |

## Commands (exact)

```
go build ./...
go test -count=1 ./...
node --check web/e2e/notes-search.spec.js

cd /workspace/projects/notebook
NODE_PATH=/workspace/projects/notebook/node_modules \
  npx --no-install playwright test \
  --config /workspace/projects/notebook-e8363-u03/playwright.config.js --list

cd /workspace/projects/notebook
NODE_PATH=/workspace/projects/notebook/node_modules \
E2E_BASE_URL=https://test2.nexus.ukituki.tech \
  npx --no-install playwright test \
  --config /workspace/projects/notebook-e8363-u03/playwright.config.js \
  --list --grep SEARCH-E2E
```

## Scenario id check

| id | Present | Runnable shape |
|---|---|---|
| `SEARCH-E2E-1` | yes (line 122) | find one, hide other, `visibleItems == 1` |
| `SEARCH-E2E-2` | yes (line 141) | zero rows, `notes-search-empty` visible, `notes-empty` hidden |
| `SEARCH-E2E-3` | yes (line 161) | lower-case query vs upper-case stored text |
| `SEARCH-E2E-4` | yes (line 180) | clear restores both rows, search-empty hidden |
| `SEARCH-E2E-5` | yes (line 204) | create non-matching (hidden) and matching (visible), query retained |
| `SEARCH-E2E-6` | yes (line 233) | delete one match, then last match -> search-empty; clear restores outsider |

## Live execution

Not run by this unit. `s20c` runs:
`E2E_BASE_URL=https://test2.nexus.ukituki.tech npx --no-install playwright test`
(or the targeted `web/e2e/notes-search.spec.js`) under the host runner that has
Chromium. This unit proves discovery/configuration, not live browser behaviour.

**Check verdict: PASS.** One environment caveat (in-worktree `npx` without
`node_modules`) is documented in s11; it does not affect discovery, which was
proven with the pinned dependency.
