# s13 independent verification — notebook-search-deploy-e2e

- Feature: `f-v4-note-search`
- Execution: `E8363-s20.sde_5fexecution-u03`
- Unit: `notebook-search-deploy-e2e` (T0008, T0009, T0010)
- Worktree: `/workspace/projects/notebook-e8363-u03`
- Branch: `orc-exec-E8363-s20.sde_5fexecution-u03`
- HEAD tested (commands executed at): `6a1a34e81ed45f7f7915dd7d9dff2fc0d6310a24`
- Branch tip at report time: `868d15f0ea457de42614b3b22bd5d6f6c1aa57f3`
  (`chore(notebook-search-deploy-e2e): s15 independent regression (E8363)`,
  artifacts only; `git diff 6a1a34e..868d15f -- <source/deploy/config paths>`
  is empty)
- Evidence HEAD in `s13-verify-input.md`: `9ceafdbd1bede428097d784539093092d0c9156f`
- Source equivalence: `git diff --stat 9ceafdb..HEAD` contains only
  `artifacts/units/notebook-search-deploy-e2e/{s10,s11,s12,s15}`; all spec,
  deploy, package, config, and graph files are byte-identical to the evidence
  HEAD.
- Verified by: `architect` (independent verifier; read-only inspection, fresh
  commands, no git write commands, no live stand contacted)
- Toolchain: `go1.24.4 linux/amd64`, `node v20.19.2`,
  `@playwright/test` 1.64.1 (pinned in the project repo)
- Verdict: **PASS**

## Commands reproduced

| # | Command | Exit | Result |
|---|---|---|---|
| 1 | `go test -count=1 ./...` (worktree) | `0` | `ok github.com/ukituki-ps/notebook 2.743s` |
| 2 | `node --check web/e2e/notes-search.spec.js` | `0` | no output |
| 3 | pinned Playwright `test --config <worktree>/playwright.config.js --list` from `/workspace/projects/notebook` with `NODE_PATH=/workspace/projects/notebook/node_modules` | `0` | `Total: 13 tests in 2 files` (7 auth + 6 search) |
| 4 | same, `E2E_BASE_URL=https://test2.nexus.ukituki.tech`, `--list --grep SEARCH-E2E` | `0` | `Total: 6 tests in 1 file` |
| 5 | `npx --no-install playwright --version` (project repo) | `0` | `Version 1.64.1` |

Discovery listing (search subset):

```
notes-search.spec.js:122:1 › SEARCH-E2E-1 search finds matching note
notes-search.spec.js:141:1 › SEARCH-E2E-2 non-matching query shows the search empty state
notes-search.spec.js:161:1 › SEARCH-E2E-3 match is case-insensitive
notes-search.spec.js:180:1 › SEARCH-E2E-4 clear restores the full list
notes-search.spec.js:204:1 › SEARCH-E2E-5 create while query active re-applies the filter
notes-search.spec.js:233:1 › SEARCH-E2E-6 delete while query active keeps the filter consistent
Total: 6 tests in 1 file
```

The full listing also contains the unchanged auth suite `E2E-1..E2E-7`
(`web/e2e/auth-notes.spec.js`), giving 13 tests / 2 files.

## Content hashes (independently recomputed, match `s13-verify-input.md`)

```
bc4cd9f252711c7f27256dbe344f1bece2d18a8f1b82959a97cbc1fbf3d295ee  web/e2e/notes-search.spec.js
9a06fc25836615748c4ec4651c485ad96d06535facd35edb600333e162c28e57  deploy/path1/e2e-preview.sh
f1354cf8054081439f7603d4b7d962d8f7eea7fb8dd9e8779a0dad08810b243d  package.json
cc36a72d3e7945e6242be6c6b84e520139a671d540b4cec9a9e93f69b20604af  package-lock.json
927a8e0b26457e4c72df24a7bbe4058ea52c1056f35fd2f04503cc485e7f6f0a  playwright.config.js
cbfeb8830d0b09e818d1c7ab946dcf1d1a512851a82c331cab2f695acac8df08  path1.project.json
c8d6facfee352bd189857bf55d2ef2dca2a058ae12cc71b1d2f46b3b0790c9d2  doc/идеи/f-v4-note-search/UI-GRAPH.yaml
```

## Scenario checks (`web/e2e/notes-search.spec.js`)

- Exactly six real `test(...)` declarations:
  `SEARCH-E2E-1` (line 122), `-2` (141), `-3` (161), `-4` (180), `-5` (204),
  `-6` (233).
- No bypasses:
  `grep -nE 'test\.(skip|fixme|only)|describe\.(skip|only)|xit\(|xdescribe\('`
  → no matches.
- Exactly one screenshot call per scenario: lines 138, 158, 177, 201, 230, 281
  write `SEARCH-E2E-1..6.png` under
  `doc/идеи/f-v4-note-search/screenshots/`.
- Each test registers a unique user, logs in through the real UI
  (`loginViaUI`), and creates its own notes; no test depends on another's state.
  `fullyParallel: true` is therefore safe.
- Scenario semantics match T0008/spec: find-and-hide, non-match search-empty
  (with `notes-empty` hidden), case-insensitive, clear-restores, create-while-
  active (non-matching hidden, matching appears, query retained), delete-while-
  active (last match → search-empty, then clear restores the outsider).
- No user-B isolation scenario was added to the search spec; isolation remains
  auth `E2E-6` plus `TestNotesSearchIsolation`.
- The clear control prefers `notes-search-clear` with an accessible-name
  fallback; this matches the contract's accessible-name requirement without
  weakening any search assertion.

## Integration smoke / deploy checks

- `grep -nE 'q=|search|SEARCH' deploy/path1/e2e-preview.sh` → no matches; the
  API-only smoke has no search assertion.
- `E2E_API_ONLY=1` path prints `e2e-preview: API-only mode (Playwright -> s20c)`
  and exits `0` **before** the Playwright section (`deploy/path1/e2e-preview.sh:188-191`).
- `path1.project.json` parses:
  - `integration.command = "E2E_API_ONLY=1 bash deploy/path1/e2e-preview.sh"`;
  - `audit.oracles["UI-E2E-PREVIEW"]` = healthz `200` + unauth `GET /api/notes`
    `401`.
- `UI-GRAPH.yaml` header: `schema: ui-graph/v1`, `feature_id: f-v4-note-search`,
  `platform: web`, `execution_id: E8363`, `status: planned`, `source: design`;
  from-code actualization is explicitly deferred to s21.

## Protected-file check

- `git diff --stat 9ceafdb..HEAD -- package.json package-lock.json
  deploy/path1/e2e-preview.sh deploy/path1/preview-deploy.sh
  web/e2e/notes-search.spec.js web/e2e/auth-notes.spec.js playwright.config.js
  path1.project.json doc/идеи/f-v4-note-search/UI-GRAPH.yaml` → empty.
- Additionally `git diff --stat 5935e148584b5fef28bd77ac4e45b800f10da03b..HEAD --
  deploy/path1/e2e-preview.sh deploy/path1/preview-deploy.sh package.json
  package-lock.json` → empty, so the deploy/package surface is unchanged over the
  whole feature branch as well.
- Playwright is pinned at exactly `1.64.1` in `package.json` and
  `package-lock.json`; the CLI reports `Version 1.64.1`.

## Notes / limitations

- Live browser execution against `test2` is intentionally **not** run here; it is
  the s20c gate. This verification proves syntax, discovery, configuration,
  scenario shape, protected-file stability, and integration/E2E separation.
- The worktree has no local `node_modules` (gitignored); discovery was run with
  the repository's pinned dependency via `NODE_PATH`, which is an environment
  resolution detail, not a spec defect. The config's `testDir: "web/e2e"`
  resolves relative to the worktree config, so the listed specs are this
  worktree's files.
- No FAIL and no blocking finding.
