# UI graph design review — f-v4-note-search (s04.graph_builder_design)

- **Step:** `s04.graph_builder_design`
- **Execution:** `E8363`
- **Feature:** `f-v4-note-search`
- **Platform:** `web` (`path1.ui.json.platform = "web"`, same-origin static UI)
- **Branch (this pass):** `validation/platform-dev-20261106-zero`
- **Pass type:** planned UI graph from design. The graph is **not** actualized
  from code; `web/index.html` and `web/app.js` were read only to cross-check
  testid names and state-transition consistency.

## Verdict

**PASS** — `UI-GRAPH.yaml` is now a valid `ui-graph/v1` **planned** graph for
execution `E8363` with `source: design`. It covers the three pages
(login/register/notes), all required components and selectors/testids, all
**10 of 10** required state surfaces, the navigation/self-update edges, and
evidence references for `SEARCH-E2E-1..6`. The prior `E8895` actualized header
was replaced; no actualized/from-code metadata remains in the header.

Residual findings are **non-blocking descriptive drift** between the brief
wireframes and the shipped DOM; none removes a required state, changes a testid,
or contradicts a state transition.

## Counts

| Item | Count | Detail |
|---|---:|---|
| Pages | 3 | `login`, `register`, `notes` |
| Component entries | 23 | login 4, register 4, notes 15 |
| Selectors / testids | 30 | login 7, register 8, notes 15; `testids_count: 30` |
| States | 10 | 8 notes render/fetch states + auth screens + search state machine |
| State-machine render states | 4 | `idle-list`, `filtering`, `results`, `search-empty` |
| Orthogonal fetch states | 4 | `loading`, `genuinely-empty`, `error`, `unauthorized` |
| Edges | 8 | 4 navigation + 4 notes self-update |
| Evidence scenarios | 6 | `SEARCH-E2E-1..6` |

Required-state mapping:

1. `idle-list` — idle/list, query empty or whitespace; all notes or
   `notes-empty`; search-empty and clear hidden.
2. `filtering` — trimmed non-empty query; client-side case-insensitive
   substring filter; no per-keystroke request.
3. `results` — filtering with >= 1 match; matching `note-item` rows visible.
4. `search-empty` — non-empty query, zero matches over a non-empty collection;
   `notes-search-empty` with `Ничего не найдено.`, `notes-empty` hidden.
5. `genuinely-empty` — `GET /api/notes` returns `200 []` with an empty query;
   `notes-empty` visible, `notes-search-empty` hidden.
6. `loading` — `notes-loading` visible; list/empties hidden; form and search
   disabled until loaded.
7. `error` — `notes-error` visible; failed initial GET leaves controls disabled;
   POST/DELETE failures reuse the region and keep a loaded search usable.
8. `unauthorized` — 401 or missing token; clear session/search keys, show
   "Сессия истекла...", navigate to `/login`.
9. `auth-screens` — login/register cards, forms, error lines,
   `register-link` on login and `login-link` on register.
10. `search-state-machine` — explicit idle -> filtering -> results/search-empty
    -> clear/empty -> idle transitions, plus re-apply on create/delete/reload.

## Inputs reviewed

All paths relative to `/workspace/projects/notebook-valzero/`.

| Input | Role | Observed at this head |
|---|---|---|
| `doc/идеи/f-v4-note-search/feature-brief.md` | Design source (s03 wireframes revalidated for E8363) | 224 lines; wireframes 73–180; 10 state blocks + state machine |
| `doc/идеи/f-v4-note-search/scope-report.md` | Scope (s02) | `notebook-web` covers `web/index.html`, `web/app.js`, `web/app.css`, `web/e2e/notes-search.spec.js` |
| `path1.ui.json` (repo root) | Platform declaration | `platform: "web"`; static same-origin `/api/*`; token in localStorage |
| `web/index.html` | DOM cross-check | 111 lines; 30 `data-testid`s; login/register/notes sections; search block 77–87; empties 89–95; list 96 |
| `web/app.js` | Behaviour cross-check | 614 lines; `filterNotes`/`renderNotes`; `loadNotes`; create/delete re-render; search input/clear wiring |
| `doc/идеи/f-v4-note-search/UI-GRAPH.yaml` | File replaced by this pass | Prior `E8895` actualized header; useful components/selectors/states/evidence preserved and re-scoped to `planned` |

## Drift vs brief (non-blocking)

### D-1 — Literal `user:` prefix in the idle wireframe

Brief 95 draws `Notebook   user: [user-name] [logout]`. `web/index.html` renders
`user-name` as the username text only; there is no literal `user:` label. The
planned graph records `user-name` without the prefix. Presentation-only.

### D-2 — Clear visibility on a whitespace-only query

Brief 79 declares idle/list for a "query empty or whitespace" and brief 102/176
says the clear button is hidden "while the query is empty". At this head,
`renderNotes()` hides `notes-search-clear` only when the **raw**
`searchQuery === ""`; a whitespace-only input leaves the list unfiltered
(correct idle/list) but keeps `Clear` visible. The planned graph encodes this
raw-empty rule in `idle-list` and `notes-search-clear`. This is an ambiguity in
the brief wording rather than a state change; see open question 1.

### D-3 — "Usable in every loaded state" vs failed initial GET

Brief 179–180 says the search controls are "usable in every loaded state", while
brief 151–154 correctly states that after a failed initial GET the list/search
controls stay disabled until a successful reload. The graph follows the specific
error block and the DOM: disabled after a failed initial GET, usable after
POST/DELETE failures once the list has loaded. No behavioural contradiction;
only the summary note is broad.

### D-4 — Auth link placement is now pinned

Brief 88 draws `link: login-link <-> register-link` without assigning a link to
a screen. The planned graph pins the DOM-accurate placement: `login` has
`register-link` -> `/register`; `register` has `login-link` -> `/login`. This
resolves the placement drift noted in the prior s03 review.

### D-5 — Note form order matches the updated wireframe

Brief 97–110 draws the create form above the search block; the DOM order is
`notes-error` -> `note-form` -> `notes-loading` -> search -> empties -> list.
The updated wireframe's form-above-search order matches the DOM. The graph also
records `notes-error` and `notes-loading`, which the idle sketch does not draw;
descriptive only.

### D-6 — Testid scope changed intentionally

The prior graph listed only 15 notes-screen testids. This planned graph records
all 30 testids across login/register/notes and sets `testids_scope` explicitly,
resolving the prior `testids_count: 15` ambiguity. The feature-delta set
(`notes-search`, `notes-search-clear`, `notes-search-empty`) remains unmistakable
inside the full list.

## Code-consistency checks (read-only)

- One filter path for load/create/delete/reload: `renderNotes()` ->
  `filterNotes()`; matches the brief state machine and the graph's
  `search-state-machine`.
- `notes-search-empty` is gated by `hasQuery && !noNotes && visible.length === 0`
  and never replaces `notes-empty`; the graph keeps the two states separate.
- `setNotesEnabled(false)` disables `note-input`, `notes-search` and
  `notes-search-clear` during load; the success path re-enables them.
- `handleUnauthorized()` clears `notebook.token`, `notebook.user` and the saved
  search, shows "Сессия истекла..." and redirects to `/login`.
- Search is client-side over the loaded owner-scoped list; no per-keystroke
  request. `notes-search` has a visible label and `aria-controls="notes-list"`.
- `notes-search-empty` uses `role="status"` / `aria-live="polite"` and the exact
  text `Ничего не найдено.`.

## Open questions

1. **Whitespace-only clear visibility (D-2).** Is a visible `Clear` on a
   whitespace-only query acceptable, or should the clear button also be hidden
   when the trimmed query is empty? The planned graph currently encodes the DOM
   behaviour (`hidden` only for raw empty) so s21 actualization will not drift.
2. **Reload persistence.** The brief state machine says reload while filtering
   re-applies the same filter; `web/app.js` additionally persists the query in
   `sessionStorage` (`notebook.search`) and restores it on load. The graph
   records this restore path. Confirm it is an intended part of the contract,
   not only an implementation detail.
3. **Testid scope convention.** Should future graphs continue with the full
   30-testid, all-page inventory, or revert to a notes-only feature-delta list
   with an explicit annotation?
4. **Error-state summary wording (D-3).** Leave the brief's broad
   "usable in every loaded state" sentence as-is, or qualify it with the
   failed-initial-GET exception at the next brief touch?

None of these blocks the s04 gate; the graph is complete and consistent enough
for s21 actualization.

## Limitations of this pass

- Per instruction, **no git commands were run**; verification is against the
  working tree at this head.
- Only two files were written: `UI-GRAPH.yaml` and this review. No brief, source,
  CSS, scenario, or path-1 file was modified.
- The previous `E8895` actualized metadata is historical and intentionally not
  carried into this planned `E8363` header.
