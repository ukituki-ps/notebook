# Prototype / visual schema review — f-v4-note-search (s03.proto_visualize)

- **Step:** `s03.proto_visualize`
- **Execution:** `E8363`
- **Feature:** `f-v4-note-search`
- **Platform:** `web` (`path1.ui.json.platform = "web"`, `feature_profile = full`)
- **Branch (this pass):** `validation/platform-dev-20261106-zero`
- **Pass type:** re-validation of the **updated** `feature-brief.md` section
  "Wireframes (s03, ASCII, revalidated for E8363)" (lines 73–180) against the
  DOM/CSS at this head. This review is the only artifact produced by this step.
- **Schema revision reviewed:** `feature-brief.md` 222 lines, 10 state
  subsections + state machine (the previous pass reviewed the 180-line brief
  whose schema covered 5/10 states).

## Verdict

**PASS** — all **10 of 10** required states are now represented in the ASCII
schema, and the testids/transitions shown match `web/index.html` and
`web/app.js` at this head:

1. login/register navigation — `feature-brief.md` 79–91
2. notes header (incl. `user-name`) — 93–110
3. search input — 93–110
4. clear button (separate, hidden on empty query) — 102, 116, 176
5. notes list / note ids — 104–105
6. `notes-empty` (genuinely empty server list) — 133–139
7. `notes-search-empty` — 122–131
8. loading — 141–146
9. error — 148–154
10. 401 / session expired — 156–162

Plus the search state machine (164–171). The previously blocking gap is closed.

Residual findings are **non-blocking descriptive drift** in an otherwise
DOM-aligned schema; none removes a required state, changes a testid, or
contradicts `UI-GRAPH.yaml` on a state transition. The one substantive wording
issue is D-3 (error-state search availability), which should be corrected when
the brief is next editable.

## Inputs reviewed

All paths relative to `/workspace/projects/notebook-valzero/`.

| Input | Role | Observed at this head |
|---|---|---|
| `doc/идеи/f-v4-note-search/feature-brief.md` | Subject: updated s03 ASCII section | 222 lines; schema 73–180; 10 state blocks + state machine |
| `doc/идеи/f-v4-note-search/scope-report.md` | Scope (s02) | `notebook-web` covers `web/index.html`, `web/app.js`, `web/app.css` |
| `doc/идеи/f-v4-note-search/UI-GRAPH.yaml` | Actualized graph (s21) | pages login/register/notes; 11 notes states; 15 listed testids |
| `web/index.html` | DOM under review | 30 `data-testid`s; notes screen 58–98; search 77–87; empties 89–95; list 96; header 60–64 |
| `web/app.css` | Styling | Search rules 185–213; `.notes-search-empty` rule 211–213 still unused |
| `web/app.js` | Behaviour | `filterNotes` 362–368; `renderNotes` 372–390; `handleUnauthorized` 392–401; `loadNotes` 403–434; clear wiring 567–575 |
| `platform-dev-validation-zero/s01-product-review.md` | Prior product review | Mismatches 1 (copy) / 2 (label) now largely resolved by the new schema |

## Required-state coverage

`PASS` = state is drawn and its testid/behaviour matches this head.

| # | Required state | Schema location | DOM evidence | Result |
|---|---|---|---|---|
| 1 | login/register navigation | brief 79–91: login/register cards, forms, error lines, `login-link` ↔ `register-link`, `login-success → notes`, `register-success → login`; notes→login via 401 (156–162) | `login`/`register`/`notes` sections (index 12–98); `register-link` on login (28), `login-link` on register (53); `location.replace("/notes"/"/login")` (app.js 177, 265, 399) | PASS (see D-5) |
| 2 | notes header | brief 97: `Notebook`, `user: [user-name]`, `[logout]` | `notes-header` with brand, `user-name`, `logout` (index 60–64; app.js 446) | PASS (see D-1) |
| 3 | search input | brief 99–101: label `Поиск заметок`, `data-testid="notes-search"` | `notes-search`, label `Поиск заметок`, `type=search`, `aria-controls="notes-list"` (index 77–87; web_ui_test.go 158–170) | PASS |
| 4 | clear button | brief 102 `(clear hidden while query is empty)`, 116 `[notes-search-clear]`, 176 separate button | `notes-search-clear`, `type=button`, `aria-label="Очистить поиск"`, `hidden` on empty query (index 83–85; app.js 389) | PASS (see D-4) |
| 5 | notes list | brief 104–105: `[note-item id=N] #N text [delete-note]` | `notes-list` `<ul>`; `note-item` template; text `#<id> <text>`; `delete-note` (index 96, 102–107; app.js 336–351) | PASS |
| 6 | `notes-empty` | brief 133–139: `notes-empty` visible, list hidden, search-empty hidden | `notes-empty` "Пока нет заметок..." (index 89–91); `notesEmpty.hidden = !noNotes` (app.js 383) | PASS |
| 7 | `notes-search-empty` | brief 122–131: testid, `role=status`, `aria-live=polite`, exact `Ничего не найдено.`, notes-empty hidden | index 92–95; shown only for `hasQuery && !noNotes && visible.length === 0` (app.js 386–388) | PASS |
| 8 | loading | brief 141–146: `notes-loading` visible; list/empty/search-empty hidden; form+search disabled | `notes-loading` (index 75); app.js 409–413 (`setNotesEnabled(false)` disables `note-input`, `notes-search`, `notes-search-clear`) | PASS |
| 9 | error | brief 148–154: `notes-error` visible, f-v3 messages, POST/DELETE share region, search usable | `notes-error` role=alert (index 66); messages app.js 422–432, 485–499, 542–545 | PASS (see D-3) |
| 10 | 401 / session expired | brief 156–162: clear `notebook.token/user`, `notes-error` "Сессия истекла...", navigate `/login` | `handleUnauthorized` app.js 392–401 clears token/user/search, disables controls, redirects after 200 ms | PASS |

Coverage: **10/10 states present**, 7 matching exactly and 3 with the
non-blocking wording/layout notes below.

## Drift findings (non-blocking)

### D-1 — Phantom `Notes` page title still drawn

The idle/list wireframe keeps a bare `Notes` line (brief 98). The notes screen
has **no page heading** in the DOM: index 58–98 contains the `notes-header`
(brand `Notebook`, `user-name`, `logout`) and then the form/search/list; there is
no `h1`/`Notes` text and no testid for it. Cosmetically wrong only; `UI-GRAPH`
records no `notes-title` component. Action: drop the line or add a real heading.

### D-2 — Create form is drawn below the list; the DOM puts it above

Idle wireframe 104–108 places `note-input`/`add-note` after the note items. The
DOM order is: `notes-header` → `notes-error` → `note-form` → `notes-loading` →
search → `notes-empty` → `notes-search-empty` → `notes-list` (index 60–96), i.e.
the form sits **above** the search and list. `web_ui_test.go` constrains only
"search above list" (171–175), so both orders are functionally legal, but the
wireframe does not depict the shipped layout. Action: redraw the form above the
search block (cheapest; matches f-v3 and `UI-GRAPH`).

### D-3 — Error state overstates search availability (highest-priority wording)

Brief 151–153 says for the error state: `GET != 200 or network error: ...
POST/DELETE failures use the same error region; search input stays usable`.

At this head, a **GET** failure leaves the search disabled: `loadNotes()` calls
`setNotesEnabled(false)` (app.js 413) and the non-200 branch (422–424) and catch
(430–432) both `return`/end without `setNotesEnabled(true)` — only the success
path re-enables controls (428). **POST/DELETE** failures do leave the search
usable (app.js 547–554; delete re-enables only its own button, 480–499).

So "search input stays usable" is true for POST/DELETE and the post-load states,
false for a failed initial GET. The code is self-consistent and matches
`UI-GRAPH` (`loading` says controls not usable until loaded; `error` says the
existing f-v3 semantics apply). Action: qualify the clause, e.g. "search input
stays usable for POST/DELETE failures; after a failed GET the controls remain
disabled until a successful reload."

### D-4 — Clear button rendering

The schema now correctly states the control is a separate button hidden on an
empty query (102, 116, 176), but never shows its shipped label. DOM: text
`Clear`, `aria-label="Очистить поиск"` (index 83–85). Wireframe only names the
testid. Presentation-only; no oracle asserts the literal.

### D-5 — Auth link placement is not pinned

Brief 88 draws `link: login-link <-> register-link` without saying which link is
on which screen. DOM: the **login** page carries `register-link`
(`href="/register"`, index 28); the **register** page carries `login-link`
(`href="/login"`, index 53). `UI-GRAPH.yaml` 29–37 still lists them the other
way round (`login` → `login-link`, `register` → `register-link`), which is graph
bookkeeping drift already noted in the prior pass. The navigation requirement
itself is covered (both directions plus success/401 edges).

### D-6 — Dead CSS rule (unchanged)

`web/app.css` 211–213 defines `.notes-search-empty`, but the element in
`web/index.html` 92 uses `class="muted"`; no element in `web/` uses that class.
No visual impact (`.muted` already supplies `margin-top: 16px`, app.css 146–149).
Either add the class or delete the rule.

### D-7 — `UI-GRAPH.testids` count vs source (unchanged)

`testids_source: web/index.html`, `testids_count: 15`, and the 15-item list
(UI-GRAPH 151–168) cover notes-screen testids only, while `web/index.html`
declares **30** (including all login/register testids). If intentional
(feature-delta scope), annotate the field so it is not read as the full count.

### Previously raised drifts now resolved

- Note item text now includes the `#<id> ` prefix (brief 104–105) — matches
  app.js 341.
- `notes-search-empty` copy is now `Ничего не найдено.` (brief 129) — matches
  index 94 exactly; the s01 casing/period mismatch is closed in the schema.
- Clear-control visibility (hidden on empty query) and header `user-name` are
  now stated — matches app.js 389 and index 62.

## Code consistency (no defect)

- One filter path for load/create/delete/reload: `renderNotes()` → `filterNotes()`
  (app.js 362–390; mutations 470–473 and 528–529), matching the state machine's
  `create/delete/reload ... re-apply the same filter` (brief 170).
- `notes-search-empty` is gated by `hasQuery && !noNotes && visible.length === 0`
  (app.js 387) and never replaces `notes-empty` for an empty server list; this is
  exactly the separation drawn in brief 130/138 and asserted by
  `web_ui_test.go` 246.
- Loading disables form and search controls (app.js 409–413); 401 clears
  session state and redirects (392–401).
- Search is client-side over the loaded owner-scoped list; no per-keystroke
  request (app.js 559–565), matching brief 117–118.

## Open questions

1. **D-3 correction path.** Should the error-state clause be fixed in
   `feature-brief.md` now, or recorded as a follow-up? This pass is a review and
   does not edit the brief.
2. **Wireframe layout authority.** Confirm the shipped form-above-search order is
   intended (D-2) so the wireframe can be redrawn rather than the DOM reordered.
3. **`UI-GRAPH` testid scope** (D-7) and the swapped auth link placement (D-5):
   decide whether the graph should be corrected at the next graph touch.
4. **`Notes` title** (D-1): drop from the sketch or introduce a real heading?

None of these blocks the s03 gate; D-3 is the only one that misstates behavior.

## Limitations of this pass

- Per instruction, **no git commands were run**; verification is against the
  working tree at this head, not a base diff.
- Only this file was written. No brief, graph, source, CSS, or path-1 file was
  modified.
- Historical execution IDs in `UI-GRAPH.yaml` (`E8895`) are immutable prior-run
  artifacts; this pass runs under `E8363` and does not re-stamp them.

## Re-validation statement

The updated s03 section covers the complete required state surface (10/10) and is
DOM-aligned on testids, header/`user-name`, clear-button visibility, note ids,
the two distinct empty states, loading, error, 401, and the search state machine.
The residual drift listed above is descriptive and does not block this gate; the
implementation, `UI-GRAPH.yaml`, and the schema now agree on every state
transition and testid.
