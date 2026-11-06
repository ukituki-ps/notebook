# Milestone brief — f-v4-note-search (s15.brief_milestone)

- **Step:** `s15.brief_milestone`
- **Execution:** `E8363`
- **Feature:** `f-v4-note-search`
- **Platform:** `web` (`feature_profile = full`)
- **Branch (this pass):** `dev/f-v4-note-search-validation-zero`
- **Base:** `5935e148` (`5935e148584b5fef28bd77ac4e45b800f10da03b`)
- **Pass type:** fresh E8363 re-validation; the milestone decomposition and scope
  are unchanged from the saved s11/s13 plan.
- **File written:** `doc/идеи/f-v4-note-search/M01/brief.md`

## Verdict

**PASS** — the single milestone `M01 Search end-to-end` is recorded with E8363
metadata and remains consistent with `plan.md`, `change-definition.md`, and
`spec/core.md` after the s10/s14 corrections. The goal, unit table, scope,
out-of-scope, and exit criteria are accurate for the code at this head.

## Inputs reviewed

- `doc/идеи/f-v4-note-search/plan.md` — 1 milestone, 3 units, T0001–T0010.
- `doc/идеи/f-v4-note-search/change-definition.md` — C1–C4, s10-corrected.
- `doc/идеи/f-v4-note-search/feature-brief.md` — final brief (s06/E8363).
- `doc/идеи/f-v4-note-search/spec/core.md` — API/UI contract (s14).
- `doc/идеи/f-v4-note-search/invariants.json` — 16 active + 2 proposed.
- `doc/идеи/f-v4-note-search/T0001`–`T0003/brief.md` — existing unit briefs.
- `doc/идеи/f-v4-note-search/UI-GRAPH.yaml` — planned E8363 graph.
- `main.go`, `main_test.go`, `web/index.html`, `web/app.js`, `web/app.css`,
  `web_ui_test.go`, `web/e2e/notes-search.spec.js`,
  `deploy/path1/e2e-preview.sh`, `path1.project.json` — cross-checks.

## Counts

| Item | Count |
|---|---|
| Milestones | 1 (`M01`) |
| Units | 3 (`U01`, `U02`, `U03`) |
| Tasks | 10 (`T0001`–`T0010`) |
| Task distribution | U01: T0001–T0004 · U02: T0005–T0007 · U03: T0008–T0010 |

## Changes to M01/brief.md

1. Added E8363 metadata: execution, step, platform, validation branch, base,
   pass type, and task range.
2. Added a `Tasks` column to the unit table (T0001–T0004 / T0005–T0007 /
   T0008–T0010) so each unit maps to the plan without changing the units.
3. Corrected the backend scope to the handler-level filter over the
   `ListNotes(session.UserID)` snapshot (`q` only narrows).
4. Corrected the UI scope: full empty-state guard (`hasQuery` + non-empty
   collection + zero matches), `notes-empty` separation, single render path, and
   OD-6 `sessionStorage` restore explicitly non-contractual.
5. Corrected the test scope: 8 backend search tests, `TestUISemantics`, and the
   six named Playwright scenarios; user-B isolation remains auth E2E-6 plus
   `TestNotesSearchIsolation`.
6. Corrected the preview scope: `E2E_API_ONLY=1` integration smoke is auth/notes
   only; search E2E is Playwright at s20c; graph actualization is s21.
7. Expanded out-of-scope with OD-6 query persistence and the search `q=` API
   smoke; exit criteria now state the six scenarios, auth E2E-6 isolation, and
   the s21/s22a/s22b/s22c/s24 gates.

## Consistency checks

- **Plan parity:** milestone name, units, task ranges, and exit gates match
  `plan.md`; no unit or task was added, removed, or renamed.
- **s10 corrections preserved:** no Store search helper, no search API smoke,
  no user-B isolation claim for the search spec, no E2E reload claim.
- **s14 alignment:** the backend and UI wording matches `spec/core.md` §1 and §3.
- **Scope:** nothing beyond the approved change definition and R01–R45.
- **Gates:** s21 graph, s22a UI audit, s22b/s22c reviews, s24 approval; s45/s46
  skipped.

## Legacy note

The pre-existing `T0001`–`T0003/brief.md` files are unit-level briefs from the
prior plan structure. They were not rewritten in this step; the authoritative
task definitions are `plan.md` plus the new `T0004`–`T0010` task briefs. This is
non-blocking for the milestone, which references the plan decomposition.

## Limitations

- No git commands were run; verification is against the working tree at this
  head.
- Historical execution IDs in `spec/core.md`, `contract-matrix.md`,
  `expertise-report.md`, and the legacy `T0001`–`T0003` briefs were not
  re-stamped.
- Only `M01/brief.md` and this review were written at s15.
