# T0010 — UI graph actualization at s21 (s16 task brief)

- Unit: `notebook-search-deploy-e2e`
- Domain: `notebook-deploy`
- SDE: `sde-infra`
- Change class: `plain`
- Files: `doc/идеи/f-v4-note-search/UI-GRAPH.yaml`

## Scope

1. At s21, actualize `UI-GRAPH.yaml` from the code (`web/index.html`,
   `web/app.js`, `web/app.css`) — not from design — keeping
   `schema: ui-graph/v1`, `feature_id: f-v4-note-search`, `platform: web`, and
   an actualized/from-code status.
2. Reconcile pages, components, selectors, and state ids with the DOM:
   `notes-search`, `notes-search-clear`, `notes-search-empty`, `notes-empty`,
   plus the unchanged login/register/loading/error/401 states.
3. Confirm the search state transitions (idle → filtering → results /
   search-empty; clear returns to idle; create/delete re-apply the filter) and
   remove any selector or state that is not present in the code.
4. Keep the graph observational: it documents the implemented UI and makes no
   contract, platform, or path-1 change.

## Acceptance oracles

- s21 graph gate passes; YAML parses and validates against `ui-graph/v1`.
- Every search selector/testid in the graph exists in `web/index.html` or
  `web/app.js`; no testid drift.
- `notes-empty` and `notes-search-empty` remain distinct in the graph.
- Existing auth/notes graph entries remain accurate.

## Forbidden

Hand-writing states not present in the code; changing app behavior to fit the
graph; changing platform/path-1 config; committing per-run evidence; leaving
design-only selectors or duplicate states in an actualized graph.
