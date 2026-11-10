# Plan — f-v4-note-search (E6636, s11)

- Execution: **E6636** · step **s11.planner_high_level** · role **planner**
- Saved at **s13.plan_save**; process `path-1.feature` **4.0.0** (entry
  `default`, platform `web`, profile `full`)
- Branch: `dev/path10-runner-13` · base `9e7fae353c61e717505dc40019627a1d7ab48820`
- DS: **Notebook DS 1.0.1** (`ds/v1.0.1`, digest
  `sha256:4e0ef1052a1401a928588445f921f7d231b7c0e7c9b10c181fdbbb439108c85e`,
  constraint `=1.0.1`)
- Change definition: `change-definition.md` (s10 E6636, model artifact
  `f-v4-note-search/change-definition` v2 approved)
- Planned UI graph: `UI-GRAPH.planned.yaml` (s04 E6636, 19 nodes / 18 UI nodes,
  69 edges, 9 states: 8 renderable + `normal = idle`)
- Goal: owner-scoped search over the existing notes API and web view; auth,
  storage, and note lifecycle unchanged.
- Status: plan only. No code/`web/`/`design/` change at s11; s20 implements,
  s20c verifies on `test2`, s22a/s22e/s22b/s22c review, s24 approves.

## Milestone M01 — Search end-to-end (3 units)

s20 fan-out: exactly **3 child executions**, one distinct `session_id` each; the
parent receives only summary/diff/verdict. Each unit brief ≤8 files.

### U01 `notebook-search-api` (agent `sde-backend`)

- `GET /api/notes?q=`: trim; empty/whitespace q → all own notes; non-empty →
  case-insensitive substring; owner predicate before the text predicate; `[]`
  not `null`; auth (`401`) before query handling; `UserID` never exposed.
- 512-byte cap on decoded q → `400 {"error":"query too long"}` before any note
  scan; exactly 512 bytes accepted; cap in bytes, not runes. Existing
  auth/session/create/delete/wire semantics unchanged.
- Files (2): `main.go`, `main_test.go`.
- Acceptance: backend `go build ./...`, `go vet ./...`, `go test -count=1 ./...`
  green; all `TestNotesSearch*` tests (Finds, NotFound, CaseInsensitive,
  Isolation, AuthRequired, EmptyQuery, WhitespaceQuery, Encoding, QueryTooLong,
  incl. exactly-512 accept) pass.

### U02 `notebook-search-ui` (agent `sde-frontend`)

- Search input/filter/clear/search-empty; count `Найдено N`
  (`notes-search-count`, `aria-live=polite`, hidden on empty query); retry
  (`notes-retry`) in error; offline banner (`notes-offline`) + `Проверить сеть`
  (`notes-offline-check`) + offline-zero; zero-notes → base `notes-empty` wins
  and search disabled; Delete `Удалить` + `aria-label="Удалить заметку #N"`;
  query in-memory only; re-apply query after create/delete/reload.
- DS-only: Notebook DS 1.0.1 components/tokens, 0 local instances, no `design/`
  or DS-file edits; path6 gaps `n-count` (GAP-1), `n-delete` (GAP-3), GAP-2/GAP-4
  stay accepted/non-blocking.
- Files (4): `web/index.html`, `web/app.js`, `web/app.css`, `web_ui_test.go`.
- Acceptance: `TestUISemantics` passes; `go test ./...` green; `INV-UI-LABEL`,
  `INV-UI-A11Y-NAME`, `INV-XSS-ESCAPE`, `INV-SEARCH-UI-FILTER`,
  `INV-SEARCH-UI-EMPTY`, `INV-SEARCH-UI-TESTIDS` hold; s22a 0 DS violations.
- **R-1 (closed at base):** the earlier literal `min-height: 44px` oracle
  mismatch is resolved — `web_ui_test.go:360-365` now asserts the DS token
  `min-height: var(--control-height)` and `--control-height: 44px`
  (`web/app.css:14`). U02 keeps the DS-token form; no DS edit.

### U03 `notebook-search-deploy-e2e` (agent `sde-infra`)

- `web/e2e/notes-search.spec.js`: **20 scenarios** — existing 1–8 plus count,
  zero-notes, loading, error/retry, offline, offline-zero, XSS/escaping,
  keyboard/focus/aria, 512-byte API cap (`400`, 512 accepted), 390/1200
  viewports, clear-focus, user-B owner isolation; plus `CR-01..CR-03`
  regressions (stale GET after delete, 401 lock + `aria-describedby`, offline
  clear then reconnect).
- `deploy/path1/e2e-preview.sh`: API smoke (incl. 512 cap) + Playwright entry;
  `scenarios.json` / `scenario-evidence.json`: per-scenario evidence.
- **test2 only** under the E6636 lease; no prod/main/test1/canary; platform and
  DS frozen until s24; no skips/fixmes, no fake evidence.
- Files (4): `web/e2e/notes-search.spec.js`, `deploy/path1/e2e-preview.sh`,
  `scenarios.json`, `scenario-evidence.json`.
- Acceptance: `npx playwright test web/e2e/notes-search.spec.js` → 20 passed on
  `test2`; Playwright 1.64.1; per-scenario screenshot + `pngdiff`; 20/20 evidence.

### Task table (T0001–T0012)

| Task | Unit | Files | Oracle |
|---|---|---|---|
| T0001 q contract: trim/empty/whitespace/case-insensitive substring | U01 | `main.go` | `TestNotesSearchFinds`, `TestNotesSearchCaseInsensitive`, `TestNotesSearchEmptyQuery`, `TestNotesSearchWhitespaceQuery` |
| T0002 owner predicate before text predicate; isolation | U01 | `main.go`, `main_test.go` | `TestNotesSearchIsolation` |
| T0003 512-byte cap before scan; `400`; 512 accepted | U01 | `main.go`, `main_test.go` | `TestNotesSearchQueryTooLong` (+ 512 accept) |
| T0004 auth-before-query, encoding, wire no-leak; backend suite | U01 | `main_test.go` | `TestNotesSearchAuthRequired`, `TestNotesSearchEncoding`, `TestWireContract`, `TestHTTPTransport` |
| T0005 search/count/clear/empty markup, testids, labels | U02 | `web/index.html`, `web/app.css` | `TestUISemantics`, `INV-SEARCH-UI-TESTIDS` |
| T0006 client filter via single `renderNotes`, clear, empty precedence | U02 | `web/app.js` | `TestUISemantics`, `INV-SEARCH-UI-FILTER`, `INV-SEARCH-UI-EMPTY` |
| T0007 count/retry/offline/offline-zero/delete label/aria-live | U02 | `web/index.html`, `web/app.js`, `web/app.css` | `TestUISemantics`, `INV-UI-LABEL`, `INV-UI-A11Y-NAME` |
| T0008 keep 44px expectation on the DS token (`--control-height`); DS-only | U02 | `web/app.css`, `web_ui_test.go` | `go test ./...` green; s22a 0 DS violations |
| T0009 expand Playwright spec to 20 scenarios + CR regressions | U03 | `web/e2e/notes-search.spec.js` | 20 passed, no skips/fixmes |
| T0010 API smoke + 512-cap + E2E entry on `test2` | U03 | `deploy/path1/e2e-preview.sh` | `bash deploy/path1/e2e-preview.sh` exit 0 |
| T0011 scenario manifest + per-scenario evidence/pngdiff | U03 | `scenarios.json`, `scenario-evidence.json` | 20/20 evidence, `pngdiff` OK |
| T0012 test2-only/freeze guard; no prod/main/test1/canary | U03 | `deploy/path1/e2e-preview.sh`, `scenarios.json` | s20b/s20c evidence; scope check |

## Execution order

1. **s19** — lease `test2` for E6636 (TTL; no other stand).
2. **s20** — fan-out exactly 3 child executions (U01/U02/U03), distinct
   `session_id` each; each unit brief ≤8 files.
3. **s20a** — integrate the three units on `dev/path10-runner-13`.
4. **s20b** — preview deploy via platform ORC, `test2` only; platform frozen.
5. **s20c** — API smoke + Playwright 20 scenarios + screenshots/`pngdiff`.
6. **s21** — actualize `UI-GRAPH.yaml` from `web/`; **s22a/s22e/s22b/s22c** —
   UI audit, platform/DS checks, red-team/adversarial review; **s23** refine;
   **s24** owner approval via signed Nexus request (`orc_wait`), then close.

## Verification

- Backend: `go build ./...`, `go vet ./...`, `go test -count=1 ./...`; UI
  static: `TestUISemantics` green, no DS/local-instance drift.
- Preview `test2`: `npx playwright test web/e2e/notes-search.spec.js` → 20
  passed; per-scenario screenshots + `pngdiff`.
- `s22a`: **0 DS violations**, 0 local instances, path6 gaps accepted; `s24`:
  `ds-drift` clean + owner approval; no code/web/design edits at s11.

## Known risks

- **R-1 (closed at base):** `TestUISemantics` 44px oracle now uses the DS token
  `--control-height`; re-check in T0008, do not reintroduce a literal.
- **R-2:** isolation regression if query precedes owner predicate → T0002.
- **R-3:** create/delete skips re-filter → single `renderNotes` + E2E 5/6.
- **R-4:** preview drift → Playwright 1.64.1 pin, test2-only lease, frozen.
- **R-5 (offline delete/clear parity):** v7 disables per-row delete offline and
  hides clear offline; current app keeps them. s20 aligns to v7 or records an
  explicit design change; s22a/s22e verify.
- **R-6 (spec/history drift):** `spec/core.md` and `visualized-brief.md` are
  historical DS 1.0.0 snapshots; s14 regenerates from the s06 brief and active
  1.0.1 artifacts.

## Out of scope

Auth/session/token/persistence, pagination/ranking/fuzzy/highlighting, new
runtime deps/bundler/DS release, prod/main/stage/test1/canary, s45/s46, changes
to `f-v3-auth-notes`, E4312 or E1320.
