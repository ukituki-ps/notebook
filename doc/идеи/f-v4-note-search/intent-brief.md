# Intent brief — f-v4-note-search

This document is the exact intent submitted for owner approval at
`s08.intent_brief_review`. It reconciles the 45 raw-request items in
`feature-request.md` with the design decisions in `expertise-report.md`.

## Scope

Add owner-scoped text search over existing notes, in the API and the web UI,
without changing authentication, storage, or note lifecycle behaviour.

## Reconciled interpretation

| Raw items | Interpretation |
|---|---|
| R01–R11 | New execution `E9294` in the path-10 contour, branch `dev/f-v4-note-search` from `406fa96`, s45/s46 skipped. |
| R12–R18 | `GET /api/notes`: bearer required; optional `q`; trim; empty/whitespace `q` = all notes; non-empty `q` = case-insensitive substring over the current user's notes. |
| R19–R23 | Go tests: find, not-found, isolation, 401, URL-encoding/special characters. |
| R24–R30 | Notes UI: labelled search field, live filtering of the loaded list, clear action, "ничего не найдено" empty state, testids, UI graph actualization. |
| R31–R40 | Preview on `test2`; Playwright 1.64.1 E2E: login, create 2 notes, find one, find none, clear restores both, user B isolation; package/lock untouched; pngdiff OK. |
| R41–R45 | Auth/persistence unchanged; no f-v3/E4312/E1320 changes; test2 only; no prod/main/stage/canary. |

## Added / clarified points (15)

1. **Whitespace-only `q`** is treated as empty and returns all notes (closed OD-1).
2. **Empty result** is `[]`, never `null`.
3. **Owner predicate first**: `q` can only narrow the current user's notes.
4. **Case-insensitivity** is `strings.ToLower` on both sides; no locale collation promised.
5. **Auth is unchanged**: missing/bad bearer still returns `401` before query handling.
6. **Exact UI testids**: `notes-search` for the input, `notes-search-empty` for the empty state.
7. **Empty state condition**: shown only when the trimmed query is non-empty and the filtered list is empty.
8. **Client-side filtering** of the already owner-scoped list; no per-keystroke API request.
9. **Regression protection**: create/delete/reload re-render through the same filter and keep working.
10. **Playwright 1.64.1** stays pinned; `package.json`/`package-lock.json` are not rolled back.
11. **Preview only on `test2`**; no prod/main/stage deploy.
12. **No canary rollout** is started.
13. **s45.push_primary / s46.post_deploy_verify** remain skipped.
14. **Three units** (backend, web UI, deploy/E2E) and the session fan-out check (3 child executions, 3 distinct child sessions, parent session distinct) are part of the execution contract.
15. **UI graph** is actualized at s21 from the real code; the s04 graph is only planned.

## Explicitly not approved

- Any auth/session/token rewrite.
- Any persistence/DB change.
- Pagination, ranking, fuzzy search, highlighting.
- Changes to production, main, stage, or canary.
- Changes to the completed `f-v3-auth-notes` feature or executions `E4312`/`E1320`.

## Acceptance

Owner approval of this file authorizes the scope above. Any later widening of
scope requires a new intent review; it is not implied by this approval.

## Status

Prepared for `s08.intent_brief_review`. Items: 45/45 traced. Open questions: 0
(OD-1 and OD-2 are closed and documented above). Approval is requested from the
owner via the Nexus approval policy for `subject=brief`.
