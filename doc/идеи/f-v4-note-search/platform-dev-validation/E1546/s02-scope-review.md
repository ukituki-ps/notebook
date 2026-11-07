# Scope analysis — f-v4-note-search (s02.architect_scope_analysis, E1546)

- **Step:** `s02.architect_scope_analysis`
- **Execution:** `E1546`
- **Input:** draft feature brief (s01), immutable raw request.
- **Base:** `9723acd3e6277c119ac90f8b95fcc0f9bdd7a2a6`

## Verdict

**PASS** — the existing `scope-report.md` is a complete and current scope
analysis. Affected domains, constraints, architecture notes, ambiguities and
risks still match the brief and the repository layout. No new domain or conflict
is introduced by the re-validation.

## Domains / surfaces (unchanged)

| Domain | Surface | Change class |
|---|---|---|
| notebook-api | `main.go`, `main_test.go` | read-only query projection + tests |
| notebook-web | `web/index.html`, `web/app.js`, `web/app.css`, `web/e2e/notes-search.spec.js` | search input, filtering, clear, empty state |
| notebook-deploy | `deploy/path1/e2e-preview.sh`, `path1.project.json` | preview/E2E on test2 only |
| docs/graph | `doc/идеи/f-v4-note-search/UI-GRAPH.yaml` | planned at s04, actualized at s21 |

## Constraints carried forward

1. Auth/session/token/storage frozen; search is a read-only projection.
2. Auth guard order preserved: auth → method → query; unauthenticated = 401.
3. Owner predicate first; `q` may narrow, never widen.
4. No new Go deps, no build tags, no bundler/framework in `web/`.
5. Playwright stays 1.64.1; `package.json` / `package-lock.json` untouched.
6. Only `test2`; no prod/main/stage/canary.
7. `f-v3-auth-notes`, `E4312`, `E1320` untouched.

## Open decisions

- `OD-1` whitespace-only `q` → all notes (closed in `expertise-report.md`).
- `OD-2` server query + client filter (both) (closed).

No blocking conflict; proceed to s03 (proto) / s04 (planned graph) / s05.
