# UI graph actualization — f-v4-note-search (s21.graph_actualize)

- **Step:** `s21.graph_actualize`
- **Execution:** `E8363`
- **Feature:** `f-v4-note-search`
- **Platform:** `web`
- **Branch:** `dev/f-v4-note-search-validation-zero`
- **Evaluated SHA:** `eeacf65f2b5913cc9ab28cfbf9e5426a4b67ec77`
- **Pass type:** actualized from code (not from design).
- **Artifact:** `/workspace/projects/notebook-valzero/doc/идеи/f-v4-note-search/UI-GRAPH.yaml`

## Verdict

**PASS** — `UI-GRAPH.yaml` is now a valid `ui-graph/v1` **actualized**
(`status: actualized`, `source: code`) graph for execution `E8363` at
`evaluated_sha: eeacf65f2b5913cc9ab28cfbf9e5426a4b67ec77`.

The graph was rebuilt from the shipped `web/index.html`, `web/app.js` and
`web/app.css`. The s04 planned graph was used only as a structural baseline;
its `status`/`source`/metadata were replaced with code-verification metadata.
Every listed component, selector and testid exists in the code; there are
**no phantom nodes** (30/30 testids verified, with no unlisted DOM testids).

## Inputs reviewed

All paths relative to `/workspace/projects/notebook-valzero/`.

| Input | Absolute path | Role |
|---|---|---|
| DOM / markup | `/workspace/projects/notebook-valzero/web/index.html` | Pages, components, all 30 `data-testid`s, states, labels, ARIA |
| Behaviour | `/workspace/projects/notebook-valzero/web/app.js` | Render/filter/state transitions, edges, 401/logout, persistence |
| Styles | `/workspace/projects/notebook-valzero/web/app.css` | Layout/responsive/state styling selectors |
| Static UI oracle | `/workspace/projects/notebook-valzero/web_ui_test.go` | Required/forbidden testids, labels, ARIA, empty-state rules |
| Scenario E2E | `/workspace/projects/notebook-valzero/web/e2e/notes-search.spec.js` | `SEARCH-E2E-1..6` behaviour and assertions |
| Scenario catalogue | `/workspace/projects/notebook-valzero/doc/идеи/f-v4-note-search/scenarios.json` | Scenario ids, titles, `e2e_ref` |
| Scenario evidence | `/workspace/projects/notebook-valzero/doc/идеи/f-v4-note-search/scenario-evidence.json` | Per-scenario `status: pass`, screenshots, sha256 |
| Evidence manifest | `/workspace/projects/notebook-valzero/doc/идеи/f-v4-note-search/evidence-manifest.json` | Committed hashes for evidence/screenshots |
| Baseline graph | `/workspace/projects/notebook-valzero/doc/идеи/f-v4-note-search/UI-GRAPH.yaml` | Planned (s04) structure, re-scoped to actualized |

## Counts

| Item | Count | Detail |
|---|---:|---|
| Pages | 3 | `login`, `register`, `notes` |
| Components | 23 | login 4, register 4, notes 15 |
| Selectors / testids | 30 | login 7, register 8, notes 15; `selectors_verified_in_code: true` |
| States | 10 | 8 notes render/fetch/transition states + auth screens + search state machine |
| State-machine render states | 4 | `idle-list`, `filtering`, `results`, `search-empty` |
| Orthogonal fetch states | 4 | `loading`, `genuinely-empty`, `error`, `unauthorized` |
| Edges | 8 | 4 navigation + 4 notes self-update |
| Evidence scenarios | 6 | `SEARCH-E2E-1..6`, all `status: pass` |

## State coverage (10/10)

1. `idle-list` — empty/whitespace query; all loaded notes or `notes-empty`;
   `notes-search-empty` hidden; `notes-search-clear` hidden only when the raw
   `searchQuery === ""`.
2. `filtering` — trimmed non-empty query; client-side case-insensitive
   substring over `title + text`; no per-keystroke request.
3. `results` — filtering yields >= 1 match; matching `note-item` rows visible.
4. `search-empty` — non-empty query, zero matches over a non-empty collection;
   `notes-search-empty` visible with `Ничего не найдено.`, `notes-empty` hidden.
5. `genuinely-empty` — `GET /api/notes` returns `200 []` with an empty query;
   `notes-empty` visible, `notes-search-empty` hidden.
6. `loading` — `notes-loading` visible; list/empties hidden; form and search
   controls disabled until the initial load succeeds.
7. `error` — GET != 200 / network error shows `notes-error`; a failed initial GET
   leaves controls disabled; POST/DELETE failures reuse the same region.
8. `unauthorized` — 401 or missing token clears `notebook.token`/`notebook.user`
   and `notebook.search`, shows "Сессия истекла...", redirects to `/login`.
9. `auth-screens` — login/register cards, forms, error lines,
   `register-link` on login and `login-link` on register.
10. `search-state-machine` — idle -> filtering -> results/search-empty ->
    clear/empty -> idle, plus re-apply on create/delete/reload.

## Selectors verified against code

All 30 testids are present exactly once in `web/index.html`. Selector-level
checks performed:

- **login (7):** `login-card`, `login-form`, `login-username`,
  `login-password`, `login-submit`, `login-error`, `register-link`.
- **register (8):** `register-card`, `register-form`, `register-username`,
  `register-password`, `register-confirm`, `register-submit`, `register-error`,
  `login-link`.
- **notes (15):** `notes-header`, `user-name`, `logout`, `notes-error`,
  `note-form`, `note-input`, `add-note`, `notes-loading`, `notes-search`,
  `notes-search-clear`, `notes-empty`, `notes-search-empty`, `notes-list`,
  `note-item`, `delete-note`.

Attribute/behaviour checks recorded in the graph:

- `notes-search` is `input type="search"`, labelled `for="notes-search"`, with
  `aria-controls="notes-list"` and appears above `notes-list`.
- `notes-search-clear` is `type="button"`, has `aria-label`, and starts `hidden`.
- `notes-search-empty` starts `hidden`, is `role="status"` with
  `aria-live="polite"`, text `Ничего не найдено.`
- `notes-error`/`login-error`/`register-error` are `role="alert"`,
  `aria-live="polite"`, start `hidden`.
- `note-item`/`delete-note` exist only inside
  `<template id="note-item-template">`; `notes-list` is an empty `<ul>` and
  `app.js` clones the template (`cloneNode(true)`), so there are no phantom rows.
- No legacy ids (`username`, `password`, `confirm-password`, `notes-form`,
  `note-text`, `error`, `notes-card`) remain.
- All six evidence screenshots exist and their SHA-256 values match both
  `scenario-evidence.json` and `evidence-manifest.json` (verified locally).

## Drift vs code and plan

No testid, component, state, or edge in the planned graph was contradicted by
the code. Drift found is descriptive/metadata only.

### D-1 — Password roles (actualization correction)

The planned graph listed `login-password`, `register-password` and
`register-confirm` with `role: textbox`. In the DOM these are
`input type="password"` with no ARIA role. The actualized graph therefore omits
`role` for those three selectors instead of asserting a non-existent role. The
testids and selectors themselves are unchanged.

### D-2 — Literal `user:` prefix absent

`web/index.html` renders `user-name` as the username text only; there is no
literal `user:` label. The graph records `user-name` without a prefix.
Presentation-only.

### D-3 — Clear on a whitespace-only query

`renderNotes()` hides `notes-search-clear` only when the **raw**
`searchQuery === ""`; a whitespace-only input leaves the list unfiltered but
keeps `Clear` visible. The actualized graph encodes this raw-empty DOM rule
(consistent with s04 D-2 and s05 OD-5).

### D-4 — Error-state summary vs failed initial GET

The brief's broad "usable in every loaded state" wording is qualified by the
specific error block and the DOM: after a failed initial GET the search/form
controls stay disabled until a successful reload; after POST/DELETE failures a
already-loaded search remains usable. No behavioural contradiction.

### D-5 — Auth link placement

The graph pins the DOM-accurate placement: `login` has `register-link` ->
`/register`; `register` has `login-link` -> `/login`.

### D-6 — Testid scope

The graph records the full 30-testid inventory across all three pages (not a
notes-only delta), matching `web_ui_test.go` and the s04 planned scope.

### D-7 — Unused `.notes-search-empty` CSS class

`web/app.css` declares `.notes-search-empty`, but the DOM element with
`data-testid="notes-search-empty"` uses `class="muted"` only. The state still
renders through `.muted`; this is cosmetic CSS drift, not a state or selector
change. Optional cleanup only.

## Open questions

1. **Whitespace-only clear visibility (D-3).** Should `Clear` be hidden when the
   *trimmed* query is empty, or is the current raw-empty DOM rule the intended
   contract? The actualized graph records the code as-is.
2. **Search persistence across reload.** `web/app.js` stores the query in
   `sessionStorage` (`notebook.search`) and restores it on load. Confirm this is
   an intended contract behaviour, not only an implementation detail.
3. **Testid scope convention.** Keep the full 30-testid, all-page inventory, or
   switch future graphs to a notes-only feature-delta list with an explicit
   annotation?
4. **Error-state wording.** Keep the brief's broad "usable in every loaded
   state" sentence, or qualify it with the failed-initial-GET exception?
5. **Dead CSS selector (D-7).** Remove `.notes-search-empty` from `app.css` or
   apply the class to the element? Not required for this step.

## Limitations

- Per instruction, **no git commands were run**; verification is against the
  working tree at `eeacf65f2b5913cc9ab28cfbf9e5426a4b67ec77` as reported for the
  step.
- Only two files were written: `UI-GRAPH.yaml` and this report. No source,
  test, scenario, evidence, CSS, or path-1 file was modified.
- The graph is a documentation/oracle artifact; runtime E2E evidence is the
  committed `scenario-evidence.json` plus the `SEARCH-E2E-1..6` screenshots.
