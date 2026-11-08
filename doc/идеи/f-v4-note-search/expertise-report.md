---
schema_version: "1.0"
feature_id: f-v4-note-search
execution_id: E0809
step: s05.architect_validation
ds_release: "1.0.0"
ds_digest: sha256:02f027a86bbf8993bd1c14bbb91d5c3ba4453f47e886be73487a28d2044dda3d
verdict: approve_with_open_decisions
blockers: 0
open_decisions_count: 7
---

# Expertise report — f-v4-note-search (s05 architect validation)

## 1. Verdict: design vs architecture constraints

**Approve with open decisions. 0 blockers.** The v6 design is compatible with
the path-10 architecture: no new origin, dependency, storage field, endpoint,
or auth path is introduced. The open decisions in §5 must be resolved at
s06/s08; the implementation items in §6 belong to s20.

| Constraint | Design / implementation evidence | Result |
|---|---|---|
| Same-origin static only | `web/index.html`, `web/app.js`, `web/app.css` are embedded (`main.go:22-25`); no CDN/CORS/framework/bundler; DS code path is `web`; prototype is local. | PASS |
| No new dependencies | `go.mod` unchanged (Go stdlib only); Playwright stays test-only at 1.64.1 (`package.json:9`); DS is vanilla. | PASS |
| Owner-scope (q narrows only) | UI filters the already loaded owner-scoped list (`web/app.js:362-368`); API calls `ListNotes(session.UserID)` before text matching (`main.go:537-556`); `UserID` is `json:"-"` (`main.go:67-71`). | PASS |
| `q` ≤ 512 bytes | API caps the decoded value before scanning (`main.go:541-545`, `maxQueryBytes=512`); 512 exactly is accepted. UI never sends `q` (`web/app.js:415`), so the cap is API-only today; `spec/core.md` omits the 400 row (R-3). | PASS with spec gap |
| Text-only notes | `Note{ID,Text}`; design adds no title field; `noteSearchText()` tolerates a future `title` without requiring one (`web/app.js:355-360`). | PASS |
| Auth guard unchanged | `requireAuth` runs before method/query handling (`main.go:530-534`); login/register screens are unchanged; UI clears storage and redirects on 401 (`web/app.js:392-401`). | PASS |
| No scope creep | No pagination/ranking/highlighting/title; design adds search, clear, count, and offline/retry states only. | PASS |

## 2. DS validation

- **Non-disk exactness:** Notebook DS `1.0.0` only (`=1.0.0`); `ds_digest`
  `sha256:02f027a8…da3d` matches `ds.lock.json`, `design-impact.md`,
  `visualized-brief.md`, `UI-GRAPH.yaml`, and `proto.json`.
- **Hashes recomputed:** `design/tokens.json` = `9cca3164…4068`,
  `design/registry.json` = `c2d4c3ae…d9d1`, release manifest = `72e26a2d…9bf2`;
  all match `ds.lock.json` and the manifest. `kit_sha256` matches.
- **12 registry components** used verbatim from 14 in `design/registry.json`;
  `primitives/card` and `primitives/button-secondary` are correctly not counted
  (no node id, no state dependency). `n-note-form` is a composition
  (`primitives/textarea` + `primitives/button`); `n-offline` is a second
  `patterns/note-item` occurrence. **0 local instances** (no local `<style>`,
  CSS, or instance classes).
- **Path-6 gaps non-blocking:** `GAP-1` (`n-count`, missing pattern),
  `GAP-3` (`n-delete`, registry omission; `.delete-note` exists at
  `web/app.css:248-257`), `GAP-2` (input `disabled` state missing). All are
  `blocking=false`, `status=accepted`; `path6_required=[n-count,n-delete]`.
- **Code path / no Kubiki:** DS implementation is `web/app.css`; no Kubiki,
  `frontend/src/ui/kit`, or v6 imports. Caveat: manifest `code.sha256` is the
  release snapshot, not the current working tree; do not claim live equality.

## 3. UI graph check

- `UI-GRAPH.yaml` has **18 nodes** and **43 edges** (7 `contains`, 12 `renders`,
  8 `uses`, 16 `state-transition`), `status: planned`, `source: prototype`.
- **States:** all 7 renderable states are covered — `idle` (+`normal` alias),
  `results`, `no-results`, `empty`, `loading`, `error`, `offline`; 8 state names
  in total, as in `proto.json`.
- **No orphan nodes:** every node has at least one edge. `n-search-field`,
  `n-search-clear`, `n-count`, `n-notes-list`, `n-note-item`, `n-note-text`,
  `n-delete`, each state node, `n-error`, `n-retry`, and `n-offline` are all
  reachable from `note-search` or a state node.
- **Traceability:** delete = `n-note-item → n-delete` (`renders`) +
  `n-delete → web/app.css:248-257` (`uses`) + `GAP-3`; search =
  `note-search → n-search-field` + `n-search-field → n-search-clear` +
  `n-search-field → primitives/input` + idle/results/no-results transitions;
  count = `note-search → n-count` + `n-count → design/tokens.json#--muted` +
  `visible/zero/hidden` + `GAP-1`; offline = `state-any → state-offline` +
  `state-offline → n-offline` + `n-offline → patterns/note-item`/`primitives/button`.
- **Caveat (non-blocking):** the graph's 18 node identities differ from the 18
  in `proto.json`/`component-refs.json`: the graph adds the page node and
  `n-note-text`, and omits `n-button` and `n-offline-check` (documented as
  composition/reuse). Counts agree; identities must be reconciled at s21.

## 4. Explicit B* decisions (no silent resolution)

| id | Decision | Trace |
|---|---|---|
| B-1 | Search is a read-only projection of the existing owner-scoped list; no auth/storage/lifecycle change. | request 12–18, 41 |
| B-2 | `q` is trimmed; empty/whitespace-only `q` returns all own notes (OD-1 closed). | request 13, 17, 18; `spec/core.md` §1.1 |
| B-3 | Matching is case-insensitive substring via `strings.ToLower`; no locale collation promised. | request 14; `spec/core.md` §1.1 |
| B-4 | Owner predicate is applied before the text predicate; `q` narrows only; `UserID` is never serialized. | request 15; `spec/core.md` §1.1/§2 |
| B-5 | `q` is decoded by `net/http`; decoded length >512 bytes → `400 {"error":"query too long"}` before any scan. | request 23; `feature-brief.md` API; `main.go:541-545` |
| B-6 | UI filters the already loaded owner-scoped list client-side; no request per keystroke. | request 24–26; `spec/core.md` §3 |
| B-7 | `notes-search-empty` only for a non-empty trimmed query on a non-empty collection; base `notes-empty` wins for zero notes. | request 27; `spec/core.md` §3; scope-report OD-2 |
| B-8 | Create/delete/reload re-apply the active query; query is restored from `sessionStorage` and cleared on logout/401/no token. | request 28; `spec/core.md` §3; scope-report OD-4 |
| B-9 | Stable testids `notes-search`, `notes-search-clear`, `notes-search-empty`; labelled search/clear with live status. | request 29; `spec/core.md` §3 |
| B-10 | Preview only on `test2`; Playwright 1.64.1; no package/lock rollback; no prod/main/stage/canary; s45/s46 skipped. | request 31, 38, 39, 5, 8, 45 |
| B-11 | Notebook DS 1.0.0 only; 12 registry components; 0 local instances; accepted gaps non-blocking; no Kubiki. | request 42; `ds.lock.json`, `design-impact.md` |
| B-12 | UI graph is planned at s04 and actualized from code at s21. | request 30; `UI-GRAPH.yaml` |

Earlier OD-1 (whitespace `q`) and OD-6 (Unicode parity) remain closed by
`feature-brief.md`. Scope-report OD-2/OD-3/OD-4/OD-5 map to AOD-1/AOD-2/AOD-3/AOD-4
below and are deliberately **not** silently accepted.

## 5. Open decisions (status: open)

```yaml
open_decisions:
  - {id: AOD-1, question: "Zero notes + non-empty q: which empty state wins?", options: ["base notes-empty wins (current code/test)", "search-empty wins", "disable/hide search when notes.length == 0"], recommendation: "Keep base notes-empty; additionally disable search when the loaded collection is empty.", decision_ref: "feature-request.md #27 vs #24-25; spec/core.md §3; scope-report OD-2; UX-05", status: open}
  - {id: AOD-2, question: "Client-side filter or server q (per-keystroke/debounced)?", options: ["client-only over the loaded list", "debounced GET /api/notes?q=", "hybrid"], recommendation: "Client-only for this feature; server q stays the API contract and is revisited with pagination/large lists.", decision_ref: "feature-request.md #24-26; feature-brief.md UX; spec/core.md §3; scope-report OD-3", status: open}
  - {id: AOD-3, question: "Does the query persist across reload?", options: ["restore from sessionStorage (current)", "reset on reload", "put q in the URL/hash"], recommendation: "Restore via sessionStorage, always sync the input, clear on logout/401/no token/user switch.", decision_ref: "feature-request.md #28; spec/core.md §3; scope-report OD-4; web/app.js:451-456", status: open}
  - {id: AOD-4, question: "What is the offline data source?", options: ["in-memory already loaded list only", "real cache (SW/localStorage)", "no offline state in this feature"], recommendation: "In-memory loaded list only and label it «загруженные заметки»; add an offline-zero variant if offline ships; otherwise defer the state out of s20.", decision_ref: "feature-request.md #41-42; feature-brief.md out-of-scope persistence; UX-02/UI-10", status: open}
  - {id: AOD-5, question: "When is the result count visible?", options: ["only for a non-empty query (results/no-results)", "always", "never"], recommendation: "Visible only in results/no-results with aria-live=polite; implement as visible.length at s20 (currently absent from web/).", decision_ref: "feature-request.md #24-27; visualized-brief.md states; UX-01", status: open}
  - {id: AOD-6, question: "Language policy for the notes UI?", options: ["full Russian", "keep technical English terms (Add/Logout) with an explicit policy", "bilingual"], recommendation: "Russian user-facing copy for the feature; localize Add/Logout to «Добавить»/«Выйти» or record an explicit English-term policy.", decision_ref: "feature-request.md #27; UX-08; web/index.html:63,72,105", status: open}
  - {id: AOD-7, question: "390px order: composer before search or search before composer?", options: ["keep composer/Logout first (current prototype)", "put search first per s03 wireframe", "collapsible composer"], recommendation: "Put search first on the notes screen; at minimum confirm the deviation, because the primary feature control is currently below the composer.", decision_ref: "feature-brief.md wireframes (lines 79-103); UX-10; visualized-brief.md layout", status: open}
```

## 6. Risks and mitigations

| id | Risk | Mitigation / owner |
|---|---|---|
| R-1 | **DS token drift:** `font.h1` 22px vs CSS `1.4rem` (22.4px); `font.body` 15px token vs 16px browser default; `font.secondary` 13px unused; `border_subtle` never referenced; `radius.sm` hardcoded; spacing 6/10/14/18/20/48/88px off-scale. | Recorded, non-blocking; DS 1.x cleanup, s22a audits rendered CSS. Do not edit `design/` at s05. |
| R-2 | **Registry omissions:** `.delete-note` absent from `design/registry.json`; no count pattern; no visual input `disabled`. | Use existing DS class as-is; GAP-1/2/3 accepted; propose `button-danger`, `count-label`, input disabled for DS 1.x. |
| R-3 | **Client filter vs API q cap:** UI never sends `q`; spec/core and contract-matrix omit the 512-byte/400 contract; `invariants.json` has no `INV-SEARCH-Q-MAX`. | Keep client-only (AOD-2); add the cap row and invariant before s14; never use `maxlength=512` (UTF-16 units, not UTF-8 bytes); map 400 if server q is later used. |
| R-4 | **Offline is not implemented:** `web/app.js` has no `navigator.onLine`, cache, or listener; a fetch rejection goes to the generic error path. | Resolve AOD-4 before s20; if implemented, source is the in-memory loaded list and an offline-zero variant is required; no persistence promise. |
| R-5 | **Count is not implemented:** no `notes-search-count` in `web/index.html`/`web/app.js`; design promises «Найдено N» with `aria-live`. | s20: `visible.length`, hidden for an empty trimmed query, keep polite live region; UX-01. |
| R-6 | **390 density:** composer (label + 3-row textarea + Add) precedes search; idle 926px / offline 1067px at 844px viewport; full-width Delete; search starts below the fold. | Resolve AOD-7; consider compact trailing Delete in a later DS pass; no horizontal overflow already verified. |
| R-7 | **Design states vs current app:** app lacks count, retry button, offline banner, and visible «Удалить»; error copy lacks «Попробуйте ещё раз.»; search is enabled with zero notes. | s20 checklist from P-10/UX-01/03/05/08/14/18; s21 reconciles graph to code. |
| R-8 | **Spec drift:** `spec/core.md` and `contract-matrix.md` predate v6 and omit count/offline/retry/512; `UI-GRAPH` node identities differ from `proto.json`. | s14 must regenerate specs from feature-brief + this report; s21 reconciles node ids. |

## 7. Evidence

| id | Evidence |
|---|---|
| EV-1 | `orc_ctx` (`s05.architect_validation`, project `f41f0adb-…`) and `orc_status E0809`: s04 done, s05 pending. |
| EV-2 | `sha256sum design/tokens.json design/registry.json design/releases/1.0.0/manifest.json` matches `ds.lock.json`. |
| EV-3 | `design/registry.json` has 14 components; 12 used; 0 local instances; `path6_required=[n-count,n-delete]`. |
| EV-4 | `UI-GRAPH.yaml`: 18 nodes, 43 edges, 7 states + `normal` alias, every node has an edge. |
| EV-5 | `main.go:541-545` implements the 512-byte cap; `web/app.js:362-368` filters client-side; `web/app.js:415` never sends `q`. |
| EV-6 | `grep notes-search-count web/ main.go` returns none; `grep notes-offline web/` returns none: count and offline are design-only until s20. |
| EV-7 | `git status` clean at `c7d82eb`; s04 graph commit present; no code/design/web change made by s05. |
