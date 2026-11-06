# s16 spec sync — notebook-search-deploy-e2e

- Feature: `f-v4-note-search`
- Execution: `E8363-s20.sde_5fexecution-u03`
- Unit: `notebook-search-deploy-e2e` (T0008, T0009, T0010)
- Branch: `orc-exec-E8363-s20.sde_5fexecution-u03`
- HEAD checked: `6a1a34e81ed45f7f7915dd7d9dff2fc0d6310a24`
  (branch tip at report time `868d15f`, artifacts-only s15 commit; source
  identical to evidence HEAD `9ceafdb`)
- Spec inputs: `spec/core.md` §3 (UI + E2E) and §4; `spec/contract-matrix.md`;
  `change-definition.md` C3/C4; T0008/T0009/T0010 briefs; `feature-brief.md`.
- `spec_synced: true`, `drift_count: 0` for this unit's surface

## UI/E2E contract rows owned or co-owned by this unit

| Row | Contract | Sync evidence | Status |
|---|---|---|---|
| U-03 | typing filters the loaded list client-side, no request per keystroke | `SEARCH-E2E-1` asserts filtering; the spec issues no per-keystroke request | synced |
| U-04 | case-insensitive UI match | `SEARCH-E2E-3` (lower-case query vs `Buy MILK CASE-…`) | synced |
| U-05 | search-empty only for non-empty query over non-empty list; copy/role/aria | `SEARCH-E2E-2` (visible, `notes-empty` hidden), `SEARCH-E2E-6` (after last match) | synced |
| U-06 | genuinely empty server list uses `notes-empty` | preserved; auth `E2E-5` remains discovered and unchanged | synced |
| U-07 | clear restores full list and hides search-empty | `SEARCH-E2E-4` | synced |
| U-08 | create while query active re-applies filter | `SEARCH-E2E-5` (non-matching hidden, matching appears, query retained) | synced |
| U-09 | delete while query active re-applies; last match → search-empty | `SEARCH-E2E-6` | synced |
| U-10 | login precedes search; user-B isolation stays auth E2E-6 | every search test logs in via the UI; no isolation scenario added to the search spec | synced |
| U-11 | loading/error/401 unchanged; controls disabled while loading | `loginViaUI` waits for `notes-loading` hidden and `note-input` enabled; auth `E2E-7` unchanged | synced |

API rows `C-01..C-30` are Go-oracle territory owned by `notebook-search-api`;
they are green through `go test -count=1 ./...` but this unit does not claim them
as its own oracles.

## Scenario-id sync

`SEARCH-E2E-1..6` are present exactly once each in
`web/e2e/notes-search.spec.js` (lines 122/141/161/180/204/233), listed by the
pinned Playwright CLI as 6 tests in 1 file, and match T0008/spec semantics:
find, not-found empty state, case-insensitive, clear, create-active,
delete-active.

## Deploy/adapter sync (T0009, T0010)

| Requirement | Evidence | Status |
|---|---|---|
| Integration smoke is auth/notes only, no search `q=` | `grep -nE 'q=|search|SEARCH' deploy/path1/e2e-preview.sh` → no matches | synced |
| API-only mode exits before Playwright | `deploy/path1/e2e-preview.sh:188-191` exits `0` before the Playwright section | synced |
| `path1.project.json` integration command unchanged | parsed `integration.command = E2E_API_ONLY=1 bash deploy/path1/e2e-preview.sh` | synced |
| `UI-E2E-PREVIEW` oracle unchanged | healthz `200` + unauth `GET /api/notes` `401` | synced |
| Playwright auto-discovers the search spec | `playwright.config.js` `testDir: "web/e2e"`; listing = 13 tests / 2 files | synced |
| Playwright pinned at 1.64.1 | `package.json` and `package-lock.json` both 1.64.1; CLI `Version 1.64.1` | synced |
| No protected deploy/package changes | `git diff --stat 9ceafdb..HEAD -- …` empty; also empty from `5935e148` for deploy/package | synced |
| UI graph planned E8363, actualized at s21 | `UI-GRAPH.yaml`: `schema: ui-graph/v1`, `status: planned`, `source: design`, `execution_id: E8363` | synced |

## Invariant mapping

- `INV-SEARCH-UI-FILTER` → `SEARCH-E2E-1`, `-3`, `-5`, `-6` — synced.
- `INV-SEARCH-UI-EMPTY` → `SEARCH-E2E-2`, `-6` (distinct from `notes-empty`) —
  synced.
- `INV-SEARCH-UI-TESTIDS` → spec uses `notes-search`, `notes-search-clear`,
  `notes-search-empty`; `TestUISemantics` owns the static assertion — synced.
- `INV-AUTH-REQUIRED` / `INV-USER-ISOLATION` (E2E side) → auth `E2E-6`, `E2E-7`
  remain discovered; no regression — synced.
- `INV-UI-ORACLE` / `INV-UI-E2E-PREVIEW` remain proposed until s20c materializes
  evidence; this unit proves configuration/discovery only — correctly deferred.

## Drift assessment

- No spec/API drift introduced (the unit changes no source).
- No deploy/config drift.
- No testid drift between the planned graph, the DOM, and the E2E spec.
- The graph is intentionally not claimed as actualized; s21 owns that gate.
- Residual: live stand behaviour is proven at s20c, and s21 must re-read the
  integrated code before actualizing the graph.

**Verdict: IN SYNC — `drift_count = 0`, no spec or code change required.**
