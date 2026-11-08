---
unit_id: notebook-search-deploy-e2e
domain: notebook-e2e
sde: sde-infra
change_class: plain
scope:
  - "expand web/e2e/notes-search.spec.js to 20 scenarios (existing 8 + 12 listed below); no skips/fixmes"
  - "API smoke in deploy/path1/e2e-preview.sh incl. 512-byte q -> 400 'query too long' and 512 accepted; then Playwright entry"
  - "scenarios.json: 20 entries (SEARCH-E2E-1..20); scenario-evidence.json: 20/20 per-scenario screenshot + sha256/pngdiff"
  - "test2 only under the E0809 lease; no prod/main/test1/canary; platform and DS frozen until s24"
files:
  - web/e2e/notes-search.spec.js
  - deploy/path1/e2e-preview.sh
  - scenarios.json
  - scenario-evidence.json
---
# T0103 — notebook-search-deploy-e2e (U03)

`scenarios.json` / `scenario-evidence.json` live in the feature dir
(`doc/идеи/f-v4-note-search/`).

## Goal

Deliver the 20-scenario search E2E, the `test2` API-smoke entry, and truthful
per-scenario evidence, with no skips or fabricated results.

## Task list

1. Keep existing SEARCH-E2E-1..8 (find, not-found empty, case-insensitive,
   clear, create with active query, delete with active query, whitespace-only,
   no-token cleanup) and add:
   - 9 count `Найдено N` only for a non-empty query, hidden when empty;
   - 10 zero-notes: `notes-empty` wins, search disabled;
   - 11 loading: `notes-loading` visible, search disabled;
   - 12 error state + `Повторить`; retry re-runs `loadNotes`;
   - 13 offline banner with loaded notes, no false empty state;
   - 14 offline-zero: offline variant, not search-empty;
   - 15 XSS/escaping: note text with HTML/script renders literally;
   - 16 keyboard/focus/aria: tab order, visible focus, labels, `aria-live`;
   - 17 512-byte API cap via `request`: `q` > 512 → `400 query too long`,
     512 accepted;
   - 18 390/1200 viewports: no horizontal overflow, stacked/inline search row;
   - 19 clear returns focus to the input and restores the full list;
   - 20 owner-scope B: user B never sees user A's notes.
2. `web/e2e/notes-search.spec.js`: exactly 20 tests, unique per-scenario
   screenshots, no `test.skip`, `fixme`, `only`, or fake evidence.
3. `deploy/path1/e2e-preview.sh`: keep health + auth smoke; add API search smoke
   (owner-scope, 512-byte `400`, 512 accept) before the Playwright run; fail-close
   when node/npx/browsers are missing; `E2E_BASE_URL` required.
4. `scenarios.json`: 20 entries with `id`, `given/when/then`, `e2e_ref`.
   `scenario-evidence.json`: 20 pass entries with screenshot path + sha256 and
   `pngdiff` OK; no stale E8895 data.
5. Run **only** on `test2` under the E0809 lease; no prod/main/test1/canary;
   platform and DS frozen until s24; do not edit `design/**`.

## Oracles

`npx playwright test web/e2e/notes-search.spec.js` → 20 passed;
`bash deploy/path1/e2e-preview.sh` exit 0; scenario manifest = 20; evidence =
20/20 with distinct screenshots and `pngdiff` OK; scope check `test2` only.
## DS constraints
No UI/code styling change; Notebook DS 1.0.0 stays pinned and untouched; no
Kubiki/local CSS; 390/1200 assertions read the DS-rendered UI as-is.
## Out of scope
`main.go`, `web/index.html`, `web/app.js`, `web/app.css`, `web_ui_test.go`,
auth/persistence, prod/main/stage/test1/canary, s45/s46, DS/platform changes.

## Acceptance

20/20 Playwright scenarios pass on `test2`; API smoke incl. 512-byte `400` and
512 accept; 20/20 scenario evidence with screenshots/`pngdiff`; no skips/fixmes;
run confined to `test2`.

## Evidence required

Playwright 20/20 report; `e2e-preview.sh` transcript/digest; `scenarios.json`
(20) and `scenario-evidence.json` (20 pass, sha256); per-scenario PNGs;
`pngdiff` result; lease/stand proof (`test2` only); `git diff` limited to the
four files.
