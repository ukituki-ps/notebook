# T0003 — notebook-search-deploy-e2e (s16 unit brief)

- Unit: `notebook-search-deploy-e2e`
- Domain: `notebook-deploy`
- SDE: `sde-infra`
- Change class: `plain`
- Files: `deploy/path1/e2e-preview.sh`, `path1.project.json`,
  `web/e2e/notes-search.spec.js`, `doc/идеи/f-v4-note-search/UI-GRAPH.yaml`

## Scope

1. Add Playwright `web/e2e/notes-search.spec.js` with exactly 6 scenarios:
   login; create 2 notes; search finds one; search finds none; clear returns
   both; user B does not see user A's notes.
2. Keep Playwright pinned at 1.64.1; do not roll back `package.json`/lock.
3. Extend the stand API smoke (integration) with unauthenticated 401 and search
   find/not-found, keeping the integration/E2E split from E4312.
4. Actualize `UI-GRAPH.yaml` from code at s21 (notes-search,
   notes-search-empty, testids).

## Acceptance oracles

- `bash deploy/path1/e2e-preview.sh` on `test2` (API smoke + Playwright).
- E2E: 6/6 passed, pngdiff OK, preview verdict pass/verified.
- `s21` graph gate; `s20c` preview gate.

## Forbidden

prod/main/stage, canary, s45/s46, runtime dependency changes, committing
per-run evidence/screenshots.
