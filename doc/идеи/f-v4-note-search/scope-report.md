# Scope report — f-v4-note-search

## Affected domains

| Domain | Surface | Change |
|---|---|---|
| notebook-api | `main.go`, `main_test.go` | `GET /api/notes` query parsing + case-insensitive owner-scoped filter; tests |
| notebook-web | `web/index.html`, `web/app.js`, `web/app.css`, `web/e2e/notes-search.spec.js` | search input, client-side filtering, clear, empty state, testids |
| notebook-deploy | `deploy/path1/e2e-preview.sh` (only if search smoke is added), `path1.project.json` (no semantic change) | preview/E2E on test2 |
| docs/graph | `doc/идеи/f-v4-note-search/UI-GRAPH.yaml` | planned at s04, actualized at s21 |

## Constraints

1. Auth, session, token, and note storage semantics are frozen. The search is a
   read-only projection of the existing owner-scoped list.
2. `GET /api/notes` keeps its existing auth guard order: auth → method → query.
   Missing/invalid bearer still yields `401` before any query handling.
3. Owner scoping must remain the first predicate. The query must never widen the
   result set beyond `note.UserID == userID`.
4. No new dependencies (`go.mod` unchanged), no build tags, no framework or
   bundler in `web/`.
5. Playwright stays at 1.64.1; `package.json`/`package-lock.json` must not be
   rolled back.
6. Preview only on `test2`. prod/main/stage and canary are out of scope.
7. `f-v3-auth-notes`, `E4312`, `E1320` are not modified.

## Architecture notes

- The store is in-memory and guarded by `Store.mu`. Filtering is done while
  holding the same lock used by the existing list read; no lock-order change.
- The handler already writes JSON through `writeJSON`/`writeErr`. The search
  path must keep the same envelope and `[]` (not `null`) for no matches.
- `net/http` decodes `r.URL.Query().Get("q")`; no manual URL parsing.
- The UI already holds the owner-scoped list in memory. Filtering client-side
  avoids a second request per keystroke and keeps create/delete/reload wiring
  intact; the backend `q` behaviour is still implemented and tested.
- The search text and stored text are compared after `strings.ToLower`. No
  stored text is mutated.

## Ambiguities and decisions

| id | Ambiguity | Options | Recommendation |
|---|---|---|---|
| OD-1 | whitespace-only `q` | all notes / `400` | all notes (trim → empty → all); documented in spec and tested |
| OD-2 | search location | server query vs client filter | both: server `q` contract + client filter on the loaded list |

OD-1 is closed in `expertise-report.md` (B-decision) and must be reflected in
`s14` spec/contract matrix and tests.

## Conflicts / risks

- A query branch that filters before the owner predicate would leak foreign
  notes. Mitigation: keep the owner check and add `TestNotesSearchIsolation`.
- UI filtering could hide newly created notes if the create path does not
  re-apply the active query. Mitigation: re-render through the same filter
  function after create/delete and cover it in E2E.
- Changing the E2E runner must not change runtime dependencies. Mitigation:
  test-only Playwright dependency already present at 1.64.1.

## Recommendation

Proceed with a single backend unit (`notebook-search-api`), a single web unit
(`notebook-search-ui`), and a deploy/E2E unit (`notebook-search-deploy-e2e`).
No auth/persistence unit, no schema migration.
