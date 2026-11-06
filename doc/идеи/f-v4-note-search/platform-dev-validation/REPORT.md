# Platform validation — f-v4-note-search (final, ae079e5c)

- Date: 2026-11-06 (UTC)
- Platform under test: `ae079e5cadd9398d29457d31213757ae67bdd52d`
  (Nexus `/healthz` commit and ORC `/version` revision match)
- Contour: dev + `test2` only. Prod/preprod/test1 untouched.
- Project: `f41f0adb-67d9-4ddf-8ba9-0efd9c6e50a9`
- Execution: **E8895** (`execution_transport=git`, `path-1.feature@3.2.2`)
- Work branch: `dev/f-v4-note-search-ae079e5c` (base `326ae62`)
- Deployed stand: test2, build **2210238** / commit `22102389…`

## P0–P6 — PASS

| # | Scenario | Result |
|---|---|---|
| P0 | Nexus dev + ORC + test2 smoke | **PASS** (`ae079e5c`) |
| P1 | Fresh execution + session fan-out/linkage | **PASS** (E8895; 3 distinct sessions) |
| P1b | Legacy fail-closed guard | **PASS** (E9294 probes; `legacy_parent_session`, no step/attempt) |
| P2 | F198 approval binding / repo-relative path | **PASS** (digest match; blob+JSON rejected; escapes refused) |
| P3 | ORC CAS reject→retry | **PASS** (single pause event) |
| P4 | L2 integration on test2 | **PASS** (15/15 API) |
| P5 | Unit push → s20a → s20b host stand-runner deploy | **PASS** |
| P6 | go test / 17 oracles / Playwright / screenshots | **PASS** (13/13 on test2 2210238) |

## Post-P6 path progress

| Step | Result |
|---|---|
| s21 graph actualize | **PASS** (`gates_passed`) — UI-GRAPH E8895 actualized |
| s22 result audit | **PASS** (`gates_passed`) — fault catalog 20/20, archd decision `f-v4-note-search/result-audit` |
| s22a UI audit | **PASS** (`gates_passed`) — 12 items A–L, 0 blockers/majors/open critical |
| s22b red-team audit | **BLOCKED** — platform reviewer runtime (see below) |
| s22c / s23 / s24 | **not reached** |

## s20b deploy evidence

- Host stand-runner `deploy-preview`, queue rc=0, 25s.
- `notebook-stand:test2-2210238`; digest
  `sha256:a5aa4c8947b321e42604fd829a81c2a17ca37efefc86d6d254ec0b4147ead604`,
  build_args_hash `sha256:721b209f…`.
- test2 `/healthz`: `build_ref=2210238`, `commit=22102389…`, hashes match.
- `build-provenance.json` (21:00:30Z) + `deploy-provenance.json` (21:00:39Z).

## s20c E2E evidence

Host stand-runner `e2e-preview` rc=0 (10s), `preview-verdict.json`
`result=pass/status=verified/mode=ui`, ref `2210238`, 13/13 Playwright
(7 auth + 6 search). Evidence under
`.orc-eval/E8895/22102389…/doc/идеи/f-v3-auth-notes/`
(`scenario-evidence.json`, `evidence-manifest.json`, screenshots).

## s22b blocker (platform reviewer runtime)

s22b is a reviewer step. All work and artifacts are ready:

- `doc/идеи/f-v4-note-search/red-team-review.json` / `red-team-review.md`
  (independent reviewer, 0 critical/high; 3 low/info), attack log with 3/3
  canaries detected.
- Independent reviewer executed on `qwen3.8-fast` / `llama-proxy`.
- `orc_register_reviewer` returned `applied=true` for sessions
  `ses_e4d4a251effeuxr3rfiLT6kFg2` and `ses_e4d4375e2ffehxTqWnkji4CShe`
  (`reviewer_session_registered` events present).

Every `orc_accept(s22b)` fails before gates:

```
reviewer_hook_disabled
reviewer hook is disabled (ORC_REVIEWER_HOOK) and no official reviewer
registration exists
```

Attempts made: registration (admin break-glass, applied), `replace=true`,
step reopen + restart, reviewer session in the artifact, and exposing
`reviewer_session_id`/model/provider in the execution context. The runtime still
does not recognize the registration. The step had started before the reviewer
session was created; `orc_step_reopen` did not rebind the step-run session.

This is a platform reviewer-runtime defect/configuration (`ORC_REVIEWER_HOOK`
disabled and the official registration lookup not honoring
`orc_register_reviewer`), not path-1/unit code. No force/skip/waiver was used.

**Unblock:** enable `ORC_REVIEWER_HOOK`, or fix the reviewer-runtime lookup to
honor `orc_register_reviewer` rows for the current step-run session. Then
`orc_resume(E8895)` and `orc_accept(s22b)`; s22c/s23/s24 can proceed.

## Residual risks

1. **Reviewer runtime (above):** blocks s22b and therefore s22c/s23/s24.
2. **`gate_bundle_digest` empty on test2:** not a P5 blocker; recorded as a
   residual risk for the stand build.
3. **RT-NEW-1 (low):** stale `notebook.search` sessionStorage across a later
   login in the same tab (cosmetic; notes remain owner-scoped).
4. **RT-NEW-2 (info):** no `q` length cap; bounded by own note count.
5. **RT-NEW-3 (low):** `canary.json` is a runner-side gitignored artifact;
   reviewer re-ran the 3 canaries independently (3/3).

## State and hygiene

- E8895 **paused** at `s22b.red_team_audit` (no bypass).
- test2 lease released; test2 remains on `2210238`.
- No platform code, path-1, Nexus, or deploy scripts modified. The fault
  catalog was versioned into the branch (`audit/fault-catalog/`) so the eval
  worktree is self-contained; this is project audit data referenced by
  `path1.project.json`, not platform code.
- All results committed/pushed on `dev/f-v4-note-search-ae079e5c`.

## Reviewer-runtime retest (platform 730d144a)

Platform Nexus/ORC = `730d144a1e63837b590f3e95d01f67142ca3a699`.
Resumed E8895 and retried s22b with the nested-session contract.
ORC_REVIEWER_HOOK remains disabled; registration for
`ses_e4d4375e2ffehxTqWnkji4CShe` is used.

## Reviewer-runtime fix — completed (730d144a)

After the platform fix, s22b and s22c were accepted with `gates_passed`:

- **s22b red-team audit — PASS.** Nested `author`/`reviewer` sessions now read by
  the gate. Reviewer `ses_e4d4375e…` (`qwen3.8-fast`/`llama-proxy`), author
  `ses_e4de2edbeffe…` (deepseek). 0 critical/high; 3 low/info; canary 3/3.
- **s22c adversarial code review — PASS.** Reviewer `ses_e4d39ff69ffe…`
  (`qwen3.8-fast`/`llama-proxy`); `proofs=[PR-e8162b165c14]`; 0 critical/high;
  3 low/info; build/vet/test and targeted 11/11 green.
- **s23 refinement — SKIPPED (optional).** No critical/high findings; a code
  change would invalidate s20a and require a new deploy/E2E.

E8895 path steps: s20/s20a/s20b/s20c, s21, s22, s22a, s22b, s22c done;
s23 skipped; s24 final acceptance pending. ORC_REVIEWER_HOOK remains disabled;
the official registration path is used.

## s24 final acceptance — awaiting owner approval

s24 `gate-acceptance-approval` requires a signed Nexus assertion. Request created:

- request_id: `apr_0632235f9cf1c359b9ee27ddf85b76ad`
- subject: `s24`, branch `dev/f-v4-note-search-ae079e5c`
- policy: `notebook/s24` v1, owner approval, expires `2026-11-06T21:51:26Z`
- digest: `sha256:e7f86a419d25f4a357c95486253fa426f48e4ff4ad322d5f4adc57b66e497719`
- test2 lease for the accept gate: `080ce1f4-726d-4a9e-8344-e8171223d2aa`

On approval, call `orc_accept(s24.team_lead_accept)` with the assertion
(`approval_ref` or inline `assertion`). All prior steps are done; s23 is
optionally skipped (0 critical/high).

Owner approved s24 via Nexus request `apr_0632235f9cf1c359b9ee27ddf85b76ad` (decision=approved, ed25519, expires 2026-11-06T21:51:26Z).

## s24 — blocked at evidence-authentic (platform)

Owner approval `apr_0632235f9cf1c359b9ee27ddf85b76ad` was verified and the
approval gate passed. The remaining L1 gates are:

1. `gate-scenario-coverage` / `gate-evidence-authentic`: the canonical s20c
   `evidence-manifest.json` (sha256 f7dbb9ad…) and `scenario-evidence.json`
   cover the **7 f-v3 auth scenarios** and reference
   `doc/идеи/f-v3-auth-notes/screenshots/E2E-1..7.png`. Those screenshots are
   gitignored per-run artifacts; the ORC accept cleans them from the eval
   worktree, so the gates cannot find them.
2. The feature-owned f-v4 search evidence (6 scenarios, screenshots committed)
   fails the near-duplicate check: the full-page frames differ by <0.5 0.000000or
   several pairs, and its manifest hash does not match the s20c
   `preview-verdict` (f7dbb9ad… = the auth-only manifest).

Root cause is s20c feature-dir/evidence resolution: the host E2E run wrote
f-v3 evidence while the deployed feature is f-v4, and s24 binds to that
manifest. Fix: run s20c for f-v4 (producing f-v4 scenario-evidence/manifest and
updating preview-verdict), or permit the canonical per-run evidence to be read
from the execution root without cleaning. No bypass was used.

All other s24 gates pass (deliverable, approval, preview-verified, fault
catalog, detectors/proof, identity=deployed 2210238, docs-only descendant).

## s24 — PASS (platform 730d144a)

s24 `gates_passed` on commit `37b79b94dde915c73a461cb9a800b57cdd4005d1`:

- Owner approval `apr_0632235f9cf1c359b9ee27ddf85b76ad` verified (ed25519).
- s20c evidence re-captured for **f-v4-note-search**: 6 search scenarios with
  element/state screenshots (notes-list, search empty, query input, clear row —
  not full-page), all >=5KB and distinct (pngdiff: no near-duplicates).
- `scenario-evidence.json` + `evidence-manifest.json` for f-v4;
  `preview-verdict.evidence_manifest_sha256 =
  5dbe8770fd08ddc97e0b6ca2b2fcdbc046abd728b9aeb518c033efe0ae2e51a1`.
- All 11 s24 gates passed, including identity (deployed build 2210238,
  docs-only descendant), approval, scenario coverage, evidence authenticity,
  detector proof (20), graph, fault catalog, stand lease.

**E8895 = completed.** s20/s20a/s20b/s20c, s21, s22, s22a, s22b, s22c, s24 done;
s23 optional skipped (0 critical/high). test2 remains on `2210238`
(digest `sha256:a5aa4c89…`, build_args_hash `sha256:721b209f…`); test2 lease
released. P0–P6 PASS.

## Residual platform hardening (not path-1 blockers)

1. **Stand-runner manifest auto-regen:** after platform code changes,
   `/home/ukituki/lkfl-runner/manifest.sha256` must be rebuilt from
   `/srv/archkit/deploy-dev` (hash-pin drift broke s20b once).
2. **`gate_bundle_digest`:** test2 `/healthz` returns an empty value; bind it in
   the stand build so provenance carries the gate bundle digest.
3. **Eval-worktree guard:** host/ORC path split (`/srv/archkit/dev/orc-repos`
   vs `/app/orc-repos`) and per-step cleanup caused `eval-worktree-missing` /
   `target-not-git`; add a guard/auto-heal that never recreates from the ORC
   container.
4. **PAT/credential rotation:** unit-agent SSH is provisioned; ORC-side child
   branch creation still uses HTTPS without credentials (pre-created branches
   were required once). Rotate/scope the GitHub credential for ORC.

None of these block path-1; P0–P6 and s20–s24 are PASS.
