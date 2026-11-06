# s14 quality — notebook-search-deploy-e2e

- Feature: `f-v4-note-search`
- Execution: `E8363-s20.sde_5fexecution-u03`
- Unit: `notebook-search-deploy-e2e` (T0008, T0009, T0010)
- Worktree: `/workspace/projects/notebook-e8363-u03`
- Branch: `orc-exec-E8363-s20.sde_5fexecution-u03`
- HEAD reviewed: `6a1a34e81ed45f7f7915dd7d9dff2fc0d6310a24`; branch tip at
  report time `868d15f` (artifacts-only s15 commit, source unchanged)
- Verdict: **PASS** — `crutch_density_grew: false`

## Maintainability

- The Playwright spec is organized around small helpers:
  `registerUser`, `loginViaUI`, `createUserAndLogin`, `submitNote`, `addNote`,
  `visibleItems`, `setQuery`, `clearControl`, `clearQuery`, `expectSearchEmpty`,
  `shot`. Each helper has one responsibility and is reused by the six tests.
- Tests wait on real conditions: `waitForResponse` for POST 201 and DELETE 204,
  `waitForURL`, `toBeHidden`/`toBeVisible`, and input-enabled checks. There are
  no `waitForTimeout` sleeps, so the suite is deterministic and not timing-
  dependent.
- Unique usernames/tokens (`uniqueUsername`, `uniqueToken`) make tests
  independent and safe under `fullyParallel: true`.
- The integration path (`E2E_API_ONLY=1`) remains a small, fast, explicit split
  from Playwright, avoiding duplicated search coverage in the API smoke.

## Scope discipline

- This unit made **no source change**. `git diff --stat 9ceafdb..HEAD` touches
  only `artifacts/units/notebook-search-deploy-e2e/{s10,s11,s12}`.
- No application, deploy-script, package/lock, Playwright-config, path-1, or
  graph edit.
- `UI-GRAPH.yaml` correctly remains `status: planned` / `source: design`; s21
  owns from-code actualization. This unit did not hand-write an "actualized"
  graph ahead of the gate.

## Unrelated changes

None. Protected files are byte-identical to both the unit base and the feature
base (`5935e148`); the diff over the whole feature branch for deploy scripts and
package files is empty.

## Test strength

- Exactly six scenario-specific tests, matching T0008/spec semantics, each with
  a distinct assertion set:
  - `SEARCH-E2E-1` visible/hidden rows + count 1 + search-empty/notes-empty hidden;
  - `SEARCH-E2E-2` zero rows + search-empty visible + `notes-empty` hidden +
    search input still visible/enabled/query-retained;
  - `SEARCH-E2E-3` lower-case query vs upper-case stored text;
  - `SEARCH-E2E-4` clear restores both rows and hides search-empty;
  - `SEARCH-E2E-5` create with active query: non-matching hidden, matching
    visible, query retained;
  - `SEARCH-E2E-6` delete under query, last-match removal shows search-empty and
    not `notes-empty`, then clear restores the outsider.
- No `skip`/`fixme`/`only`/`xit`/`xdescribe`; a missing browser or stand fails
  the run (fail-close).
- One screenshot per scenario id for s20c `pngdiff`.
- Auth regression suite `E2E-1..E2E-7` remains discovered and unchanged (7
  tests), so removal/renaming would be visible immediately.

## Residual risks

- Live browser behaviour is unproven here by design; s20c is the authoritative
  gate, and the stand must contain the T0002 search UI.
- The worktree has no local `node_modules` (gitignored); literal in-worktree
  `npx --no-install` fails before discovery. Discovery is reproduced with the
  repository's pinned `@playwright/test@1.64.1` via `NODE_PATH`; the stand runner
  installs deps fail-close.
- The clear-control locator allows an accessible-name fallback in addition to
  the `notes-search-clear` testid. This is broader than a strict testid match,
  but the contract only requires an accessible name; every assertion after the
  click is still strict on list/search-empty state.
- Screenshots are written to the feature screenshots directory at run time; they
  are per-run evidence and must not be committed (T0008 forbidden list).

## Conclusion

The deploy/E2E unit is contract-faithful, properly split from the API smoke,
dependency-stable, and free of unrelated changes at the tested HEAD. No defect
and no blocking finding.
