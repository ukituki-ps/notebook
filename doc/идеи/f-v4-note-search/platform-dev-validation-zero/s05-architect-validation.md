# Architect validation — f-v4-note-search (s05.architect_validation)

- **Step:** `s05.architect_validation`
- **Execution:** `E8363`
- **Feature:** `f-v4-note-search`
- **Platform:** `web` (`path1.ui.json.platform = "web"`, same-origin static UI, `feature_profile = full`)
- **Branch (this pass):** `validation/platform-dev-20261106-zero`
- **Pass type:** fresh re-validation of the design after the s03 wireframe update
  (10-state ASCII schema) and the s04 planned-graph update (E8363). Nothing was
  rewritten; this validation is the only artifact produced by this step.

## Verdict

**PASS** — the design still respects the architecture constraints of the
path-10 contour, and no open decision is silently resolved. The updated brief and
planned graph are internally consistent enough for s06 finalization and s07
traceability.

There are **no blocking findings**. Two conditions must be carried forward:

1. **s07 must regenerate the intent trace under E8363** and must not inherit the
   prior `intent-trace.json` / `intent-brief.md` claim of `open_questions: []`
   and all-`match` verdicts. The updated s03/s04 design raises refinements that
   the prior E9294 trace did not record.
2. **s08 must confirm OD-6** (query persistence across a full page reload) or
   declare it a non-contract UI convenience. This is the only needs-human
   decision; it is low severity and does not block the design gate.

## Inputs reviewed

All paths relative to `/workspace/projects/notebook-valzero/`.

| Input | Role | Observed state |
|---|---|---|
| `doc/идеи/f-v4-note-search/expertise-report.md` | Architect validation (s05, prior revision) | B-1…B-9; OD-1/OD-2 closed; interface freeze; validation refs `a3d99d7` / `37648cb` / `41ae536` |
| `doc/идеи/f-v4-note-search/feature-brief.md` | Updated design brief | FINAL/s06 with s03 wireframes "revalidated for E8363"; 10 state blocks + state machine; API table; AC 1–6 |
| `doc/идеи/f-v4-note-search/UI-GRAPH.yaml` | Updated planned UI graph | `schema: ui-graph/v1`, `status: planned`, `source: design`, `execution_id: E8363`; 3 pages, 10 states, 30 testids, SEARCH-E2E-1..6 |
| `doc/идеи/f-v4-note-search/scope-report.md` | Scope/impact report | 4 domains; constraints 1–7; OD-1/OD-2; conflicts; 3-unit recommendation |
| `doc/идеи/f-v4-note-search/invariants.json` | Machine-readable invariants | 16 active + 2 proposed; search owner/case/empty/not-found/encoding/UI invariants active; no relaxation |

Supporting cross-checks (read-only): `feature-request.md` (45 items),
`s03-proto-review.md`, `s04-graph-review.md`, `s01-product-review.md`,
`intent-brief.md`, `intent-trace.json`, `spec/core.md`,
`spec/contract-matrix.md`, `path1.ui.json`, `main.go`, `web/index.html`,
`web/app.js`, `web_ui_test.go`, `web/e2e/notes-search.spec.js`.

## Architecture constraints — respected

| # | Constraint | Design evidence | Status |
|---|---|---|---|
| C1 | Auth, session, token, note storage semantics frozen; search is a read-only projection | B-1; brief Goal/Out of scope; expertise interface freeze | HOLDS |
| C2 | Auth guard order `auth → method → query`; missing/bad bearer `401` before query handling | scope constraint 2; B-1/B-4; `spec/core.md` §1.1 | HOLDS |
| C3 | Owner predicate is first; `q` can only narrow, never widen | B-4; brief API "only the current user's notes"; `INV-SEARCH-OWNER-SCOPE` | HOLDS |
| C4 | No new runtime dependencies, no build tags, no framework/bundler in `web/` | scope constraint 4; Playwright is a test-only devDependency | HOLDS |
| C5 | Playwright stays 1.64.1; `package.json`/`package-lock.json` not rolled back | B-8; scope constraint 5 | HOLDS |
| C6 | Preview only on `test2`; prod/main/stage/canary out of scope | B-9; scope constraint 6; brief Out of scope | HOLDS |
| C7 | `f-v3-auth-notes`, `E4312`, `E1320` not modified | B-9; scope constraint 7; brief Out of scope | HOLDS (current tree; git ancestry not checked) |
| C8 | Interface freeze: `GET /api/notes` schema unchanged, no new endpoint/auth header/CORS, POST/DELETE unchanged | expertise interface freeze; `spec/core.md` §1.2, §5 | HOLDS |
| C9 | No new lock and no lock-order change | expertise risk 2; scope architecture notes | HOLDS in intent; wording drift D-2 |
| C10 | Existing invariants remain active; no auth/persistence invariant relaxed | `invariants.json`; brief Finalization note | HOLDS |

The updated 10-state wireframes add auth, loading, error, unauthorized, and
genuinely-empty surfaces that are explicitly "unchanged from f-v3". They do not
expand the feature scope and do not relax C1/C3/C8.

## Open decisions (`open_decisions[]`)

| id | Question | Status | decision_ref |
|---|---|---|---|
| OD-1 | Whitespace-only `q`: all notes or `400`? | **closed** | `expertise-report.md` B-2; `feature-brief.md` API contract (empty/whitespace rows); `scope-report.md` OD-1 → all notes |
| OD-2 | Server-side `q` vs client-side filtering? | **closed** | `expertise-report.md` B-6; `feature-brief.md` UX (filters the loaded list); `scope-report.md` OD-2 → both contracts; UI filters the loaded list |
| OD-3 | Exact `notes-search-empty` copy | **closed** | s03 resolves to `"Ничего не найдено."` (brief wireframe line 129; `UI-GRAPH.yaml` selector label; DOM line 94). The lowercase phrase in brief line 68 is a summary, not the exact oracle. |
| OD-4 | `search-empty` vs `genuinely-empty` when the loaded collection is empty and `q` is non-empty | **closed** | `UI-GRAPH.yaml` `search-empty` (requires a non-empty loaded collection) and `genuinely-empty` (empty collection → `notes-empty`). Precedence: genuinely-empty wins. B-7 must be read with the non-empty-collection guard; s07 should record it. |
| OD-5 | Visible `Clear` on a whitespace-only query | **closed** | `UI-GRAPH.yaml` `notes-search-clear` hides on **raw** empty only; `idle-list` covers whitespace as unfiltered. s04 D-2. No raw-request conflict; s21 should actualize the DOM rule. |
| OD-6 | Query persistence across a full page reload (`sessionStorage` `notebook.search`) | **needs human (low)** | `UI-GRAPH.yaml` transition "reload restores the saved query"; s04 open question 2; raw request R28 only says do not break reload, it does not require query persistence. s08 should confirm or drop/declare non-contract. |
| OD-7 | UI-graph testid inventory: 30 all-page vs 15 notes-only | **closed** | `UI-GRAPH.yaml` `testids_scope` / `testids_count: 30`; s04 D-6. Full inventory with explicit scope is acceptable; no raw-request conflict. |
| OD-8 | Error-state summary "usable in every loaded state" | **closed** | `feature-brief.md` specific error block (failed initial GET leaves controls disabled) and `UI-GRAPH.yaml` `error` govern; s03 D-3 / s04 D-3. s14 text should use the qualified wording. |

No decision is silently closed: every closed item has a design reference; the
only unapproved item is OD-6. The prior `intent-trace.json` (`open_questions: []`)
and `intent-brief.md` ("Open questions: 0") **must not be reused unchanged** —
they predate the s03/s04 updates and would silently absorb OD-5/OD-6/OD-7/OD-8.

## B*-decision traceability to the raw request

| B | Decision | Raw items | Trace class | s07/s08 action |
|---|---|---|---|---|
| B-1 | Search is a read-only projection; no storage/auth change | R12–R18, R41 | direct | keep `match` |
| B-2 | Trim `q`; empty/whitespace `q` returns all notes | R13, R17, R18 | delegated choice (R18 explicitly allows "all notes" or `400`) | s07 record as a resolved decision, not a pure `match`; s08 approves OD-1 |
| B-3 | Substring + `strings.ToLower` on both sides; no locale collation | R14 | **refinement/reinterpretation** | s07 mark `refined`; s08 explicitly approves matching granularity (substring, not prefix/token/fuzzy; no locale promise) |
| B-4 | Owner predicate first; `q` only narrows | R15, R21 | direct (trace should also cite R21 isolation test) | s07 add R21 to B-4 trace |
| B-5 | `q` decoded via `r.URL.Query().Get("q")` | R23 | implementation detail | keep `match`; bind R23 to `TestNotesSearchEncoding` |
| B-6 | UI filters the already loaded owner-scoped list; no per-keystroke request | R24–R26, R28, R29 | **refinement/reinterpretation** | s07 mark `refined`; s08 approves client-side filtering; add R28/R29 to B-6 trace; separate clear control is an additive design detail traced to R26 |
| B-7 | Empty state only for a non-empty trimmed query with zero matches | R27 | **refinement** (and under-specified) | s07 add the "loaded collection non-empty" guard and the exact `"Ничего не найдено."` copy; s08 approves; record OD-4 |
| B-8 | E2E on `test2`, Playwright 1.64.1, package/lock not rolled back | R31, R38, R39 | direct but trace incomplete | s07 expand to R31–R40, including R32–R37 scenarios and R40 `pngdiff` |
| B-9 | `s45.push_primary`/`s46.post_deploy_verify` skipped; no prod/main/stage/canary | R5, R8, R45 | direct | keep `match`; R6/R7 belong to scope constraint 7, not B-9 |

### Reinterpretations that must go to s07/s08

1. **R14 / B-3 — matching semantics.** The raw request says "case-insensitive
   search over note text"; the design narrows this to case-insensitive
   substring via `strings.ToLower`, with no locale collation and no
   prefix/token/fuzzy matching. This is a legitimate refinement, but it is not a
   literal restatement of R14 and must be recorded as a refinement.
2. **R24–R26/R28 / B-6 — client-side filtering.** The raw request requires a
   search field, filtering, and clearing; it does not specify client vs server
   evaluation or a separate clear button. The design chooses client-side
   filtering of the loaded owner-scoped list, no per-keystroke request, a
   separate clear control, and `sessionStorage` query persistence. OD-2 covers
   the client/server choice; the separate button and persistence should be
   traced as added design points (persistence is OD-6, needs human).
3. **R27 / B-7 — empty-state condition.** The raw request only names the empty
   state. The design adds the condition "trimmed query non-empty, loaded
   collection non-empty, zero matches" and the exact copy
   `"Ничего не найдено."`. This is a refinement and should be recorded, not
   marked as a pure `match`.
4. **R18 / B-2 — whitespace-only `q`.** The raw request explicitly delegates the
   choice ("all notes or `400`"). The design chooses all notes. This is a
   resolved decision, not a reinterpretation; s07 should use a resolved/decision
   verdict rather than `match`.
5. **R32–R37 / R40 — E2E scenarios and `pngdiff`.** B-8's current trace cites
   only R31/R38/R39. The six E2E scenarios and `pngdiff` are covered by brief
   AC 4 but are missing from B-8's trace; s07 should bind them explicitly.
6. **Process items R01–R11.** These are execution/process requirements (gates,
   no bypass, fan-out, skipped steps), not B-decisions. The prior trace maps
   several of them to `B-9/process`; s07 should bind them to the plan/scope
   rather than stretching B-9, which only covers the skipped deploy steps and
   the no-prod/canary constraint.

## Drift findings

### D-1 — Metadata/version drift in the prior validation and invariants

`expertise-report.md` "Validation status" cites draft brief `a3d99d7`, planned
graph `37648cb`, and scope report `41ae536`; `invariants.json` stamps
`execution_id: E9294`, `step: s06.feature_brief_final`,
`branch: dev/f-v4-note-search`. The updated brief and graph are now E8363. This
is historical metadata, not design drift. Do not rewrite those artifacts; this
s05 review is the E8363 re-validation reference, and s07 should cite it.

### D-2 — Lock wording is stricter than necessary

`expertise-report.md` risk 2 and `scope-report.md` architecture notes say the
filter runs "under the existing `Store.mu` read path" / while holding the lock.
At the implementation cross-checked in s02, `Store.ListNotes` returns a copy
under `Store.mu` and the handler filters that snapshot after the lock is
released. Behavior is safe: no new lock, no lock-order change, no mutation. The
design intent is satisfied; only the wording is stricter than the safe
implementation. Clarify at s14 as "filter the snapshot returned by `ListNotes`;
no new lock". Non-blocking.

### D-3 — Empty-state copy appears in two forms

`feature-brief.md` line 68 says `"ничего не найдено"` (lowercase, no period);
the s03 wireframe line 129 and `UI-GRAPH.yaml` label say `"Ничего не найдено."`.
s03 closed the exact-copy question in the schema; the prose bullet remains a
non-normative summary. s07 should cite the graph label as the exact oracle.
Non-blocking.

### D-4 — Wireframe `user:` prefix

The idle wireframe draws `user: [user-name]`; the graph records `user-name`
without the prefix, matching the DOM. Presentation-only; s04 D-1. Non-blocking.

### D-5 — Error-state summary wording

The brief's summary says search controls are "usable in every loaded state",
while the specific error block correctly says a failed initial GET leaves them
disabled until a successful reload. The specific block and the graph govern;
s03 D-3. Non-blocking wording drift.

### D-6 — Whitespace-only clear visibility

The brief says the clear control is hidden "while the query is empty"; the graph
and DOM hide it only for the **raw** empty string, so a whitespace-only query is
idle/list but still shows `Clear`. OD-5 closes this as acceptable; s21 should
actualize the DOM rule. Non-blocking.

### D-7 — Prior intent trace contradicts the updated design record

`intent-trace.json` (E9294) sets `open_questions: []`, marks all 45 items
`verdict: "match"`, `added: false`; `intent-brief.md` says "Open questions: 0"
while also listing 15 "Added / clarified points". The updated s03/s04 design
raises OD-5/OD-6/OD-7/OD-8 and the B-3/B-6/B-7 refinements. If s07 reuses the
prior trace unchanged, the new open decision (OD-6) and the refinements would be
silently resolved. This is the highest-priority traceability drift.

### D-8 — Trace coverage gaps in B-4/B-6/B-8

B-4 cites only R15 (not the R21 isolation test); B-6 cites R24–R26 (not R28
reload/create/delete regression or R29 testids); B-8 cites R31/R38/R39 (not the
six E2E scenarios R32–R37 or R40 `pngdiff`). These are trace-hygiene gaps, not
design conflicts; s07 should expand the trace.

### D-9 — Minor presentation drift (already known)

`web/app.css` defines a `.notes-search-empty` rule while the DOM uses
`class="muted"` (s03 D-6); the clear button's visible text `Clear` is not drawn
in the wireframe (s03 D-4); the form-order and note-id drifts from the earlier
pass are resolved. No design impact.

## Risks

1. **Stale trace / silent resolution (highest).** Reusing the E9294
   `intent-trace.json` with `open_questions: []` and all-`match` verdicts would
   silently swallow OD-6 and the B-3/B-6/B-7 refinements. Mitigation: s07
   regenerates the trace under E8363 and marks refinements explicitly.
2. **Scope creep through design conveniences.** `sessionStorage` query
   persistence and the separate clear button are additive behaviors not
   required by R24–R28. Mitigation: trace them; s08 confirms OD-6 or drops
   persistence.
3. **Empty-state oracle brittleness.** The exact copy differs between the brief
   prose and the graph/wireframe. Mitigation: use the graph label
   `"Ничего не найдено."` as the exact oracle; do not assert the lowercase
   summary.
4. **Stale query across user switch.** Persisted `notebook.search` can survive a
   later login in the same tab (REPORT RT-NEW-1, low). Mitigation: 401/logout
   clear the key; if persistence is kept, add a login-time clear or accept the
   residual risk explicitly.
5. **Lock-wording misinterpretation.** The design says "under `Store.mu`"; an
   implementer could move filtering under the lock unnecessarily. Mitigation:
   clarify s14 wording to "filter the `ListNotes` snapshot; no new lock".
6. **Implementation-informed design.** The updated brief asserts all 10 states
   are implemented, so design and code now describe each other. Mitigation: s07
   must trace to the raw request, not merely to the current DOM, and s21 must
   actualize the graph from code independently.
7. **No git verification.** Per instruction, no git commands were run; C7
   (`f-v3`/`E4312`/`E1320` untouched) is checked only against the current tree.

## Needs-human items

- **OD-6 (low):** confirm whether the search query should persist across a full
  page reload via `sessionStorage` `notebook.search`, or be treated as a
  non-contract UI convenience. If confirmed, s08 should record it as an accepted
  added behavior; if not, the reload-restore branch should be dropped before
  implementation-freeze. No other item requires a human answer beyond the normal
  s08 intent approval.

## Limitations

- Per instruction, **no git commands were run**. Verification is against the
  working tree at this head, not against a base diff; C7 is therefore a
  current-tree check only.
- Historical execution IDs in `expertise-report.md`, `invariants.json`,
  `intent-trace.json`, and `intent-brief.md` are prior-run artifacts (E9294 /
  E8895). This pass runs under E8363 and does not re-stamp them; s07 should
  reference this E8363 validation as the current design re-validation.
- Only this file was written. No brief, graph, scope, invariant, spec, source,
  CSS, or path-1 file was modified.

## Re-validation statement

The updated design — 10-state wireframes in `feature-brief.md`, the planned
E8363 `UI-GRAPH.yaml`, the unchanged `scope-report.md`, and the active
`invariants.json` — still respects the path-10 architecture constraints and
preserves owner scoping, auth order, envelope, and interface freeze. The design
is approved for s06 finalization and s07 traceability with the conditions above:
regenerate the trace under E8363, record B-3/B-6/B-7 as refinements, expand the
B-4/B-6/B-8 trace coverage, and resolve OD-6 at s08.
