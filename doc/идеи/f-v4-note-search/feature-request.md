# Raw request — f-v4-note-search

> Immutable capture of the human request for s07 requirement trace.
> Source: task prompt "РОЛЬ: team-lead notebook / dev.code.ukituki.tech", 2026-11-05.

## Process requirements

1. Feature is a new small feature `f-v4-note-search` in the path-10 contour.
2. Process: `path-1.feature` 3.2.2, entry point `default`, platform `web`, feature_profile `full`.
3. Base branch `dev/f-v3-auth-notes`, base SHA `406fa965480025f452781ca864f7b1c44491ed28`.
4. Work branch `dev/f-v4-note-search`; feature dir `doc/идеи/f-v4-note-search`.
5. Skip `s45.push_primary` and `s46.post_deploy_verify`; do not execute them.
6. Do not roll back or rework `f-v3-auth-notes`.
7. Do not resume/accept `E4312`; do not touch `E1320`.
8. Do not touch prod/main/stage; do not start canary rollout.
9. Mandatory gates: s21 UI graph, s22a UI audit, s22b/s22c independent reviewer (author != reviewer), s24 owner approval via `@nuxus_dev_bot`.
10. No force/skip/waiver, no fake evidence/self-sign, do not commit per-run artifacts.
11. Session fan-out must be verified after s20: 3 child executions, 3 distinct child session_ids, parent session different, parent receives only summary/diff/verdict.

## Backend (U01)

12. `GET /api/notes?q=<text>`.
13. Without `q` — all notes of the current user.
14. With `q` — case-insensitive search over note text.
15. Only notes of the current user are returned.
16. Without bearer token — HTTP 401.
17. Empty `q` — all notes.
18. Whitespace-only `q` — must be fixed in the spec as either all notes or 400.
19. Tests: search finds a note.
20. Tests: search does not find an absent note.
21. Tests: a user does not see another user's notes.
22. Tests: unauthenticated request returns 401.
23. Tests: URL-encoding and special characters in `q`.

## Web UI (U02)

24. Search field in the notes view.
25. Filtering the notes list by the query.
26. Clearing the search restores the full list.
27. Empty state "ничего не найдено".
28. Do not break create/delete/reload.
29. `data-testid` for the search field and for the empty state.
30. Actualize the UI graph.

## Deploy / E2E (U03)

31. Preview deploy on `test2`.
32. E2E scenario: login.
33. E2E scenario: create 2 notes.
34. E2E scenario: search finds one note.
35. E2E scenario: search finds nothing.
36. E2E scenario: clearing search returns both notes.
37. E2E scenario: user B does not see user A's notes.
38. Use Playwright 1.64.1, not 1.53.
39. Do not roll back package/lock files.
40. `pngdiff` must be OK.

## Constraints

41. Auth and persistence behaviour must not change.
42. Only search scope is in scope; no unrelated refactors.
43. No changes to the old `f-v3-auth-notes` branch or its artifacts.
44. `E4312` and `E1320` are not resumed, accepted, or modified.
45. Preview is allowed only on `test2`; prod/main/stage and canary are out of scope.
