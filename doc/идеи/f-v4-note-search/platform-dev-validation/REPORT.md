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
