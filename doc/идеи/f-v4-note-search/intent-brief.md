# Intent brief — f-v4-note-search (E8363)

- **Execution:** `E8363` · **Step:** `s07.requirements_reconcile`
- **Platform:** `web` · **Branch:** `validation/platform-dev-20261106-zero`
- **Base:** `5935e148584b5fef28bd77ac4e45b800f10da03b` · **Platform under test:** `730d144a`
- **Source:** `feature-request.md`, 45/45 items traced in `intent-trace.json`.

## Goal

Add an owner-scoped, case-insensitive substring search over existing notes — on
`GET /api/notes?q=<text>` and in the notes web view — without changing
authentication, persistence, or note lifecycle behaviour. This is a fresh
E8363 re-validation of the same intent, not a new scope.

## Asked → doing (R01–R45)

| ID | Asked | Doing |
|---|---|---|
| R01 | Small feature in path-10 | Keep `f-v4-note-search` small; no scope widening |
| R02 | path-1 3.2.2, default, web, full | Same process/profile on platform 730d144a |
| R03 | Base `f-v3-auth-notes` @406fa965 | Original base recorded; E8363 uses base 5935e148 |
| R04 | Branch `dev/f-v4-note-search`; feature dir | Dir unchanged; this pass uses the validation branch |
| R05 | Skip s45/s46 | Both stay skipped |
| R06 | Do not rework f-v3 | Reference only; no rollback |
| R07 | Do not touch E4312/E1320 | Neither resumed, accepted, or modified |
| R08 | No prod/main/stage/canary | test2 preview only |
| R09 | Gates s21/s22a/s22b/s22c/s24 | All mandatory, author ≠ reviewer |
| R10 | No force/skip/waiver/fake evidence | No bypass; only the 3 s07 files written |
| R11 | Fan-out after s20: 3 children/sessions | Verify 3 child executions, 3 distinct sessions, parent different |
| R12 | `GET /api/notes?q=` | Optional `q` on the existing endpoint |
| R13 | Without `q` → all own notes | All notes of the current user |
| R14 | `q` → case-insensitive search | Case-insensitive substring via `strings.ToLower` |
| R15 | Only current user's notes | Owner predicate first; `q` only narrows |
| R16 | No bearer → 401 | 401 before method/query handling |
| R17 | Empty `q` → all notes | All own notes, 200 |
| R18 | Whitespace-only: all notes or 400 | Choose **all notes** (allowed option, OD-1) |
| R19 | Test: finds a note | `TestNotesSearchFinds` |
| R20 | Test: absent not found | `TestNotesSearchNotFound` |
| R21 | Test: no cross-user notes | `TestNotesSearchIsolation` |
| R22 | Test: unauthenticated 401 | `TestNotesSearchAuthRequired` |
| R23 | Test: URL-encoding/specials | `TestNotesSearchEncoding` |
| R24 | Search field in notes view | `data-testid="notes-search"`, labelled |
| R25 | Filter list by query | Client-side filter of the loaded list |
| R26 | Clear restores full list | `notes-search-clear` resets to full list |
| R27 | Empty state "ничего не найдено" | `notes-search-empty`, copy `Ничего не найдено.` |
| R28 | Do not break create/delete/reload | Same render/filter path; query re-applied |
| R29 | Testids for field and empty state | `notes-search`, `notes-search-empty` |
| R30 | Actualize UI graph | `UI-GRAPH.yaml` actualized at s21 |
| R31 | Preview on test2 | s20b on test2 only |
| R32 | E2E login | Login precedes the notes flow |
| R33 | E2E create 2 notes | Two-note fixture |
| R34 | E2E finds one note | `SEARCH-E2E-1` |
| R35 | E2E finds nothing | `SEARCH-E2E-2` |
| R36 | E2E clear returns both | `SEARCH-E2E-4` |
| R37 | E2E user B isolation | Isolation scenario in the suite |
| R38 | Playwright 1.64.1, not 1.53 | Pin stays 1.64.1 |
| R39 | No package/lock rollback | Files untouched |
| R40 | `pngdiff` OK | s20c screenshot diff must pass |
| R41 | Auth/persistence unchanged | Frozen; search is read-only |
| R42 | Search scope only | No unrelated refactors |
| R43 | No f-v3 branch/artifact changes | None |
| R44 | E4312/E1320 untouched | None |
| R45 | Preview only test2; prod/canary out | test2 only |

## Where we interpreted / what we added

**No item was added to scope.** The trace is 45 × `match`, 0 ×
`reinterpreted`, 0 × `missing`, 0 × `dropped`, 0 `added: true`. No human
confirmation exists at s07, so refinements are recorded as precise `match`
interpretations rather than as `reinterpreted`.

Interpretations to confirm at s08 (non-blocking, already documented in s03–s05):

1. **R14 matching granularity** — "search" is implemented as case-insensitive
   **substring** matching (`strings.ToLower` on both sides, no locale collation,
   no prefix/token/fuzzy matching).
2. **R18 whitespace-only `q`** — the item explicitly allows "all notes" or
   `400`; we choose **all notes** (trim → empty).
3. **R24–R28 UI evaluation** — filtering is **client-side** over the already
   loaded owner-scoped list, with no request per keystroke; the separate
   `notes-search-clear` button is an additive affordance inside R26.
4. **R27 empty-state condition and copy** — shown only for a non-empty trimmed
   query, a non-empty loaded collection, and zero matches; exact copy
   `Ничего не найдено.`; `notes-empty` remains the genuinely-empty server state.
5. **R29 testids** — exact values `notes-search` and `notes-search-empty`.
6. **R38–R39 toolchain** — Playwright 1.64.1 stays pinned; package/lock are not
   rolled back.

**Not added:** query persistence across a full page reload via `sessionStorage`
`notebook.search`. The current UI/graph contains such a restore path, but R28
only requires that reload keeps working. It is **not** part of this contract;
see OD-6 below.

## Prototypes and design links

- s03 wireframes: [s03-proto-review.md](platform-dev-validation-zero/s03-proto-review.md)
  and `feature-brief.md` §Wireframes (10 states).
- s04 planned graph: [s04-graph-review.md](platform-dev-validation-zero/s04-graph-review.md)
  and [UI-GRAPH.yaml](UI-GRAPH.yaml).
- s05 re-validation: [s05-architect-validation.md](platform-dev-validation-zero/s05-architect-validation.md).
- s06 finalization: [s06-brief-final.md](platform-dev-validation-zero/s06-brief-final.md).
- Machine trace: [intent-trace.json](intent-trace.json).

## Open questions for s08 human review

1. **OD-6 (low, needs-human) — reload persistence.** Should the search query
   survive a full page reload via `sessionStorage` `notebook.search`?
   **Proposed resolution: do not persist.** The raw request requires only that
   reload keeps working (R28), not that the query survives. `sessionStorage`
   persistence stays out of scope unless the owner explicitly asks; if the owner
   wants it, record it at s08 as an added behavior before implementation freeze.
   It does not block s07 or the design gates.

No other open questions: OD-1 and OD-2 are closed and reflected in the table
above (R18 → all notes; R24–R28 → client-side filter over the loaded list).
