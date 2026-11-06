# s10 unit plan — notebook-search-deploy-e2e

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
| Date | 2026-11-06 (UTC) |
| Verdict | **ready to execute** |

## Objective

Prove the deploy/E2E unit of f-v4-note-search is complete and consistent at
this head, without changing application, deploy, package, or spec code:

1. The six Playwright search scenarios exist, are discoverable, and are
   runnable against the `test2` preview stand via `E2E_BASE_URL`.
2. The integration smoke stays auth/notes API only (`E2E_API_ONLY=1`) and has
   no search `q=` assertion.
3. Playwright stays pinned at 1.64.1; `package.json`/`package-lock.json` are
   unchanged.
4. `UI-GRAPH.yaml` is the planned E8363 graph and is actualized only at s21.
5. No deploy-script changes (`deploy/path1/e2e-preview.sh`,
   `deploy/path1/preview-deploy.sh`).

## Inputs to read

- `doc/идеи/f-v4-note-search/feature-brief.md`
- `doc/идеи/f-v4-note-search/change-definition.md`
- `doc/идеи/f-v4-note-search/spec/core.md`
- `doc/идеи/f-v4-note-search/spec/contract-matrix.md`
- `doc/идеи/f-v4-note-search/T0008/brief.md`, `T0009/brief.md`,
  `T0010/brief.md`
- `web/e2e/notes-search.spec.js`, `web/e2e/auth-notes.spec.js`
- `playwright.config.js`, `path1.project.json`
- `deploy/path1/e2e-preview.sh`
- `doc/идеи/f-v4-note-search/UI-GRAPH.yaml`

## Scenario ids in scope

| id | Behaviour |
|---|---|
| `SEARCH-E2E-1` | Search finds the one matching note and hides the other. |
| `SEARCH-E2E-2` | Non-matching query shows `notes-search-empty`, hides `notes-empty`. |
| `SEARCH-E2E-3` | Matching is case-insensitive. |
| `SEARCH-E2E-4` | Clear restores the full list and hides the search-empty state. |
| `SEARCH-E2E-5` | Create while a query is active re-applies the filter. |
| `SEARCH-E2E-6` | Delete while a query is active re-applies the filter; last match removal shows search-empty, not notes-empty. |

User-B isolation is **not** a search-spec scenario; it remains auth `E2E-6`
plus `TestNotesSearchIsolation` (change-definition C3, T0008).

## Plan

1. Read the feature docs, task briefs, both Playwright specs, Playwright and
   path1 configs, the deploy script, and the UI graph.
2. Statically verify the six scenarios: ids, no `skip`/`fixme`/`only`, one
   screenshot per id, login + fixture preconditions, test2-capable base URL.
3. Verify pinning and protected files: `@playwright/test` 1.64.1 in
   `package.json`/lock; no diff for deploy scripts or package files.
4. Verify the integration split: `E2E_API_ONLY=1` exits before Playwright; the
   script contains no `q=`/search assertion; `path1.project.json` keeps
   `integration.command` and the `UI-E2E-PREVIEW` oracle.
5. Verify `UI-GRAPH.yaml` is `status: planned`, `source: design`,
   `execution_id: E8363`, schema `ui-graph/v1`, with s21 reserved for
   from-code actualization.
6. Run executable checks:
   - `go build ./...`
   - `go test -count=1 ./...`
   - `node --check web/e2e/notes-search.spec.js`
   - Playwright `test --list` (proves discovery of 6 search + 7 auth tests)
   - JSON/YAML parse checks for `path1.project.json` and `UI-GRAPH.yaml`
7. Write s10–s18 records. Do not run a live stand E2E; that is s20c under the
   host runner.

## Out of scope

- Editing `web/e2e/notes-search.spec.js`, application sources, deploy scripts,
  `package.json`/`package-lock.json`, or `UI-GRAPH.yaml`.
- Running the live `test2` E2E or deploying a stand (s20b/s20c).
- Committing/pushing (coordinator does that).
- Actualizing `UI-GRAPH.yaml` from code (s21).

## Acceptance criteria and verdict

- 6/6 search scenarios present and listed by Playwright: see s12.
- `go build` and `go test` green: see s12.
- Integration smoke auth/notes-only; Playwright 1.64.1; no deploy changes:
  see s12/s15.
- Graph planned E8363, actualization at s21: see s12/s16.

**Plan verdict: ready to execute.** No blocking dependency at this head; live
execution is intentionally deferred to s20c.
