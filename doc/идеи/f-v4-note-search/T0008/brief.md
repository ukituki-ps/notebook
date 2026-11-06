# T0008 — Playwright search scenarios (s16 task brief)

- Unit: `notebook-search-deploy-e2e`
- Domain: `notebook-deploy`
- SDE: `sde-infra`
- Change class: `plain`
- Files: `web/e2e/notes-search.spec.js`

## Scope

1. Add exactly 6 Playwright scenarios, each with login plus a two-note fixture
   as preconditions:
   - `SEARCH-E2E-1` — search finds one matching note and hides the other;
   - `SEARCH-E2E-2` — non-matching query shows `notes-search-empty` and hides
     `notes-empty`;
   - `SEARCH-E2E-3` — matching is case-insensitive;
   - `SEARCH-E2E-4` — clear restores both notes and hides the search empty state;
   - `SEARCH-E2E-5` — create while the query is active re-applies the filter
     (non-matching hidden, matching appears, query preserved);
   - `SEARCH-E2E-6` — delete while the query is active stays consistent, and
     after deleting the last match the search empty state (not `notes-empty`)
     is shown.
2. Keep Playwright pinned at 1.64.1 and rely on `playwright.config.js`
   (`testDir: "web/e2e"`) for discovery; do not touch `package.json`/lock.
3. Record one scenario-specific screenshot per E2E id for the s20c `pngdiff`.
4. Do not add a user-B isolation scenario to this spec: isolation remains auth
   E2E-6 plus `TestNotesSearchIsolation`.

## Acceptance oracles

- `npx --no-install playwright test web/e2e/notes-search.spec.js`
- 6/6 scenarios pass on the `test2` preview at s20c; screenshots exist for
  `SEARCH-E2E-1..6`; `pngdiff` OK.
- Existing `web/e2e/auth-notes.spec.js` (E2E-1..7) stays green.

## Forbidden

Adding user-B isolation here as a replacement for auth E2E-6; `skip`/`fixme` or
conditional bypasses; changing the Playwright version or rolling back
`package.json`/lock; prod/main/stage runs; committing per-run evidence or
screenshots.
