# Unit plan — notebook-search-deploy-e2e (f-v4-note-search, T0003)

1. Inspect existing `web/e2e/auth-notes.spec.js`, `playwright.config.js`, and
   the f-v4 spec (`feature-brief.md`, `spec/core.md`, `T0002/brief.md`).
2. Add `web/e2e/notes-search.spec.js` with exactly 6 scenarios against a
   deployed stand:
   - SEARCH-E2E-1: search finds the matching note.
   - SEARCH-E2E-2: non-matching query shows `notes-search-empty` only.
   - SEARCH-E2E-3: match is case-insensitive (ASCII lower/upper).
   - SEARCH-E2E-4: clear restores the full loaded list.
   - SEARCH-E2E-5: create while a query is active re-applies the filter
     (non-matching hidden, matching appears, query retained).
   - SEARCH-E2E-6: delete while a query is active keeps the filter consistent,
     including `notes-search-empty` after the last match is removed.
   Reuse the existing registration/login/`addNote` patterns and per-test user
   isolation; no skips/fixmes.
3. Actualize `doc/идеи/f-v4-note-search/UI-GRAPH.yaml` (`status: actualized`)
   with the notes search input, clear control, search empty state, selectors,
   states, transitions and E2E evidence.
4. Validate without a live stand:
   - `node --check web/e2e/notes-search.spec.js`
   - `npx --no-install playwright test --list`
   - YAML parse/structure check (`js-yaml`, no new dependency).
5. Write `evidence.txt` and report. Live E2E remains an s20c step on `test2`.

Constraints: no package/lock or Playwright-version change (1.64.1), no edits to
`deploy/path1/e2e-preview.sh` or `deploy/path1/preview-deploy.sh`, no
backend/frontend application edits, no new dependencies.

Dependency/risk: the spec requires the T0002 search UI (`notes-search`,
`notes-search-empty`; clear control named `notes-search-clear` in the graph).
If the UI unit uses a different clear testid, the E2E helper falls back to the
clear button's accessible name.
