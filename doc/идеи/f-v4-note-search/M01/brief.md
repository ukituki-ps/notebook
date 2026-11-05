# M01 — Search end-to-end (milestone brief, s15)

## Goal

Deliver owner-scoped note search in the API and the notes web UI, verified by
Go tests and Playwright on `test2`, without changing auth, storage, or note
lifecycle behaviour.

## Units

| Unit | Domain | SDE | Change class | Files |
|---|---|---|---|---|
| `notebook-search-api` | notebook-api | sde-backend | plain | `main.go`, `main_test.go` |
| `notebook-search-ui` | notebook-web | sde-frontend | plain | `web/index.html`, `web/app.js`, `web/app.css`, `web_ui_test.go` |
| `notebook-search-deploy-e2e` | notebook-deploy | sde-infra | plain | `deploy/path1/e2e-preview.sh`, `path1.project.json`, `web/e2e/notes-search.spec.js`, `doc/идеи/f-v4-note-search/UI-GRAPH.yaml` |

## Scope

- `GET /api/notes?q=` optional, trimmed, case-insensitive substring,
  owner-scoped; `[]` not `null`; auth unchanged.
- UI search input (`notes-search`), live filtering, clear, empty state
  (`notes-search-empty`), create/delete/reload preserved.
- Tests: 8 backend search tests + `TestUISemantics` + 6 Playwright scenarios.
- Preview on `test2`; UI graph actualized at s21.

## Out of scope

Auth/session/token/persistence, pagination/ranking/fuzzy/highlighting, new
runtime dependencies, prod/main/stage, canary, s45/s46, f-v3/E4312/E1320.

## Exit criteria

1. All three units merged; `go build/vet/test` green.
2. Search works and is owner-scoped; 401 without bearer; encoding safe.
3. UI search/filter/clear/empty state works; create/delete/reload not broken.
4. Playwright 1.64.1 E2E green on `test2`; pngdiff OK.
5. s21/s22a/s22b/s22c/s24 gates pass; s45/s46 skipped.
