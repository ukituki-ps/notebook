# Expertise report — f-v4-note-search (architect validation, s05)

## Verdict

Design is consistent with the existing path-10 architecture. No blocking
conflicts. Proceed to final brief and specification.

## Checked against

- Raw request `feature-request.md` (45 items).
- Draft `feature-brief.md` (s01) and wireframes (s03).
- Planned `UI-GRAPH.yaml` (s04).
- Existing implementation in `main.go`, `main_test.go`, `web/`, `path1.project.json`.

## Decisions

| id | Decision | Trace |
|---|---|---|
| B-1 | Search is a read-only projection of the existing owner-scoped list; no storage or auth change. | request 12–18, 41 |
| B-2 | `GET /api/notes?q=` trims `q`; empty or whitespace-only `q` returns all notes. | request 13, 17, 18 |
| B-3 | Matching is substring + `strings.ToLower` on both sides; no locale collation promised. | request 14 |
| B-4 | The owner predicate is evaluated before/with the text predicate; the query can only narrow, never widen. | request 15 |
| B-5 | `q` comes from `r.URL.Query().Get("q")` so URL-encoded/special characters are handled by `net/http`. | request 23 |
| B-6 | UI filters the already loaded owner-scoped list; no per-keystroke request. | request 24–26 |
| B-7 | Empty state is shown only when the trimmed query is non-empty and the filtered list is empty. | request 27 |
| B-8 | E2E runs on `test2` with Playwright 1.64.1; package/lock are not rolled back. | request 31, 38, 39 |
| B-9 | `s45.push_primary` / `s46.post_deploy_verify` stay skipped; no prod/main/stage/canary. | request 5, 8, 45 |

## Open decisions

| id | Question | Status |
|---|---|---|
| OD-1 | whitespace-only `q`: all notes or `400`? | **closed** by B-2: all notes |
| OD-2 | server-side search vs client-side filtering | **closed** by B-6: both contracts; UI filters loaded list |

No remaining open decision requires a human answer beyond the s08 intent
approval itself.

## Architectural risks and mitigations

1. **Isolation regression.** A naive query branch could filter a global notes
   map. Mitigation: the handler iterates the same owner-scoped view and the
   test suite adds an explicit "user B cannot see user A's search result" case.
2. **Lock semantics.** The filter must run under the existing `Store.mu` read
   path. No new lock, no lock-order change.
3. **UI/API divergence.** Backend search is tested directly; UI filters the
   server result set. The E2E covers the user-visible contract end to end.
4. **Regression of create/delete/reload.** Existing Go UI semantics tests and
   E2E regression scenarios remain in force; search state is re-applied after
   mutation rather than replacing the render path.
5. **Test-environment drift.** The integration/E2E split from E4312 (API smoke
   vs Playwright) is preserved; the ORC container does not run Chromium.

## Interface freeze

- `GET /api/notes` response schema unchanged (`[]Note`, `UserID` not exposed).
- No new endpoint, no new auth header, no CORS change.
- No change to `POST /api/notes` or `DELETE /api/notes/{id}`.

## Validation status

Validated against draft brief `a3d99d7`, planned graph `37648cb`, and scope
report `41ae536`. Design is approved for finalization at s06. No blocking
finding; OD-1 and OD-2 are closed above.
