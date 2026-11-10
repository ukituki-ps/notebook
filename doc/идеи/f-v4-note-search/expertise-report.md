---
schema_version: "1.0"
feature_id: f-v4-note-search
execution_id: E6636
step: s05.architect_validation
ds_release: "1.0.1"
ds_digest: sha256:4e0ef1052a1401a928588445f921f7d231b7c0e7c9b10c181fdbbb439108c85e
prototype: v7
planned_graph: doc/идеи/f-v4-note-search/UI-GRAPH.planned.yaml
verdict: approve_with_open_decisions
blockers: 0
open_decisions_count: 2
closed_decisions_count: 5
risks_count: 8
---

# Expertise report — f-v4-note-search (s05 architect validation, E6636)

## 1. Verdict: design vs architecture constraints

**Approve with open decisions. 0 blockers.** The approved design (prototype v7
on Notebook DS 1.0.1, planned graph `UI-GRAPH.planned.yaml` of E6636) is
compatible with the path-10 architecture: no new origin, dependency, storage
field, endpoint, auth path, or persistence is introduced. The tree already
contains the U01/U02 implementation (`main.go`, `web/*`, `main_test.go`,
`web_ui_test.go`, `web/e2e/*`); it is used here as the implementation baseline
for validation, and s05 changes no code, design, or DS file. The open decisions
in §5 must be resolved at s07/s08; the conformance items in §6 belong to s20/s21.

| Constraint | Design / implementation evidence | Result |
|---|---|---|
| Same-origin static only | UI embedded via `//go:embed web/index.html web/app.js web/app.css` (`main.go:24-25`), served at `/`, `/app.js`, `/app.css` (`main.go:420-434`); no CDN/CORS/framework/bundler; DS code path is `web/app.css`. | PASS |
| No new dependencies | `go.mod` is stdlib-only (`module github.com/ukituki-ps/notebook`, `go 1.23`); `package.json` has only `@playwright/test 1.64.1` as a test-only devDependency; vanilla JS/CSS. | PASS |
| Owner-scope (`q` narrows only) | `ListNotes` applies `note.UserID == userID` before any text match (`main.go:195-207`); `handleNotes` filters the already owner-scoped slice (`main.go:548-556`); `UserID` is `json:"-"` (`main.go:67-71`). | PASS |
| `q` ≤ 512 bytes | `maxQueryBytes = 512` (`main.go:33`); decoded overflow → `400 {"error":"query too long"}` before scanning (`main.go:542-543`); exactly 512 accepted (`TestNotesSearchQueryTooLong`, `main_test.go:1107`). | PASS |
| Text-only notes | `Note{ID, Text}` (`main.go:67-71`); design adds no title field; `noteSearchText()` tolerates a future `title` without requiring one (`web/app.js:436-442`); API filters `note.Text` only. | PASS |
| Auth guard unchanged | `requireAuth` runs before method/query handling (`main.go:531`); 401 clears storage and redirects (`web/app.js:484-500`); login/register screens unchanged. | PASS |
| No query persistence | Query lives in `searchQuery` in memory (`web/app.js:335`); `sessionStorage["notebook.search"]` is only defensively removed, never read/written (`web/app.js:177,487,596,733`); reset on login/logout/401/user switch. | PASS |
| UI contract / testids | `notes-search`, `notes-search-clear`, `notes-search-count`, `notes-search-empty`, `notes-offline`, `notes-offline-check`, `notes-retry` in `web/index.html:67,79-107`; enforced by `TestUISemantics` (`web_ui_test.go:13`) and the search E2E suite. | PASS |
| No scope creep | Only search, clear, count, empty/search-empty, offline/retry states; no pagination, ranking, highlighting, or title field. Delete/create/reload unchanged. | PASS |
| No code/design change at s05 | `git status` shows only the s04 artifacts committed; this report is the only s05 artifact. | PASS |

## 2. DS validation

- **Pinned release:** Notebook DS **1.0.1** (`=1.0.1`), `ds_digest`
  `sha256:4e0ef1052a1401a928588445f921f7d231b7c0e7c9b10c181fdbbb439108c85e`,
  identical in `ds.lock.json`, `ds-pin.json`, `design-impact.md`, `UI-GRAPH.planned.yaml`,
  `component-refs.json`, `component-map.yaml`, and `design-gaps.json`.
- **Hashes recomputed and matching `ds.lock.json`:**
  `design/tokens.json` = `sha256:436af169ef28b64cac108288fae69d4ad6819330ac21ff048936a38af7265afb`;
  `design/registry.json` = `sha256:79d748c28c931af99fda53368d7217ac8ad1d838da7f99d5cd17104a7017c359`;
  `design/releases/1.0.1/manifest.json` = `sha256:dbc2983b548da8fbce8c860e8c6cff745b517dfd44caaf564a077a913c93e29b`;
  `web/app.css` = `sha256:be611ba4cfcb39f122255e38d101150516f619dd3a97327793832248da7baced`.
- **Registry:** 12 registry ids used verbatim of 14 in `design/registry.json`;
  `primitives/card` and `primitives/button-secondary` are correctly not counted
  (no node id / no state dependency). `n-note-form` is a composition
  (`primitives/textarea` + `primitives/button`); `n-offline` is a second
  `patterns/note-item` occurrence; `n-retry`/`n-offline-check` reuse
  `primitives/button`.
- **0 local instances:** the prototype links only `/web/app.css`; no local
  `<style>`, `style=`, instance classes, Kubiki, `frontend/src/ui/kit`, or v6 imports.
- **Path-6 gaps non-blocking:** `GAP-1` (`n-count`, missing pattern), `GAP-3`
  (`n-delete`, registry omission; `.delete-note` exists at `web/app.css:248-257`),
  `GAP-2` (`primitives/input` has no visual `disabled` state), `GAP-4` (utility
  classes `.brand/.user-name/.note-text/.notes-search-row/.muted`). All
  `blocking=false`, `status=accepted`; `path6_required=[n-count,n-delete]`.
- **Provenance caveat:** manifest `code.sha256` is the release snapshot and the
  manifest `commit` is pre-tag (`design-impact.md` residual 6); do not claim
  live equality between the manifest hash and the current `web/` tree.

## 3. UI graph check (planned, E6636)

- `UI-GRAPH.planned.yaml`: **19 nodes** = 1 page (`note-search`) + **18 UI nodes**;
  the 18 identities now match `units/note-search/proto.json` and
  `component-refs.json` **exactly** (the E0809 caveat about a page node,
  `n-note-text`, the missing `n-offline-check`, and the identity mismatch is
  resolved; `n-button` is the registry anchor with `abstract: true`).
- **69 edges:** `contains` 17, `renders` 12, `uses` 8, `state-transition` 22,
  `instance-of` 3, `reveals` 1, `filters` 1, `updates` 1, `mutates` 2,
  `offers` 2. Every node has at least one edge; the page node has 11 outgoing
  `contains` edges, and the remaining leaves are UI leaves (`n-button`,
  `n-empty`, `n-loading`, `n-note-textarea`, `n-notes-header`, `n-search-clear`,
  `n-search-empty`).
- **States:** 8 renderable states (`idle`, `results`, `no-results`, `empty`,
  `loading`, `error`, `offline`, `offline-zero`) plus the normalized alias
  `normal = idle`; `visible`/`hidden` node sets are 1:1 with `proto.json`
  `state_matrix`.
- **Traceability:** delete = `n-note-item → n-delete` (`contains`/`renders`) +
  `n-delete → web/app.css:248-257` (`uses`) + `GAP-3`; search =
  `n-search-field → n-search-clear`/`n-notes-list`/`n-count`
  (`reveals`/`filters`/`updates`) + `n-search-field → primitives/input` +
  idle/results/no-results transitions; count = `state-results/state-no-results
  → n-count` + `GAP-1`; offline = `state-any → state-offline|state-offline-zero`
  + `state-offline* → n-offline` + `n-offline → patterns/note-item`/`primitives/button`.
- **Planned vs actualized:** `UI-GRAPH.yaml` (E1868 s21, from-code) additionally
  models `n-note-text` and the transient `locked` (401) state and has no abstract
  `n-button`; this is an expected design-vs-code granularity difference, not a
  contradiction. s21 remains mandatory to re-actualize from the code of this run.
- `arch/frontend/pages/note-search.yaml` mirrors the planned graph: `status:
  planned`, `execution_id: E6636`, prototype v7, DS 1.0.1, 18 components,
  `offline-zero`, `path6_required=[n-count,n-delete]`.

## 4. Explicit B* decisions (no silent resolution)

| id | Decision | Trace |
|---|---|---|
| B-1 | Search is a read-only projection of the existing owner-scoped list; no auth/storage/lifecycle change. | request 12–18, 41; `main.go:195-207,548-556` |
| B-2 | `q` is trimmed; empty/whitespace-only `q` returns all own notes. | request 13,17,18; `spec/core.md` §1.1; `main.go:545` |
| B-3 | Matching is case-insensitive substring (`strings.ToLower` server, `toLowerCase` UI); no locale collation promised. | request 14; `INV-SEARCH-CASE-INSENSITIVE` |
| B-4 | Owner predicate before text predicate; `q` narrows only; `UserID` never serialized. | request 15; `INV-SEARCH-OWNER-SCOPE`; `main.go:67-71` |
| B-5 | Decoded `q` >512 bytes → `400 {"error":"query too long"}` before scan; exactly 512 accepted; bytes not runes. | request 23; `main.go:33,542-543`; `INV-SEARCH-Q-MAX` |
| B-6 | UI filters the already loaded owner-scoped list client-side; no request per keystroke. | request 24–26; `spec/core.md` §3; `web/app.js:436-450` |
| B-7 | `notes-search-empty` only for a non-empty trimmed query on a non-empty collection; base `notes-empty` wins for zero notes and search is disabled. | request 27; `spec/core.md` §3; `web/app.js:444-479`; scope-report OD-2 |
| B-8 | Create/delete/reload re-apply the active query; query is not persisted across reload and is cleared on logout/401/no token/user switch. | request 28; scope-report OD-4; `web/app.js:335,487,596,733` |
| B-9 | Stable testids for search/clear/count/search-empty/offline/offline-check/retry; labelled search with live status. | request 29; `spec/core.md` §3; `INV-SEARCH-UI-TESTIDS` |
| B-10 | Preview only on `test2`; Playwright 1.64.1; no package/lock rollback; no prod/main/stage/canary; s45/s46 skipped. | request 31,38,39,5,8,45 |
| B-11 | Notebook DS 1.0.1 only; 12 registry components; 0 local instances; GAP-1..GAP-4 accepted non-blocking; no Kubiki. | request 42; `ds.lock.json`, `design-impact.md` |
| B-12 | Planned UI graph at s04 (`UI-GRAPH.planned.yaml`, 19 nodes/69 edges) and mandatory actualization from code at s21 (`UI-GRAPH.yaml`). | request 30; s04 E6636; §3 above |
| B-13 | Offline data source is the in-memory already loaded list only; no SW/localStorage cache and no persistence promise; `offline` and `offline-zero` are separate states. | request 41–42; prototype v7 UX-04; `design-impact.md`; scope-report §2 |
| B-14 | Result count is visible only for a non-empty query on a non-empty, non-blocked collection, with `aria-live=polite`; value is `visible.length`. | request 24–27; prototype v7 UI-08/UX-13; `web/app.js:477-479` |
| B-15 | Design is authoritative for offline affordances: per-row delete is disabled while offline (DELETE needs the network); s20 must align code to v7 or record an explicit design change. | prototype v7 UX-03/state-matrix `offline`; §6 R-4 |
| B-16 | No title field: the future-looking `title` join in `noteSearchText()` is tolerated but no title is added, emitted, or required. | request 15; `main.go:67-71`; scope-report §3 |

Earlier OD-1 (whitespace `q`) and OD-6 (Unicode parity) remain closed by
`feature-brief.md`, `TestNotesSearchWhitespaceQuery`, and
`TestNotesSearchEncoding`. Scope-report OD-2/OD-3/OD-4 are closed by AOD-1/AOD-2/AOD-3
below; OD-5 is closed by the accepted DS gaps (GAP-1..GAP-4).

## 5. Open and closed decisions

```yaml
open_decisions:
  - {id: AOD-6, question: "Language policy for the notes UI?", options: ["full Russian", "keep technical English terms (Add/Logout/Notebook) with an explicit policy", "bilingual"], recommendation: "Record an explicit English-term policy (Notebook brand, Add, Logout) or localize Add/Logout to «Добавить»/«Выйти» consistently across code and prototype.", decision_ref: "feature-request.md #27; UX-08; web/index.html:63,73,105; prototypes/v7/exports", status: open}
  - {id: AOD-7, question: "390px order: composer before search or search before composer?", options: ["keep composer/Logout first (approved v7 prototype and current code)", "put search first per the s03 wireframe", "collapsible composer"], recommendation: "Confirm the approved v7 order (composer first, search above the list) or switch to search-first at 390; the deviation must be explicit because the primary feature control sits below the composer.", decision_ref: "feature-brief.md wireframes (lines 79-103); UX-10; export-390-idle.png; web/index.html:69-89", status: open}
closed_decisions:
  - {id: AOD-1, resolution: "Base notes-empty wins for zero notes; search is disabled when the loaded collection is empty (no phantom search-empty).", evidence: "scope-report OD-2; web/app.js:346,479; web_ui_test.go:13; v7 UX-01", status: closed}
  - {id: AOD-2, resolution: "Client-only filter over the loaded owner-scoped list; server q remains the API contract, no per-keystroke requests.", evidence: "scope-report OD-3; web/app.js:436-450; INV-SEARCH-UI-FILTER", status: closed}
  - {id: AOD-3, resolution: "No query persistence: in-memory only, reset on reload/login/logout/401/user switch; the earlier sessionStorage-restore recommendation is superseded.", evidence: "scope-report OD-4; web/app.js:335,487,596,733", status: closed}
  - {id: AOD-4, resolution: "Offline uses the in-memory loaded list only, labeled «загруженные заметки»; offline-zero is part of the approved v7; real cache/persistence stays out of scope.", evidence: "scope-report §2/§3; v7 UX-04; web/app.js:342,514,764", status: closed}
  - {id: AOD-5, resolution: "Count is visible only in results/no-results (non-empty query, non-empty collection), aria-live=polite, value = visible matches.", evidence: "v7 UI-08/UX-13; web/app.js:477-479; INV-SEARCH-UI-EMPTY", status: closed}
```

## 6. Risks and mitigations

| id | Risk | Mitigation / owner |
|---|---|---|
| R-1 | **DS residual drift (1.0.1):** typography drift is fixed in 1.0.1, but `radius.sm` is hardcoded in four rules, spacing still uses off-scale 6/10/14/18/20/48px, and Chromium renders controls at 45/92px against the 44/88px tokens. | Recorded, non-blocking; no `design/` edit at s05; s22a audits rendered CSS and ds-token-drift. |
| R-2 | **Registry omissions:** `.delete-note` (GAP-3), count label (GAP-1), input `disabled` state (GAP-2), utility classes (GAP-4). | Use existing DS class/tokens as-is; gaps accepted; proposals `button-danger`, `count-label`, input disabled for DS 1.x. |
| R-3 | **Two matchers (JS vs Go):** `toLowerCase`/`indexOf` versus `strings.ToLower`/`strings.Contains`; duplicate logic and potential divergence if server `q` is later used by the UI. | Keep the UI filter authoritative for the screen; server `q` stays the API contract; share acceptance vectors; do not move to per-keystroke requests without a new decision. |
| R-4 | **Offline delete parity:** approved v7 disables per-row delete while offline (UX-03), but `web/app.js` leaves rows enabled offline and the DELETE then fails. | B-15: align code to v7 at s20 or record an explicit design change; verify at s22a/s22e. |
| R-5 | **Offline clear parity:** v7 hides the clear control in `offline`; code keeps it enabled offline by design (CR-03) so the local query can always be cleared. | Decide at s20/s22a whether this intentional deviation is acceptable or v7 should show clear; no security or scope impact. |
| R-6 | **Spec/history drift:** `spec/core.md` and `visualized-brief.md` are historical DS 1.0.0 snapshots (UX-08); old contract text omits count/offline/retry. | s14 regenerates specs from `feature-brief.md` + this report + the active 1.0.1 artifacts; do not treat the historical snapshots as the design contract. |
| R-7 | **Static prototype:** the state-per-render prototype is not live-wired (UX-17), so interaction truth comes from code/E2E, not from `proto.html`. | E2E on `test2` (s20c) and the s21 from-code graph are the oracles; prototype is the visual/state contract only. |
| R-8 | **Graph granularity planned vs actualized:** planned graph has an abstract `n-button` and no `n-note-text`/`locked`; the actualized E1868 graph differs. | s21 re-actualizes from this run's code; difference is expected, not a blocker. |

## 7. Evidence

| id | Evidence |
|---|---|
| EV-1 | `orc_ctx`/`orc_status E6636`: s04 done (`a9fcba2`), s05 running; base `9e7fae35`. |
| EV-2 | `sha256sum design/tokens.json design/registry.json design/releases/1.0.1/manifest.json web/app.css` matches `ds.lock.json` (tokens `436af169…`, registry `79d748c2…`, manifest `dbc2983b…`, css `be611ba4…`). |
| EV-3 | `design/registry.json` has 14 components; 12 used; 0 local instances; `path6_required=[n-count,n-delete]`. |
| EV-4 | `UI-GRAPH.planned.yaml`: 19 nodes (page + 18 = `proto.json` identities), 69 edges, 8 renderable states + `normal` alias, no orphan nodes. |
| EV-5 | `main.go:24-25,33,67-71,195-207,531,548-556` implement embed, 512-cap, owner scope, auth-first; `web/app.js:335,342,436-450,477-479` implement in-memory query, offline detection, filter, count. |
| EV-6 | `main_test.go:934-1131` covers find/not-found/case/isolation/auth/empty/whitespace/encoding/512-cap; `web_ui_test.go:13` `TestUISemantics`; `web/e2e/notes-search.spec.js` + `web/e2e/auth-notes.spec.js`. |
| EV-7 | `invariants.json`: `INV-SEARCH-OWNER-SCOPE`, `CASE-INSENSITIVE`, `EMPTY-Q`, `NOT-FOUND`, `ENCODING`, `Q-MAX`, `INV-SEARCH-UI-FILTER/EMPTY/TESTIDS` (active). |
| EV-8 | `git status`: only untracked runner helpers; s04 artifacts committed at `a9fcba2`; s05 adds this report only. |
