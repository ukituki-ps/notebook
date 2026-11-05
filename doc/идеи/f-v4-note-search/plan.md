# Plan — f-v4-note-search

- Execution: **E9294** (path-1.feature 3.2.2, path-10)
- Branch: `dev/f-v4-note-search`, base `406fa965`
- Change-definition: `f-v4-note-search/change-definition` (approved)
- Target: owner-scoped note search in API + web UI, tested and previewed on `test2`.

## Milestone M01 — Search end-to-end (single milestone)

### Units and tasks

| Unit | Task | Files | Oracle |
|---|---|---|---|
| U01 `notebook-search-api` | T0001 Store/List search helper | `main.go` | `TestNotesSearchFinds`, `TestNotesSearchCaseInsensitive` |
| U01 | T0002 GET handler `q` parsing/trim | `main.go` | `TestNotesSearchEmptyQuery`, `TestNotesSearchWhitespaceQuery` |
| U01 | T0003 owner scope + auth order | `main.go`, `main_test.go` | `TestNotesSearchIsolation`, `TestNotesSearchAuthRequired` |
| U01 | T0004 search tests (find/not-found/encoding) | `main_test.go` | `TestNotesSearchNotFound`, `TestNotesSearchEncoding` |
| U02 `notebook-search-ui` | T0005 search markup/testids | `web/index.html`, `web/app.css` | `TestUISemantics` |
| U02 | T0006 filter/clear/empty logic | `web/app.js` | `TestUISemantics`, E2E |
| U02 | T0007 UI semantics tests | `web_ui_test.go` | `TestUISemantics` |
| U03 `notebook-search-deploy-e2e` | T0008 Playwright search scenarios | `web/e2e/notes-search.spec.js` | 6 E2E scenarios |
| U03 | T0009 API smoke + adapter | `deploy/path1/e2e-preview.sh`, `path1.project.json` | integration smoke |
| U03 | T0010 UI graph actualization | `doc/идеи/f-v4-note-search/UI-GRAPH.yaml` | `s21` gate |

### Execution order

1. U01, U02, U03 run in parallel via s20 fan-out (3 child executions, one
   session per child; parent session receives only summary/diff/verdict).
2. s20a integrates all three units into the work branch.
3. s20b deploys the evaluated commit to `test2`; s20c runs API smoke +
   Playwright (1.64.1) and records scenario evidence/screenshots.
4. s21 actualizes the UI graph from code.
5. s22 / s22a / s22b / s22c audits; s23 refinement if needed; s24 owner approval.

### Verification strategy

- Backend: `go build ./...`, `go vet ./...`, `go test -count=1 ./...`; all
  search invariants from `invariants.json`.
- UI semantics: `TestUISemantics` checks testids, labels, empty state, and that
  the list is rendered from API data.
- Stand: unauth `GET /api/notes` → 401; search find/not-found; A/B isolation;
  Playwright 6 search scenarios; pngdiff OK.
- Graph: `UI-GRAPH.yaml` actualized from `web/` at s21.

### Risks

- Isolation regression if query filtering precedes the owner predicate →
  dedicated isolation test and review.
- UI filtering hides new notes if create/delete does not re-apply the query →
  render through one filter function; E2E covers create/delete/reload.
- Playwright environment drift → keep the test-only 1.64.1 pin and the
  integration/E2E split from E4312.

### Out of scope

Auth/persistence, pagination/ranking/fuzzy/highlighting, new runtime deps,
prod/main/stage, canary, s45/s46, f-v3/E4312/E1320 changes.

## Nexus artifact (s13)

Approved plan artifact: `f-v4-note-search/plan.md` (Nexus draft, promoted to
confirmed). This file is the repository copy referenced by `doc/идеи/f-v4-note-search/plan.md`.
