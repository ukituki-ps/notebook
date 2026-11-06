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

All three units ran from their own pushed child branches. Each unit produced
nine step artifacts; no unit changed application code (the feature already
existed at the base), so the unit evidence is the verification record.

| Unit | Branch tip | s10–s12 | s13–s16 | s17–s18 | Verdict |
|---|---|---|---|---|---|
| notebook-search-api | `81ed0a3` | PASS | PASS | clean | PASS |
| notebook-search-ui | `b413578` | PASS | PASS | clean | PASS |
| notebook-search-deploy-e2e | `3eb413c` | PASS | PASS | clean | PASS |

- s13/s14/s16 were accepted with an independent architect session
  (`ses_e4cfc6e07ffe4iF3RvGq34CAUD`); s15 with an independent auditor session
  (`ses_e4cfc65dcffeOJG3pvNpjpQFIv`). Neither equals the unit author session.
- The machine merge gate initially failed only because the ORC container has no
  HTTPS push credentials (`could not read Username`). The three real `--no-ff`
  merges were performed and pushed via the SSH remote, then the idempotent
  merge check was retried. No force/skip was used.
- The three merge commits are in `dev/f-v4-note-search-validation-zero`
  (merge head `b784df8`); the integration report is
  `artifacts/units/integration-report.md`.

## 6. s20a/s20b/s20c

### s20a — integration (11 gates)

`gates_passed` on `b050e81`. Integration command
`E2E_BASE_URL=https://test2.nexus.ukituki.tech E2E_API_ONLY=1 bash deploy/path1/e2e-preview.sh`
passed; full Go suite and contract parity (41/41, drift 0) passed.

### s20b — preview deploy

- First deploy: `b050e81` on test2 (image `sha256:6844e622…`).
- s20c initially failed `pngdiff`: the E2E spec used `fullPage: true`, and
  SEARCH-E2E-1/3/6 were near-duplicates. The spec was corrected to
  element/state screenshots (notes-list, .notes-search, .card.notes,
  search-empty) with per-state viewport sizes; it was committed, redeployed,
  and the host E2E rerun.
- Authoritative deploy: `c267619` on test2, image
  `sha256:b8d61aec77af08a792f00aec5505d8ef0831584ee650651466929e96b992c92e`,
  build_args_hash `sha256:2c2f2727…`, `/healthz` build_ref `c267619`.
- The host runner log shows `preview-deploy: GREEN test2 on
  notebook-stand:test2-c267619`; only test2 was touched.

### s20c — E2E / f-v4 evidence

- Host E2E (`stand-runner-client E8363 e2e-preview`, transport git, target
  `c267619`) resolved `feature=doc/идеи/f-v4-note-search` and ran UI mode:
  **13/13 Playwright** (7 auth + 6 search), **6/6 SEARCH-E2E**, pngdiff OK.
- The host wrote `scenario-evidence.json` (6 scenarios), `evidence-manifest.json`
  and the six screenshots into the f-v4 feature dir. Because the ORC container
  and the authoring container do not share `/srv`, the same spec was rerun from
  the authoring worktree against **the same test2 build `c267619`** to produce
  the committed bytes. The host-run verdict is retained in the execution root;
  the committed evidence is byte-for-byte the local rerun of the same spec.
- Committed evidence: `doc/идеи/f-v4-note-search/screenshots/SEARCH-E2E-1..6.png`
  (7.0–22.9 KB, element/state, distinct; pngdiff OK) +
  `scenario-evidence.json` + `evidence-manifest.json`
  (sha256 `1952bb14d55ff938acfd07e3637ddea9dd58d924361fe4e04be1b462633fa030`).
- `preview-verdict.json` in the execution root: `result=pass`,
  `status=verified`, `mode=ui`, `evaluated_sha=c267619…`,
  `evidence_manifest_sha256=1952bb14…`.
- The s20c ORC gate returned PASS-NA because this validation run has no UI
  delta against its base (`5935e148` already contains the feature); the host E2E
  and evidence were still produced and verified. This is a gate-scope effect,
  not a code or evidence failure.
- Evidence is f-v4 only: `ORC_FEATURE_DIR`/git-diff resolution picked
  `doc/идеи/f-v4-note-search`; no f-v3 evidence was used.

## 7. s21–s22a

- s21 graph actualized from code: 3 pages, 23 components, 30 testids, 10
  states, 6 scenario refs; `graph-actualized` gate PASS-NA (no UI delta vs base).
- s22 result audit: PASS, AC-1..AC-5 with executable oracles, contract drift 0,
  fault catalog 20 (15 covered, 5 na, 0 gaps), 0 open critical/high. Nexus
  decision `f-v4-note-search/result-audit` v2 approved.
- s22a UI audit: accept, 12 items A–L, 0 blockers, 0 open critical/high, 1
  cosmetic (unused `.notes-search-empty` CSS selector), stand sha `c267619`.

## 7. s22b–s23

- **s22b red-team** — accepted with an independent reviewer session
  `ses_e4ce0fbfbffeipFcUHF5hacXaf` (model `qwen3.8-fast`, provider
  `llama-proxy`), author `ses_e4cffab3effecevpjqsiAV9qT2`
  (`deepseek-flash`/`deepseek`). 23 adversarial attempts on test2
  `c267619`: auth bypass/order, owner isolation, q abuse (`%`, `_`, very long,
  unicode, null, invalid escapes), method/id/status, XSS/rendering. All safe;
  0 critical/high/medium/low findings. Gate evidence: canary 3/3 found,
  fault catalog 20 items (15 covered/5 na/0 gap), fault-catalog-exec 20/20 ok,
  catalog-invariants ok (11 high/critical, 10 covered).
- **s22c adversarial code review** — accepted with an independent reviewer
  session `ses_e4cdcb1bdffeb0BYuxDKmeRynq` (same cross-pair), author
  `ses_e4cffab3effecevpjqsiAV9qT2`. Files reviewed: main.go, main_test.go,
  web/*, spec/*, invariants. 0 critical/high/medium/low; one cosmetic
  (unused `.notes-search-empty` CSS selector). Gate `gate-code-review` OK
  (cross-pair verified, 0 high+ findings).
- **s23 refinement** — skipped under the stated condition: 0 open
  critical/high after s22/s22b/s22c. Reason recorded in the execution log; no
  refinement code was needed.

## 8. s24 final acceptance

- `gate-acceptance-approval` uses `context.report_path` and a Nexus **s24**
  owner approval with `profile=blob`; the approval binds the exact bytes of
  this report (`payload_b64`, no `payload_json`). The request id and signed
  assertion are stored in
  `doc/идеи/f-v4-note-search/platform-dev-validation-zero/evidence/s24-approval.json`.
- Remaining s24 gates: tools-untouched, findings-seed, deliverable (report
  non-empty), process-meta-lint, ctx-manifest, findings-dod (project),
  findings-dod-process, oracle-cited, and report-nonempty.
- **Outcome: blocked on owner approval.** Request `apr_bf3c1da2417bd2a37e77829707db1515`
  was created at 23:16:22Z with blob digest `sha256:544cfc70…`, exact report
  bytes, and expired at 23:31:22Z unanswered (`state=pending`, assertion
  endpoint 409). A retry returned the same expired request (`created:false`),
  so no replacement card was minted. The execution therefore remains at
  `s24.team_lead_accept`; **s24 is not accepted** and no force/skip/waiver was
  used. All prior steps s01–s23 are accepted/green.
- At the stop point the execution has 0 open critical/high findings; 5
  inherited medium/low findings remain open (CR-1/CR-2/CR-3/RT-1/RT-2), none
  blocking. The extended independent reviews additionally report 2 low
  hardening items (invalid percent-escape degrades to empty q; unbounded
  notes-per-user) and 3 low code-review notes, all non-blocking.

## 9. Sessions, units, evidence

| Item | Value |
|---|---|
| Execution | `E8363` |
| Parent session | `ses_e4d243d58ffeXi7t5U6T5BP5Tx` |
| Unit authors | `ses_e4cffab3…` (api), `ses_e4cffa31…` (ui), `ses_e4cff993…` (e2e) |
| Independent architect | `ses_e4cfc6e07ffe4iF3RvGq34CAUD` |
| Independent auditor | `ses_e4cfc65dcffeOJG3pvNpjpQFIv` |
| s22b reviewer | `ses_e4ce0fbfbffeipFcUHF5hacXaf` (qwen3.8-fast/llama-proxy) |
| s22c reviewer | `ses_e4cdcb1bdffeb0BYuxDKmeRynq` (qwen3.8-fast/llama-proxy) |
| Unit branches | u01 `81ed0a3`, u02 `b413578`, u03 `3eb413c` |
| Integration merge | `b784df8` |
| Preview deploy | test2 `c267619`, image `sha256:b8d61aec…`, build_args `sha256:2c2f2727…` |
| f-v4 evidence manifest | `sha256:1952bb14d55ff938acfd07e3637ddea9dd58d924361fe4e04be1b462633fa030` |
| E2E | 13/13 Playwright, 6/6 SEARCH-E2E, pngdiff OK |

## 10. Residual risks

- ORC's internal git push uses HTTPS without credentials; child branch creation
  and the three unit merges were done through the SSH remote by the team-lead,
  then the merge gate was retried idempotently. No force/skip was used.
- `commit_bound_to_other_step` requires one commit per unit step; the unit
  evidence is committed step-by-step.
- The independent extended red-team probe (58 attempts) noted two **low**
  hardening items, neither blocking: (a) an invalid percent-escape in `q`
  degrades to an empty query and returns all of the caller's own notes
  (no cross-tenant leak, no 500); (b) there is no cap on notes per user, so a
  user can grow the shared in-memory list. Both are recorded here rather than
  fixed, to keep this run a validation of the existing feature.
- test2 is shared and was leased exclusively
  (`f3de666b-418e-4bd5-960c-af0d1f253a9e`); it is released after s24.
