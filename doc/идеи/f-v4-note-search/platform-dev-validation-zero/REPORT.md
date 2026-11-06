# Platform dev validation (zero) — notebook / f-v4-note-search

- Date: 2026-11-06 (UTC)
- Contour: dev platform + test2 only. Prod/preprod/test1 untouched.
- Platform SHA under test: `730d144a1e63837b590f3e95d01f67142ca3a699`
  (Nexus `/healthz` commit and ORC `/version` revision match).
- Project: `f41f0adb-67d9-4ddf-8ba9-0efd9c6e50a9`
- Process: approved `path-1.feature@3.2.2`, entry point `default` (s01 → s24).
- Execution: `E8363` (new, independent of E8895).
- Work branch: `dev/f-v4-note-search-validation-zero`
  (policy-compatible `dev/*`; the initial `validation/*` name was repaired
  before the s08 approval because Nexus `notebook/brief` allows only `dev/*`).
- Base / target head: `5935e148584b5fef28bd77ac4e45b800f10da03b`
  (actual head of `dev/f-v4-note-search-ae079e5c`; the stale `326ae62` head of
  `dev/f-v4-note-search` was NOT used).
- Authoring worktree: `/workspace/projects/notebook-valzero`
  (git worktree of the project repo, not an external clone).

## 1. Preflight

| Check | Result |
|---|---|
| Nexus dev `/healthz` | ok, commit `730d144a…`, db up |
| ORC `/version` | orc `730d144a…`, gate bundle `sha256:81505152…` |
| test2 `/healthz` | ok, build_ref `2210238`, commit `22102389…` |
| GitHub SSH | `Hi ukituki-ps/notebook!` |
| Feature dir | `doc/идеи/f-v4-note-search` |
| platform | `web` (not `both`; no mobile-lab) |

Evidence: `evidence/preflight.txt`.

## 2. Fresh execution

- `orc_start` created `E8363` with `session_id=ses_e4d243d58ffeXi7t5U6T5BP5Tx`,
  `entry_point=default`, `execution_transport=git`, `feature_profile=full`,
  `platform=web`, `base_sha=target_repo_head=5935e148…`.
- Started at `s01.product_discuss` (not `unit_batch`); s06a–s06e, s24a, s45, s46
  are skipped by the `default` entry point as designed.
- New work branch pushed to origin at `5935e148…` before start.

## 3. s01–s17 (design/spec/plan, fresh gates)

All steps were re-executed on this execution; artifacts were re-validated and,
where stale, corrected:

| Step | Agent | Result | Key evidence |
|---|---|---|---|
| s01 | product | pass | `s01-product-review.md`; 45/45 raw items covered |
| s02 | architect | pass | `s02-scope-review.md`; no material drift |
| s03 | proto | pass after fix | 10-state ASCII wireframe added to feature-brief |
| s04 | graph-builder | pass | planned UI-GRAPH `E8363` (3 pages, 23 components, 10 states) |
| s05 | architect | pass | `s05-architect-validation.md`; OD-6 carried to s08 |
| s06 | product | pass (gates_passed) | invariants 16 active + 2 proposed; test-ref gate |
| s07 | product | pass (gates_passed) | 45/45 `match`, `source_items_total=45`; OD-6 open |
| s08 | human | pass (owner approval) | `apr_ea69333dba9bdea070cdb7f5c6dede7a`, digest `9b7dc2b7…` |
| s10 | architect | pass (gates_passed) | change-definition for 5 domains |
| s11 | planner | pass | plan E8363, 1 milestone, 3 units, 10 tasks |
| s13 | planner | pass (gates_passed) | plan saved |
| s14 | spec | pass after gate fix | spec + 41-row contract matrix, drift 0 |
| s15 | planner | pass | M01 brief |
| s16 | planner | pass | T0001–T0010 briefs; unit_briefs bound to context |
| s17 | architect | pass (gates_passed) | coverage 45/45, gaps 0; 20 catalog ids (15 covered, 5 na) |
| s19 | team-lead | pass (gates_passed) | test2 lease `f3de666b-418e-4bd5-960c-af0d1f253a9e` |

Notes:
- s03 initially failed (5/10 states); the feature brief was expanded to 10
  states and re-reviewed.
- s14 contract matrix initially failed `gate-contract-matrix` (missing `test`
  column) and `gate-spec-coverage` (non-executable UI refs); both were fixed in
  the artifact and the gates then passed.
- No force/skip/waiver was used; no platform/path-1/deploy script was changed.

## 4. s20 fan-out and sessions

- Parent session: `ses_e4d243d58ffeXi7t5U6T5BP5Tx`.
- The first fan-out attempt failed because the ORC container could not push the
  child branches over HTTPS. The three child branches were created at
  `9ceafdb` from the validation branch via the SSH remote, then fan-out spawned
  3 children.
- Child executions and linked sessions (all different from the parent):

| Unit | Child execution | Session |
|---|---|---|
| notebook-search-api | `E8363-s20.sde_5fexecution-u01` | `ses_e4cffab3effecevpjqsiAV9qT2` |
| notebook-search-ui | `E8363-s20.sde_5fexecution-u02` | `ses_e4cffa31cffeVIcy4LpVF91u4f` |
| notebook-search-deploy-e2e | `E8363-s20.sde_5fexecution-u03` | `ses_e4cff9937ffeH0JuMTzqIMXAqQ` |

- Linkage was applied before the first unit accept; `orc_link_session`
  returned `applied:true` for all three.

## 5. s20 unit execution

(filled after unit execution)

## 6. s20a/s20b/s20c

(filled after integration/deploy/E2E)

## 7. s21–s24

(filled after audits and final acceptance)

## 8. Residual risks

- ORC's own git push uses HTTPS without credentials; child branch creation must
  be done through the SSH remote by the team-lead. This is a platform/tooling
  observation, not a feature defect.
- `commit_bound_to_other_step` means every unit step needs its own commit; the
  unit evidence files are committed step-by-step.
- test2 is shared and was leased exclusively for this execution; the lease is
  released after s24.
