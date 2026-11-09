# Scope report — f-v4-note-search

- Execution/step: **E0942** · `s02.architect_scope_analysis` · agent **architect**
  · `path-1.feature@4.0.0`, entry `default`, path-10
- Branch: `dev/path10-runner-11`, base `9e7fae3`
- Status: scope refresh for this execution. U01/U02/U03 are already present in
  `main.go`, `web/*`, `main_test.go`, `web_ui_test.go`,
  `web/e2e/notes-search.spec.js`; this step fixes scope, constraints,
  conflicts, and design inputs. **No code or design change is made at s02.**
- Sources: `feature-request.md` (immutable), `feature-brief.md` (s01 DRAFT),
  `s01-product-discuss.md`, approved `change-definition`
  (`f-v4-note-search/change-definition` v1), `plan.md`, `invariants.json`,
  `main.go`, `main_test.go`, `web/*`, `web_ui_test.go`,
  `web/e2e/notes-search.spec.js`, Notebook DS 1.0.1
  (`design/releases/1.0.1`, `design/tokens.json`, `design/registry.json`,
  `ds-pin.json`).

## 1. Affected domains / layers

| Domain / layer | Surface | Change / status |
|---|---|---|
| `notebook-api` | `main.go` (`handleNotes`, `ListNotes`, `maxQueryBytes = 512`) | Optional `q` on `GET /api/notes`: cap → trim → empty/whitespace means all; non-empty means case-insensitive substring over own notes; empty result is `[]`, never `null`; JSON error envelope; `401` before query handling. |
| `notebook-web` | `web/index.html`, `web/app.js`, `web/app.css`, `web_ui_test.go` | `notes-search` input in a `role=search` region, `notes-search-clear`, `notes-search-empty`, `notes-search-count`; client-side filter of the loaded owner-scoped list; `renderNotes()` re-applies the active query after load/create/delete/retry; query is in-memory only (leftover `sessionStorage["notebook.search"]` is removed). |
| `notebook-storage` | In-memory `Store` | Read-only projection; owner predicate `note.UserID == session.UserID` in `ListNotes` before filtering; no schema/migration; `UserID` stays out of the wire payload. |
| Auth | `requireAuth`, bearer parsing | Unchanged; `401` before method/query handling; no token, session, or TTL changes. |
| `notebook-tests` | `main_test.go`, `web_ui_test.go`, `web/e2e/notes-search.spec.js`, `web/e2e/auth-notes.spec.js` | 9 `TestNotesSearch*` Go tests (find, not found, case-insensitive, isolation, auth-required, empty, whitespace, encoding, 512-byte cap); static UI oracle; 20 `SEARCH-E2E-*` + 3 `CR-*` Playwright scenarios; user-B isolation also in auth E2E-6; `pngdiff` scenario. |
| `notebook-deploy` | `deploy/path1/*`, `path1.project.json` | Preview on `test2` only; API/search integration smoke; E2E discovers the search spec. |
| `path1-adapter` | `doc/идеи/f-v4-note-search/UI-GRAPH.yaml` | UI graph actualised from code at `s21` (`notes-search`, `notes-search-empty` nodes/testids). |

The approved `change-definition` maps these to changes C1–C5 with the same
domains; this report does not add a domain.

## 2. Architecture constraints

1. **Same-origin static only.** The UI is embedded from `web/index.html`,
   `web/app.js`, `web/app.css`; no CDN, new origin, CORS, framework, or bundler.
   `fetch` uses `credentials: "same-origin"`; unknown paths stay `404`.
2. **Owner-scoped only.** `q` may narrow the result but must never widen it.
   Missing and foreign notes stay indistinguishable; `UserID` remains
   `json:"-"` and is filtered in `ListNotes` before the text predicate.
3. **`q` cap.** The decoded `q` is capped at `maxQueryBytes = 512` bytes
   (`main.go:33`); a longer query returns `400 {"error":"query too long"}`
   before any note scan; exactly 512 bytes is accepted. The cap is bytes, not
   runes. Absent/empty/whitespace `q` returns all own notes.
4. **No new dependencies.** `go.mod` unchanged; vanilla JS/CSS; Playwright stays
   1.64.1 as a test-only dependency; `package.json`/lock are not rolled back.
5. **No title field.** `Note` is `{id, text}`; search is text-only. The UI
   matching helper tolerates a future `title`, but this feature must not add,
   emit, or require one.
6. **Frozen auth/storage/lifecycle.** No auth/session/persistence change;
   create, delete, retry, and reload keep working. Order stays
   auth → method → query handling.
7. **UI contract.** Stable testids `notes-search`, `notes-search-clear`,
   `notes-search-empty`, `notes-search-count`; labelled `type="search"` with
   `aria-controls="notes-list"`; clear restores the full list; search-empty is
   only for a non-empty query that filters a **non-empty** collection to zero;
   base `notes-empty` wins when there are no notes at all; existing
   `notes-loading`, `notes-error`, `notes-retry`, `notes-offline` states remain.
8. **Scope guard.** No unrelated refactors; production/main/stage and canary are
   out; `f-v3-auth-notes`, `E4312`, `E1320` are untouched.

## 3. Potential conflicts

| Conflict | Evidence | Risk | Mitigation |
|---|---|---|---|
| Client-side filter vs server `q` | UI never sends `?q`; `handleNotes` implements and tests it | Matching drift (Go `ToLower` vs JS `toLowerCase`, trim rules) and duplicate logic | Keep the UI filter authoritative for the screen; server `q` is the API contract for clients; share acceptance vectors; no per-keystroke requests without a new decision. |
| State duplication | `searchQuery`, input value, `notes[]`, and a legacy `sessionStorage` key coexist | Stale/hidden query after reload, user switch, 401 | `searchQuery` is the single source; always sync the input; remove `SEARCH_KEY` on login/logout/401/no-token; cover in E2E-8/E2E-10. |
| DS tokens vs current CSS | Tokens exist in `design/tokens.json` (1.0.1), but `web/app.css` still has a dead `.notes-search-empty` rule (the element only carries `class="muted"`) and some off-token sizes | False "token-compliant" claim and visual drift | Pin DS by manifest; s03 maps states to existing tokens; the dead rule is a DS proposal, not an ad-hoc value; s22a audits rendered CSS. |
| Empty-state precedence | Zero notes + non-empty `q` shows `notes-empty`; `renderNotes()` guards `noNotes`; `SEARCH-E2E-10` asserts it | Brief wording can be read as requiring `notes-search-empty` | OD-2 is resolved by current code + test: base-empty wins, search is disabled. |
| Release snapshot | DS 1.0.1 manifest `code.sha256` is a release snapshot; current `web/` has feature edits | Manifest misread as a live hash of current code | Pin tag/digest (`ds-pin.json`); do not claim current `web/` equals release code; re-release only if DS changes. |

The five package findings (`CR-1..3`, `RT-1..2`) target
`doc/идеи/f-dev-v1/spec/contract-matrix.md`, `main.go:83` (Store),
`main_test.go:49`, `path1.project.json` for unit `notebook.delete-note`; they
are **outside** this feature's scope and do not block s02.

## 4. Design recommendations (s02a / s03)

- **One screen only:** the notes screen gains search above the list; login and
  register are unchanged.
- **Pin the approved DS** from `design/releases/1.0.1/manifest.json`
  (`ds-pin.json`: `design_system_version=1.0.1`, digest
  `sha256:4e0ef105…c85e`), using `design/tokens.json` and
  `design/registry.json`. No new DS release if existing tokens cover search.
- **States to specify:** idle (empty query, list), loading (`notes-loading`),
  results (query + matches + `notes-search-count`), search-empty
  (`notes-search-empty`), base-empty (`notes-empty`), error (`notes-error`,
  `notes-retry`), and offline (`notes-offline`, `notes-offline-check`; copy
  "Ошибка сети. Проверьте соединение."; no new API behavior).
- **Breakpoints:** 390px mobile (search row stacked, full-width 44px controls,
  no horizontal scroll) and 1200px desktop (centered column/card, inline search
  + clear). Current CSS has a `max-width: 640px` query; frames must map onto it,
  not invent a second system.
- **Accessibility:** visible label "Поиск заметок", `type="search"`,
  `aria-controls="notes-list"`, clear `aria-label="Очистить поиск"`,
  `role="status"` + `aria-live="polite"` on the search empty state and count,
  3px focus ring.
- **Copy:** "Поиск заметок", "Поиск по тексту...", "Ничего не найдено...",
  clear "Очистить"; text-only, no title.
- **No extra controls/states:** keep create and delete untouched; do not add
  pagination, ranking, highlighting, or a title field.

## 5. Open decisions

| ID | Decision | Resolution for this scope | Status |
|---|---|---|---|
| OD-1 | Whitespace-only `q` | All notes (trim → empty → all); `TestNotesSearchWhitespaceQuery`, `SEARCH-E2E-7`. | **Closed.** |
| OD-2 | Zero notes + non-empty `q` | Base-empty wins; search disabled; `SEARCH-E2E-10`. | **Closed** by code + test. |
| OD-3 | UI filtering source | Client-only for this feature; server `q` is the independent API contract. | **Closed.** |
| OD-4 | Query persistence across reload | In-memory only; leftover `sessionStorage["notebook.search"]` is removed; `SEARCH-E2E-8`. | **Closed** by code + test. |
| OD-5 | DS empty-state drift | Dead `.notes-search-empty` rule (element uses `.muted`); normalize at s03/s22a without adding a token for one state. | **Open for s03/s22a.** |
| OD-6 | Unicode case-fold parity | Accept Go/JS differences and document: no locale-specific collation; test ASCII, Cyrillic, special characters. | **Closed.** |

No silent decisions: current code is evidence, not design approval; OD-5 is
explicitly carried to design.

## 6. Trace note

- The 512-byte cap is covered by `TestNotesSearchQueryTooLong` and
  `SEARCH-E2E-17`; `invariants.json` already lists `INV-SEARCH-Q-MAX`, so no
  new invariant is required at s02. Keep it active when s06 refreshes
  invariants.
- User-B isolation is covered by `TestNotesSearchIsolation` and
  `web/e2e/auth-notes.spec.js` E2E-6, plus `SEARCH-E2E-20`; s20c evidence must
  cite all three.
- `SEARCH-E2E-*` now has 20 scenarios (not 8) plus 3 `CR-*` regression
  scenarios; s20c `pngdiff`/E2E evidence should report the real count.

## 7. Arch-model reads

- `related` domains from the brief: the Nexus model has **no `domain`
  artifacts** registered for this project, so no per-domain related graph is
  available; the approved `change-definition`
  (`f-v4-note-search/change-definition` v1) is the authoritative target model
  and matches §1 (C1 `notebook-api`, C2 `notebook-web`, C3 `notebook-tests`,
  C4 `notebook-deploy`, C5 `path1-adapter`).
- `gaps` (open violations in affected domains): none returned. No open
  gap/violation artifact constrains this feature.
- The approved `change-definition` `not_scope` matches §2.8 and §4 exactly.

## 8. Handoff to s02a/s03

Inputs for design: this report, the s01 draft brief, DS 1.0.1 pin, and the
current `web/` implementation as evidence. Design must map the states in §4 to
the pinned DS and resolve OD-5; it must not add a second design system, a new
dependency, or out-of-scope controls.
