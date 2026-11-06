# M01 — Search end-to-end (milestone brief, s15)

- **Execution:** `E8363`
- **Step:** `s15.brief_milestone`
- **Feature:** `f-v4-note-search`
- **Platform:** `web` (`feature_profile = full`)
- **Branch (this pass):** `dev/f-v4-note-search-validation-zero`
- **Base:** `5935e148` (`5935e148584b5fef28bd77ac4e45b800f10da03b`)
- **Pass type:** fresh E8363 re-validation; decomposition and scope unchanged.
- **Tasks:** `T0001`–`T0010` (briefs under `doc/идеи/f-v4-note-search/T000N/brief.md`).

## Goal

Deliver owner-scoped note search in the API and the notes web UI, verified by
Go tests and Playwright on `test2`, without changing auth, storage, or note
lifecycle behaviour.

## Units

| Unit | Domain | SDE | Change class | Tasks | Files |
|---|---|---|---|---|---|
| `notebook-search-api` | notebook-api | sde-backend | plain | T0001–T0004 | `main.go`, `main_test.go` |
| `notebook-search-ui` | notebook-web | sde-frontend | plain | T0005–T0007 | `web/index.html`, `web/app.js`, `web/app.css`, `web_ui_test.go` |
| `notebook-search-deploy-e2e` | notebook-deploy | sde-infra | plain | T0008–T0010 | `deploy/path1/e2e-preview.sh`, `path1.project.json`, `web/e2e/notes-search.spec.js`, `doc/идеи/f-v4-note-search/UI-GRAPH.yaml` |

## Scope

- `GET /api/notes?q=` optional, trimmed, case-insensitive substring; the owner
  predicate is applied by `ListNotes(session.UserID)` and the handler filters
  that snapshot, so `q` only narrows; `[]` not `null`; auth first and unchanged.
- UI search input (`notes-search`), live client-side filtering of the loaded
  owner-scoped list, clear control (`notes-search-clear`), search empty state
  (`notes-search-empty`) shown only for a non-empty trimmed query over a
  non-empty collection with zero matches; `notes-empty` stays the genuinely
  empty server-list state; create/delete re-render through the same filter.
- Tests: 8 backend search tests (`TestNotesSearch*`), `TestUISemantics`, and 6
  Playwright scenarios (`SEARCH-E2E-1` find, `-2` not-found, `-3` case, `-4`
  clear, `-5` create-active, `-6` delete-active). User-B isolation remains auth
  E2E-6 plus `TestNotesSearchIsolation`, not a search-spec scenario.
- Preview on `test2`: `E2E_API_ONLY=1` integration smoke is auth/notes only
  (health, unauth `401`, notes CRUD); search E2E runs via the full Playwright
  suite at s20c; UI graph actualized from code at s21.
- `sessionStorage` query restore (OD-6) is an implementation convenience, not
  contractual.

## Out of scope

Auth/session/token/persistence, pagination/ranking/fuzzy/highlighting, new
runtime dependencies, prod/main/stage, canary, s45/s46, f-v3/E4312/E1320,
contractual query persistence across a full reload (OD-6), and a search `q=`
API smoke in the integration script.

## Exit criteria

1. All three units merged; `go build`, `go vet`, `go test -count=1 ./...` green.
2. Search is owner-scoped; no bearer → `401`; encoding/special characters safe;
   no-match is `200 []`.
3. UI filter/clear/empty-state semantics correct; create/delete with an active
   query re-apply the filter; reload wiring stays on the single render path
   (`TestUISemantics`).
4. Playwright 1.64.1: 6/6 search scenarios green on `test2`; auth E2E-6 covers
   user-B isolation; `pngdiff` OK.
5. s21 graph gate, s22a/s22b/s22c reviews, and s24 owner approval pass; s45/s46
   skipped.
