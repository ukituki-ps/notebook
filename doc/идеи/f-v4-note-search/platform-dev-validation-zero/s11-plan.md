# High-level plan — f-v4-note-search (s11.planner_high_level)

- **Step:** `s11.planner_high_level`
- **Execution:** `E8363`
- **Feature:** `f-v4-note-search`
- **Platform:** `web` (`path1.ui.json.platform = "web"`, `feature_profile = full`)
- **Branch (this pass):** `dev/f-v4-note-search-validation-zero`
- **Base:** `5935e148` (`5935e148584b5fef28bd77ac4e45b800f10da03b`)
- **Pass type:** fresh E8363 re-validation of the existing high-level plan at
  this head; metadata and the s10-noted wording drift were corrected, scope and
  decomposition were preserved. Only `plan.md` and this review were written; no
  source, spec, graph, path-1, auth, or persistence file was modified.

## Verdict

**PASS** — the plan is aligned with the E8363 change definition and the code at
this head. It keeps one milestone, three units, and ten tasks; the three
s10-noted drift points are corrected; execution order, verification strategy,
risks, and out-of-scope remain intact and internally consistent.

## Inputs reviewed

All paths relative to `/workspace/projects/notebook-valzero/`.

| Input | Role | Observed state |
|---|---|---|
| `doc/идеи/f-v4-note-search/change-definition.md` | Approved E8363 change definition | Five domains, C1–C4 before/after/files/acceptance, s10 corrections applied |
| `doc/идеи/f-v4-note-search/feature-brief.md` | Final brief (s06/E8363) | API table, search semantics, UX, 10-state wireframes, AC 1–6 |
| `doc/идеи/f-v4-note-search/intent-brief.md` | E8363 intent brief | R01–R45 asked→doing; OD-6 non-contractual |
| `doc/идеи/f-v4-note-search/invariants.json` | Invariants | 16 active + 2 proposed; search and UI oracles present |
| `doc/идеи/f-v4-note-search/plan.md` | Subject | Updated in this step (metadata + T0001/T0008/T0009 + verification wording) |
| `doc/идеи/f-v4-note-search/spec/core.md` | API/UI spec (s14) | Handler-level `q` filter over the owner-scoped `ListNotes` result |
| `doc/идеи/f-v4-note-search/T0001/brief.md` | Unit brief (API) | `notebook-search-api`, 8 backend search tests |
| `doc/идеи/f-v4-note-search/T0002/brief.md` | Unit brief (UI) | `notebook-search-ui`, `TestUISemantics` |
| `doc/идеи/f-v4-note-search/T0003/brief.md` | Unit brief (deploy/E2E) | `notebook-search-deploy-e2e`, 6 Playwright scenarios, s21 graph |
| `doc/идеи/f-v4-note-search/platform-dev-validation-zero/s10-change-definition.md` | Prior-step drift record | D-1 (no search API smoke), D-2 (6 E2E incl. create/delete-active), D-5 (T0001/T0009 wording), D-6 (metadata) |
| `path1.project.json` | Path-1 config | `integration: E2E_API_ONLY=1 bash deploy/path1/e2e-preview.sh`; `UI-E2E-PREVIEW` oracle; no search-specific config |
| `main.go` | API implementation | `handleNotes` parses/trims `q`, takes the `ListNotes(session.UserID)` snapshot, then filters in the handler |
| `web/e2e/notes-search.spec.js` | Search E2E | `SEARCH-E2E-1` find, `-2` not-found/empty, `-3` case, `-4` clear, `-5` create-active, `-6` delete-active |
| `deploy/path1/e2e-preview.sh` | Deploy/E2E harness | Auth/notes API smoke only; full Playwright unless `E2E_API_ONLY=1`; no `q=` search smoke |

## Decomposition (preserved)

- **Milestone:** 1 — `M01 Search end-to-end`.
- **Units:** 3 — `U01 notebook-search-api`, `U02 notebook-search-ui`,
  `U03 notebook-search-deploy-e2e`.
- **Tasks:** 10 — `T0001`–`T0010`, distributed 4 / 3 / 3 across U01 / U02 / U03.

| Unit | Tasks | Domain | Primary files |
|---|---|---|---|
| U01 `notebook-search-api` | T0001–T0004 | notebook-api | `main.go`, `main_test.go` |
| U02 `notebook-search-ui` | T0005–T0007 | notebook-web | `web/index.html`, `web/app.js`, `web/app.css`, `web_ui_test.go` |
| U03 `notebook-search-deploy-e2e` | T0008–T0010 | notebook-deploy | `web/e2e/notes-search.spec.js`, `deploy/path1/e2e-preview.sh`, `path1.project.json`, `UI-GRAPH.yaml` |

## Changes vs prior plan (E9294 → E8363)

1. **Metadata re-stamped.** Execution `E9294` → `E8363`; branch
   `dev/f-v4-note-search` → `dev/f-v4-note-search-validation-zero`; base
   `406fa965` → `5935e148`; added step `s11.planner_high_level`, platform `web`,
   and the fresh-re-validation note. Resolves s10 D-6 for the plan record.
2. **T0001 corrected.** "Store/List search helper" → "Handler-level
   owner-scoped filter over the `ListNotes` snapshot (no Store helper)". Matches
   `main.go`: `ListNotes(session.UserID)` is the owner predicate, and the
   handler filters that snapshot by trimmed lowercase `q`. Resolves s10 D-5.
3. **T0009 corrected.** "API smoke + adapter" → "Integration smoke (auth/notes
   only) + adapter; search E2E runs via Playwright at s20c", oracle
   `E2E_API_ONLY=1` auth/notes smoke. `deploy/path1/e2e-preview.sh` has no `q=`
   assertion; the full Playwright run at s20c exercises search. Resolves s10 D-1.
4. **T0008 clarified.** Names the six scenarios (find, not-found, case, clear,
   create-active, delete-active) and the `SEARCH-E2E-1..6` oracle. User-B
   isolation is not a search-spec scenario; it stays with auth E2E-6 and
   `TestNotesSearchIsolation`. Resolves s10 D-2.
5. **Consistency edits.** Execution order step 3 now says s20c runs the
   auth/notes API smoke plus Playwright search E2E; the stand verification line
   no longer claims a search API smoke; the create/delete risk mitigation no
   longer claims E2E reload coverage (reload wiring stays with
   `TestUISemantics`).

Unchanged: the single milestone, three-unit fan-out (one session per child),
s20a integration, s20b/s20c preview/E2E, s21 graph, s22/s22a/s22b/s22c audits,
s23 refinement, s24 owner approval; backend/UI/stand/graph verification axes;
the three risks; and the out-of-scope list (auth/persistence, pagination /
ranking / fuzzy / highlighting, new runtime deps, prod/main/stage, canary,
s45/s46, f-v3/E4312/E1320).

## Consistency checks

- **Counts:** 1 milestone, 3 units, 10 tasks — same as the prior plan.
- **Unit boundaries:** all task files fall inside their unit's declared surface;
  `web_ui_test.go` stays with U02, `main_test.go` with U01.
- **Oracles:** every task row names an existing test, E2E scenario set, or gate
  (`TestNotesSearch*`, `TestUISemantics`, `SEARCH-E2E-1..6`,
  `E2E_API_ONLY=1` smoke, `s21`).
- **No reintroduced overclaim:** no search `q=` API smoke, no user-B isolation
  claim for the search spec, no `T0001` Store helper, no E2E reload claim.
- **Scope:** the plan adds nothing beyond the approved change definition and
  raw-request constraints R01–R45.

## Limitations

- Per instruction, **no git commands were run**; verification is against the
  working tree at this head, not a base diff.
- Historical execution IDs and branch labels in `expertise-report.md`,
  `invariants.json`, `intent-trace.json`, `spec/core.md`, `contract-matrix.md`,
  and the `T*/brief.md` files are prior/parallel-run metadata and were not
  re-stamped; this review records the E8363 plan state.
- Only two files were written: `doc/идеи/f-v4-note-search/plan.md` and this
  review.
