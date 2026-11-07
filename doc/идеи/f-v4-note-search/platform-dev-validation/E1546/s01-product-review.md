# Product review — f-v4-note-search (s01.product_discuss, E1546)

- **Step:** `s01.product_discuss`
- **Execution:** `E1546` (restart of cancelled `E9551`; same entry/base)
- **Feature:** `f-v4-note-search`
- **Platform:** `web` (`path1.ui.json.platform = "web"`, `feature_profile = full`)
- **Work branch / base:** `dev/f-v4-note-search-ae079e5c` @ `9723acd3e6277c119ac90f8b95fcc0f9bdd7a2a6`
- **Pass type:** fresh re-validation of the already finalized brief. The existing
  docs are the s01 input; nothing was rewritten.

## Verdict

**PASS** — the finalized brief (`feature-brief.md`, s06) faithfully covers the
immutable raw request for a web-only, owner-scoped note search. The core contract
(query parameter, case-insensitive substring matching, owner scoping,
client-side filter/clear/empty states, Go + Playwright tests, test2 preview) is
complete and consistent with `expertise-report.md`, `scope-report.md`,
`invariants.json`, `UI-GRAPH.yaml` and `path1.ui.json`.

## Inputs reviewed (at base `9723acd`)

| Input | Role | State |
|---|---|---|
| `doc/идеи/f-v4-note-search/feature-request.md` | Immutable raw request (45 items) | Unchanged |
| `doc/идеи/f-v4-note-search/feature-brief.md` | Draft → final brief (s06) | FINAL; API table, search semantics, UX, wireframes, AC |
| `doc/идеи/f-v4-note-search/scope-report.md` | Scope/impact | Notebook-api / notebooks-web / deploy / docs-graph; constraints |
| `doc/идеи/f-v4-note-search/expertise-report.md` | Architect validation (s05) | B-1…B-9; open decisions closed |
| `doc/идеи/f-v4-note-search/UI-GRAPH.yaml` | UI graph | `schema: ui-graph/v1`, platform web |
| `doc/идеи/f-v4-note-search/invariants.json` | Machine invariants | search owner/case/empty/not-found/encoding/UI invariants present |
| `path1.ui.json` | Platform declaration | `platform: "web"` |

## Draft brief scope (for s02)

- **In scope:** `GET /api/notes?q=<text>`; case-insensitive substring search;
  owner scoping; web search input + live filtering + clear + `notes-search-empty`;
  Go + Playwright tests; UI graph actualization; test2 preview.
- **Out of scope:** auth/session/token changes; persistence changes;
  create/delete/reload semantics; pagination/sorting/ranking/fuzzy/highlighting;
  prod/main/stage and canary.
- **Open decision carried forward:** whitespace-only `q` = all notes (closed in
  `expertise-report.md`, re-checked at s07).

## Mismatches

None blocking. No scope drift between the raw request and the draft brief.
