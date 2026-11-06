# s13 independent verification — notebook-search-deploy-e2e

- Unit: `notebook-search-deploy-e2e` (ORC E8895, s20 fan-out, u03)
- Repo: `/workspace/projects/notebook-ae079e5c-u03`
- Branch: `orc-exec-E8895-s20.sde_5fexecution-u03`
- HEAD: `d9112d4acdb796445b66d994de1d75bf8650c0e9` (verified, clean working tree)
- Unit base: `326ae62fce7d6513c2b389750b4f5ebed278d861` (s20 fan-out STOP report)
- verified_by: `architect` (independent verification; not the unit author)
- Date: 2026-11-06 (UTC)
- Tooling: node v20.19.2, Playwright 1.64.1 (`@playwright/test`, from `/workspace/projects/notebook/node_modules`)
- Deploy: not attempted (out of scope for this verification)

## Verdict: **pass**

All acceptance criteria for the unit deliverables are met. Two environmental/context
notes are recorded at the end; neither changes the verdict.

## Criteria and results

### 1. `web/e2e/notes-search.spec.js` — PASS

- Exactly 6 real `test("...")` scenarios:
  - `SEARCH-E2E-1 search finds matching note` (line 122)
  - `SEARCH-E2E-2 non-matching query shows the search empty state` (line 141)
  - `SEARCH-E2E-3 match is case-insensitive` (line 161)
  - `SEARCH-E2E-4 clear restores the full list` (line 180)
  - `SEARCH-E2E-5 create while query active re-applies the filter` (line 204)
  - `SEARCH-E2E-6 delete while query active keeps the filter consistent` (line 233)
- No skips/fixmes/only:
  `grep -nE "test\.(skip|fixme|only)|describe\.(skip|only)|xit\(|xdescribe\(" web/e2e/notes-search.spec.js`
  → no matches (`NO skips/fixme/only`).
- One screenshot per scenario: exactly six `await shot(...)` calls (lines 138, 158,
  177, 201, 230, 281), one inside each test, with distinct filenames
  `SEARCH-E2E-1..6` written under `doc/идеи/f-v4-note-search/screenshots/`.
- Scenario coverage matches the required set (find / non-match empty state /
  case-insensitive / clear / create-while-query / delete-while-query); each asserts
  UI behaviour and, where relevant, the POST 201 / DELETE 204 response.

### 2. `doc/идеи/f-v4-note-search/UI-GRAPH.yaml` — PASS

Parsed with `js-yaml` (no new dependency) via `NODE_PATH=/workspace/projects/notebook/node_modules`:

```
schema: ui-graph/v1 status: actualized
search components: notes-search, notes-search-clear, notes-search-empty
search selectors: notes-search, notes-search-clear, notes-search-empty
search states (6): search-idle, search-filtering, search-results, search-empty, search-cleared, search-after-mutation
top-level testids count: 15 declared: 15
all notes states: search-idle, search-filtering, search-results, search-empty, search-cleared, search-after-mutation, loading, empty, list, error, unauthorized
```

Consistency with `doc/идеи/f-v4-note-search/spec/core.md` §3 (UI contract):
- labelled search input `data-testid="notes-search"` → present;
- clear control with accessible name → `notes-search-clear` button (`label: "Очистить поиск (clear)"`);
- client-side filtering with no per-keystroke request → `search-filtering` state;
- `data-testid="notes-search-empty"` only for non-empty query with zero matches →
  `search-empty` state, explicitly keeps `notes-empty` reserved for an empty server list;
- create/delete re-apply the active query → `search-after-mutation` state;
- clear restores the full list and returns to idle → `search-cleared` / `search-idle`.
The graph defines exactly six `search-*` states, matching the contract behaviours.

### 3. Package/lock/deploy files unchanged vs base — PASS

Base `326ae62` (unit base):

```
$ git diff --name-status 326ae62..HEAD -- package.json package-lock.json deploy/path1/e2e-preview.sh deploy/path1/preview-deploy.sh
(no output)
```

Blob identities are identical at HEAD and base:

| file | HEAD blob | base blob |
|---|---|---|
| `package.json` | `63d01f35273323a16790c281fd9cf6ff7fda2184` | `63d01f35273323a16790c281fd9cf6ff7fda2184` |
| `package-lock.json` | `7a93e3f6c2c298037a367892a961e14916fd4087` | `7a93e3f6c2c298037a367892a961e14916fd4087` |
| `deploy/path1/e2e-preview.sh` | `43b3c2cc5f1fdc86411f63a5c88abd363df01e92` | `43b3c2cc5f1fdc86411f63a5c88abd363df01e92` |
| `deploy/path1/preview-deploy.sh` | `12b700d7eb05add58c7e6d1e76ee4e27bbd48949` | `12b700d7eb05add58c7e6d1e76ee4e27bbd48949` |

Commit scope confirms the unit touched only its deliverables: `c48c8eb` changed
`web/e2e/notes-search.spec.js`, `UI-GRAPH.yaml`, `unit-plan.md`, `evidence.txt`;
`d9112d4` added `s12-check.md`/`evidence.txt` updates. No package or deploy edits.

### 4. Command runs — PASS

```
$ cd /workspace/projects/notebook-ae079e5c-u03
$ node --check web/e2e/notes-search.spec.js
(no output)
exit=0
```

Playwright discovery (from the project repo cwd, because the worktree has no
`node_modules`; the config is the worktree's, so `testDir` resolves to the
worktree's `web/e2e`):

```
$ cd /workspace/projects/notebook && \
  NODE_PATH=/workspace/projects/notebook/node_modules \
  npx --no-install playwright test \
    --config /workspace/projects/notebook-ae079e5c-u03/playwright.config.js \
    --list
Listing tests:
  [chromium] › auth-notes.spec.js:67:1 › E2E-1 register: valid account redirects to /login with username prefilled
  [chromium] › auth-notes.spec.js:82:1 › E2E-2 login and token: 200 stores notebook.token and opens /notes
  [chromium] › auth-notes.spec.js:96:1 › E2E-3 create note: Add renders #id text in notes-list
  [chromium] › auth-notes.spec.js:108:1 › E2E-4 reload: note stays visible after page.reload()
  [chromium] › auth-notes.spec.js:121:1 › E2E-5 delete note: 204 removes the row and empty state appears
  [chromium] › auth-notes.spec.js:135:1 › E2E-6 isolation: user B cannot see or delete user A's note
  [chromium] › auth-notes.spec.js:168:1 › E2E-7 unauthenticated GET /api/notes returns 401 with WWW-Authenticate
  [chromium] › notes-search.spec.js:122:1 › SEARCH-E2E-1 search finds matching note
  [chromium] › notes-search.spec.js:141:1 › SEARCH-E2E-2 non-matching query shows the search empty state
  [chromium] › notes-search.spec.js:161:1 › SEARCH-E2E-3 match is case-insensitive
  [chromium] › notes-search.spec.js:180:1 › SEARCH-E2E-4 clear restores the full list
  [chromium] › notes-search.spec.js:204:1 › SEARCH-E2E-5 create while query active re-applies the filter
  [chromium] › notes-search.spec.js:233:1 › SEARCH-E2E-6 delete while query active keeps the filter consistent
Total: 13 tests in 2 files
exit=0
```

Equivalent run from inside the worktree using the absolute CLI also listed the
same 13 tests with exit 0:

```
$ cd /workspace/projects/notebook-ae079e5c-u03 && \
  NODE_PATH=/workspace/projects/notebook/node_modules \
  node /workspace/projects/notebook/node_modules/@playwright/test/cli.js test --list
...
Total: 13 tests in 2 files
exit=0
```

`npx --no-install playwright test --list` run literally from the worktree fails
before test discovery because `npx` looks for a local `node_modules` (absent and
gitignored) and cancels (`npm ERR! canceled`, exit 1). This is an environment
resolution issue, not a test/discovery failure; the successful runs above use the
pinned project dependency `@playwright/test@1.64.1` (`playwright --version` →
`Version 1.64.1`), which is the version required by `package.json`.

## Notes (non-blocking)

1. The worktree's `web/index.html`/`web/app.js` are the pre-integration f-v3
   sources and do not yet contain `notes-search*`. The search UI exists on the
   UI source branch `validation/platform-dev-20261106` (`3bbd98b`), which is the
   `actualized_from` source declared in `UI-GRAPH.yaml`. Therefore the six E2E
   scenarios can only run green against the integrated preview stand that includes
   T0002 (`notebook-search-ui`); live execution is deferred to s20c as planned.
   This does not affect the criteria for this unit (spec + graph), but the
   integrator must ensure the s20c stand contains the T0002 search UI.
2. The clear control is asserted via `notes-search-clear` with an accessible-name
   fallback (`/clear|очист|сброс|×/i`) in the spec. The contract requires only an
   accessible name, and the graph declares `notes-search-clear`, so both are
   consistent.
