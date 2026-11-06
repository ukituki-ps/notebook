# T0009 — integration smoke (auth/notes only) and adapter (s16 task brief)

- Unit: `notebook-search-deploy-e2e`
- Domain: `notebook-deploy`
- SDE: `sde-infra`
- Change class: `plain`
- Files: `deploy/path1/e2e-preview.sh`, `path1.project.json`

## Scope

1. Keep the `E2E_API_ONLY=1` integration path as the health/auth/notes API
   smoke: `/healthz`, login/register, and notes CRUD, including unauth
   `GET /api/notes` → `401`. Do **not** add a `q=` search find/not-found
   assertion.
2. Keep `path1.project.json` integration command
   (`E2E_API_ONLY=1 bash deploy/path1/e2e-preview.sh`) and the
   `UI-E2E-PREVIEW` audit oracle (healthz + unauth `401`) semantically
   unchanged.
3. Rely on the full Playwright run at s20c to auto-discover
   `web/e2e/notes-search.spec.js` via `playwright.config.js`; no new path-1
   config key is required.
4. Preserve the integration/E2E split from E4312: the API-only smoke exits
   before Playwright; search coverage is Playwright-only.

## Acceptance oracles

- `E2E_API_ONLY=1 bash deploy/path1/e2e-preview.sh` on `test2` (auth/notes
  smoke passes).
- `path1.project.json` parses and keeps `integration`, `e2e.command`, and the
  `UI-E2E-PREVIEW` oracle.
- s20b preview and s20c full Playwright gates pass; `UI-E2E-PREVIEW` green.

## Forbidden

Adding a search `q=` API smoke to the integration script; changing the
integration command semantics or the audit oracle; prod/main/stage or canary;
new runtime dependencies; committing per-run evidence/screenshots.
