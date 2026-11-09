# Scope report — f-v4-note-search (E5716, s02)

- Execution: **E5716** · step **s02.architect_scope_analysis** · role `architect`
- Process: `path-1.feature` **4.0.0** (entry `default`, platform `web`, profile `full`)
- Branch: `dev/path10-runner-10` · base SHA `9e7fae353c61e717505dc40019627a1d7ab48820`
- Inputs: `feature-request.md` (raw, immutable, 45 items), `s01-product-discuss.md`
  (draft feature brief, E5716), current code on the work branch, `path1.project.json`,
  `design/` 1.0.1, `ds.lock.json`, `invariants.json`, `UI-GRAPH.yaml`.
- Architecture model: `nexus_arch_gaps` = **0 open gaps/violations** for the
  scope; no `domain`/`client-path` nodes are modelled in archd, so the domain map
  below is derived from the repository surfaces and `change-definition.md`.
- Status: scope analysis only. **No code, `web/`, or `design/` change at s02.**

## 1. Affected domains and layers

| Domain / layer | Surface | Change / status |
|---|---|---|
| `notebook-api` | `main.go` (`Store.ListNotes`, `api.handleNotes`, `maxQueryBytes`) | Optional `q` on `GET /api/notes`: trim; empty/whitespace → all own notes; non-empty → case-insensitive substring over `Note.Text`; 512-byte cap before scan; `[]` never `null`; JSON error envelope. Owner predicate applied before the text predicate. |
| `notebook-web` | `web/index.html`, `web/app.js`, `web/app.css`, `web_ui_test.go` | Search field (`notes-search`), clear (`notes-search-clear`), count (`notes-search-count`), search-empty (`notes-search-empty`), retry/offline states; client-side filter of the loaded owner list; single `renderNotes()` path. |
| `notebook-tests` | `main_test.go`, `web_ui_test.go`, `web/e2e/notes-search.spec.js`, `web/e2e/auth-notes.spec.js` | Nine Go search tests, static UI oracle, 20 `SEARCH-E2E-*` scenarios plus CR-01/02/03; user-B isolation also covered by auth E2E-6. |
| `notebook-storage` | in-memory `Store` | Read-only projection; `note.UserID == userID` before filtering; no schema, migration, or persistence change. |
| `notebook-auth` | `requireAuth`, bearer parsing | Unchanged; `401` before method/query handling; no token, session, or TTL change. |
| `notebook-deploy` | `deploy/path1/e2e-preview.sh`, `path1.project.json` | `test2` preview + E2E entry; no runtime dependency change. |
| `path1-adapter` | `UI-GRAPH.yaml`, `ds.lock.json`, `component-refs.json`, `design-gaps.json`, `prototypes/v6/*`, `arch/frontend/pages/note-search.yaml` | UI graph, DS lock/gaps, and prototype refs owned here; s21/s22a consume them. |

## 2. Verified current-state facts (evidence, not approval)

The base already contains a complete reference implementation of the feature;
this run is a path replay, so scope is to re-validate and refine, **not** to add
new scope.

- `main.go:33` `maxQueryBytes = 512`; `main.go:193-205` `ListNotes` applies the
  owner predicate and always returns a non-nil slice.
- `main.go:530-557` `handleNotes` GET: auth → `q` cap → trim → `ListNotes` →
  substring filter; cap error `400 {"error":"query too long"}` before scanning.
- `main_test.go:934-1130` `TestNotesSearchFinds/NotFound/CaseInsensitive/
  Isolation/AuthRequired/EmptyQuery/WhitespaceQuery/Encoding/QueryTooLong`
  (cap before trim; exactly 512 bytes accepted).
- `web/index.html:79-105` search region, labelled `type="search"`,
  `aria-controls="notes-list"`, clear, count, base-empty and search-empty.
- `web/app.js:444-480` filter + single `renderNotes()`; search-empty only for a
  non-empty query over a non-empty collection; base `notes-empty` wins;
  `web/app.js:344-352` disables search when locked/busy/failed/offline/zero notes.
- `web/app.js:726-734` query is **in-memory only**; `:594-607` clears on
  no-token/401/logout. This supersedes any older "restore from sessionStorage"
  wording.
- `web_ui_test.go:175-234` asserts `type=search`, `aria-controls`, label, `role=search`,
  placeholder, ordering above the list, clear label/visibility, search-empty
  `role=status` + `aria-live=polite` + final copy.
- `web/e2e/notes-search.spec.js:173-787` `SEARCH-E2E-1..20` plus CR-01/02/03;
  `web/e2e/auth-notes.spec.js` E2E-6 covers user-B isolation independently.
- `ds-pin.json` / `ds.lock.json`: **Notebook DS 1.0.1**, digest
  `sha256:4e0ef105…c85e`, constraint `=1.0.1`, release `design/releases/1.0.1`.

## 3. Architecture constraints

1. **Same-origin static only.** UI is embedded from `web/index.html`,
   `web/app.js`, `web/app.css`; same-origin `/api/*`; no CDN, new origin, CORS,
   framework, or bundler. Unknown paths stay `404`.
2. **Owner-scoped only.** `q` narrows but never widens: `ListNotes(session.UserID)`
   first, then the text predicate. Missing and foreign notes stay
   indistinguishable; `UserID` stays `json:"-"` and never appears on the wire.
3. **`q` cap.** Decoded `q` > 512 **bytes** → `400 {"error":"query too long"}`
   before any note scan; exactly 512 bytes accepted; cap is bytes, not runes, and
   is evaluated **before** trim, so a >512-byte whitespace-only `q` is also `400`.
4. **No new dependencies.** `go.mod` unchanged; vanilla JS/CSS; Playwright stays
   1.64.1 as a test-only dependency; `package.json`/lock must not be rolled back.
5. **No title field.** `Note` is `{id, text}`; search is text-only. The UI
   `noteSearchText()` title branch is forward-compatibility only — this feature
   must not add, emit, or require a title.
6. **Frozen auth/storage/lifecycle.** No auth/session/persistence change; create,
   delete, reload keep working. Order stays auth → method → query handling.
7. **UI contract.** Stable testids `notes-search`, `notes-search-clear`,
   `notes-search-empty`, `notes-search-count`, `notes-retry`, `notes-offline`,
   `notes-offline-check`; clear restores the full list; search-empty is only for a
   non-empty query filtering a non-empty collection to zero; base `notes-empty`
   wins when there are no notes at all; query is in memory only.
8. **Scope guard.** No unrelated refactors; prod/main/stage and canary are out;
   `f-v3-auth-notes`, `E4312`, `E1320` are untouched; skip `s45`/`s46`.
9. **Deploy guard.** Preview only on `test2`; no prod/main/stage/test1/canary;
   Playwright 1.64.1; `pngdiff` OK.

## 4. Potential conflicts

| # | Conflict | Evidence | Risk | Mitigation |
|---|---|---|---|---|
| R-1 | **DS version drift** | `ds-pin.json`/`ds.lock.json` = 1.0.1 (digest `4e0ef105…`), but `change-definition.md`, `UI-GRAPH.yaml`, `arch/frontend/pages/note-search.yaml` still say 1.0.0 (digest `02f027a8…`). | s02a pin or s22a `ds-drift` gate can fail or report a false mismatch. | Treat `ds-pin.json` + `ds.lock.json` + `design/releases/1.0.1/manifest.json` as authoritative; reconcile stale docs at s02a/s10; no DS release change at s03. |
| R-2 | **Isolation predicate order** | `main.go:547-554` filters after `ListNotes`; `TestNotesSearchIsolation` guards it. | Moving the text predicate before the owner predicate leaks another user's notes. | Keep owner predicate first; keep `TestNotesSearchIsolation` and SEARCH-E2E-20 + auth E2E-6 as oracles. |
| R-3 | **Client filter vs server `q`** | UI never sends `?q`; API implements and tests it. | Matching drift (Go `strings.ToLower` vs JS `toLowerCase`, trim rules) and duplicate logic. | UI filter is authoritative for the screen; server `q` is the API contract; share ASCII/Cyrillic/special-char acceptance vectors; no per-keystroke requests. |
| R-4 | **Query lifecycle wording drift** | Older scope-report text says `sessionStorage` restore; current `web/app.js:726-734` is in-memory only and clears on 401/logout (`:594-607`). | Implementer restores a stale/foreign query after reload or user switch. | In-memory only is normative (AOD-3); clear on login/logout/401/no token; cover reload and user-B in E2E. |
| R-5 | **Empty-state precedence** | `web/app.js:472-480`; `web_ui_test.go` asserts base-empty wins; search disabled at zero notes. | Brief wording can be read as requiring search-empty with zero notes. | Confirm OD-2 (closed): base `notes-empty` wins; search-empty only when a non-empty query filters a non-empty collection to zero. |
| R-6 | **Title ambiguity** | `noteSearchText()` includes a future `title`; model is `{id, text}`. | Reviewers infer title search or a schema change. | Document text-only scope; no title field, wire field, or UI copy implying titles. |
| R-7 | **Evidence fragmentation** | User-B isolation lives in `auth-notes.spec.js` E2E-6 **and** `notes-search.spec.js` SEARCH-E2E-20. | s20c cites one suite and misses the other. | Cite both suites in s20c evidence; keep scenario ids stable. |
| R-8 | **Reference implementation already present** | Base contains search code/tests, so "before" state is not empty. | Steps may assume work is already accepted and skip verification, or overwrite good code. | Treat base code as evidence to re-verify, not approval; all gates/evidence must be regenerated for E5716. |

## 5. Design recommendations (s02a / s03)

- **Pin Notebook DS 1.0.1** from `design/releases/1.0.1/manifest.json`
  (`ds/v1.0.1`, digest `sha256:4e0ef105…c85e`); no new DS release if existing
  tokens cover search. Reconcile stale 1.0.0 references (R-1).
- **One screen:** `note-search` (`data-screen="notes"`, route `/`); login and
  register unchanged.
- **States to specify:** idle, results, no-results (`notes-search-empty`), empty
  (`notes-empty`), loading (`notes-loading`), error (`notes-error` + `notes-retry`),
  offline (`notes-offline` + `notes-offline-check`), offline-empty, locked (401).
- **Breakpoints:** 390px mobile (stacked search row, full-width 44px controls, no
  horizontal scroll) and 1200px desktop (centered column/card, inline search +
  clear). Map onto the existing `max-width: 640px` rules; do not invent a second
  system.
- **Accessibility:** visible label "Поиск заметок", `type="search"`,
  `aria-controls="notes-list"`, clear `aria-label="Очистить поиск"`,
  `role="status"` + `aria-live="polite"` on search-empty/count, 3px focus ring,
  clear returns focus to the search input.
- **Copy:** "Поиск заметок", "Поиск по тексту...", "Ничего не найдено. Сократите
  запрос или очистите поиск.", "Очистить", "Найдено N", "Удалить" (aria-label
  "Удалить заметку #N"), "Повторить", "Проверить сеть".
- **Accepted DS gaps:** `GAP-1` (count label), `GAP-2` (disabled input state),
  `GAP-3` (delete danger/registry omission) remain non-blocking and accepted;
  no ad-hoc tokens or local CSS.

## 6. Open decisions

| ID | Decision | Resolution for E5716 |
|---|---|---|
| OD-1 | Whitespace-only `q` | **Closed:** trim → empty → all own notes. |
| OD-2 | Zero notes + non-empty `q` | **Closed:** base `notes-empty` wins; search disabled at zero notes. |
| OD-3 | UI filtering source | **Closed:** client-side filter of the loaded list; no request per keystroke; server `q` remains the API contract. |
| OD-4 | Query persistence | **Closed:** in-memory only; no URL/storage persistence; cleared on login/logout/401/no token. |
| OD-5 | DS 1.0.0 vs 1.0.1 drift | **Open for s02a/s10:** pin 1.0.1 as authoritative; reconcile stale docs; no DS change. |
| OD-6 | Unicode case-fold parity | **Closed:** Go `strings.ToLower` semantics; no locale-specific collation; test ASCII/Cyrillic/special chars. |

No silent decisions: OD-1/2/3/4/6 are closed by `feature-brief.md`,
`change-definition.md`, and current tests; OD-5 is an explicit s02a/s10 item.

## 7. Traceability

- Backend contract: request items 12–23 → `INV-AUTH-REQUIRED`,
  `INV-USER-ISOLATION`, `INV-SEARCH-OWNER-SCOPE`, `INV-SEARCH-CASE-INSENSITIVE`,
  `INV-SEARCH-EMPTY-Q`, `INV-SEARCH-NOT-FOUND`, `INV-SEARCH-ENCODING`,
  `INV-SEARCH-Q-MAX`, `INV-WIRE-CASING`, `INV-REAL-TRANSPORT`.
- Web UI: items 24–30 → `INV-UI-LABEL`, `INV-UI-A11Y-NAME`, `INV-UI-TRUTH`,
  `INV-UI-ORACLE`, `INV-XSS-ESCAPE`, `INV-SEARCH-UI-FILTER`,
  `INV-SEARCH-UI-EMPTY`, `INV-SEARCH-UI-TESTIDS`.
- Deploy/E2E: items 31–40 → `INV-UI-E2E-PREVIEW`, `INV-NO-SKIP-TAGS`, `pngdiff`.
- Constraints: items 41–45 → frozen auth/storage, search-only scope, no
  `f-v3-auth-notes`/`E4312`/`E1320` changes, `test2` preview only.

## 8. Risks for downstream steps

- **R-1 DS drift** (above) — s02a must pin 1.0.1 and record the digest; s10
  reconciles the stale 1.0.0 references.
- **R-2 isolation regression** — any reordering of owner/text predicates; guarded
  by Go isolation test + SEARCH-E2E-20 + auth E2E-6.
- **R-3 create/delete skip re-filter** — single `renderNotes()` plus SEARCH-E2E-5/6.
- **R-4 preview drift** — Playwright 1.64.1 pin, `test2`-only lease, frozen DS.
- **R-5 cap-before-trim** — >512-byte whitespace-only `q` must be `400`.
- **R-6 stale evidence** — previous-run artifacts (E0809) are inputs, not proof;
  E5716 gates/evidence must be regenerated.

## 9. Out of scope

Auth/session/token/persistence changes; pagination, sorting, ranking, fuzzy
matching, highlighting; cross-user search; title field/search; new runtime
deps/bundler/DS release; prod/main/stage/test1/canary; `s45`/`s46`; changes to
`f-v3-auth-notes`, `E4312`, or `E1320`.

## 10. Recommendations to downstream steps

- **s02a:** pin DS 1.0.1 from `ds-pin.json`/`ds.lock.json`; normalize the
  `note-search` screen; fail-close if an approved 1.0.1 digest is unavailable.
- **s03/s04:** design from the current code + UI-GRAPH actualized graph; keep the
  single screen, DS-only styling, and the accepted GAP-1/2/3.
- **s10:** reconcile DS version references and carry R-1…R-6 into the change
  definition and risks.
- **s14:** contract matrix must include the 512-byte cap **before trim**, `[]` not
  `null`, owner predicate order, and both isolation suites.
- **s20/s20c:** implement/verify against the invariants, run `GOWORK=off go build
  ./...`, `go test ./...`, and Playwright 1.64.1 on `test2`; cite both
  `notes-search.spec.js` and `auth-notes.spec.js` for user-B isolation.
