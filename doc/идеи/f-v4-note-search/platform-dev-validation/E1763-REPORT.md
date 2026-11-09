# E1763 — clean smoke s20a → s20c (FINAL, stopped at s20c)

- Date: 2026-11-09T14:21Z
- Platform dev: Nexus/ORC `49ec7ced`; ORC gate bundle `sha256:755214cf300e0e00ed2559041a59f17b5d89cd3f011073cd5a41c58481841347`
- Process: `path-1.feature@4.0.0`, entry `integrate` (`orc_start_from=s20a.unit_integrate`)
- Execution: **E1763** (new, from 0; `E1278` / `E9275` not resumed; `E1868` archived, not current)
- Session: `ses_e3f5afc22ffeikTMEL7HsMXque`
- Work branch: `dev/f-v4-note-search-clean-v2`
- Base SHA / gate base ref: `f5e1b4182726c0ca997456c320aacf69b8cdb5e3`
- Eval root: `/app/orc-repos/f41f0adb-67d9-4ddf-8ba9-0efd9c6e50a9/.orc-eval/E1763`
- Execution status: **paused at s20c** (s21 allocated, not started; s22+ and s24 not run)

## Step status

| step | status | commit evaluated | notes |
|---|---|---|---|
| s20a.unit_integrate | **done / gates_passed** | `2412e70` | invariants 19/19 active; `INV-UI-E2E-PREVIEW` proposed |
| s20b.preview_deploy | **done / gates_passed** | `b922315` | test2 build `2412e70`, image `sha256:4a5303b4…` |
| s20c.preview_verify | **done / gates_passed** (gate = PASS-NA) | `b83b0fa` | E2E 30/30, scenario-evidence 20/20 |

Branch tip: `b83b0fa0d232eb01e4615ca4bd5218c86248f232`.

## Test stand

- Stand: `test2` (`https://test2.nexus.ukituki.tech`), only stand used.
- Lease: `efe7125f-93d0-49c5-88ff-68ae23684997`, active `14:12:27Z → 16:12:27Z`,
  **released at STOP 14:21:09Z**. `test1`, prod and main were not touched.

## s20a

- `orc_gate_dry_run` is not exposed; dry run used `orc_proof_run` on the evaluated commit:
  remote tip `f5e1b418`, tracked per-run artifact scan, `go build/vet/test`
  (`PR-b90c03d2e0f0`), and all 19 `active` invariant `test_ref`s (`PR-9f1a5b5886f3`, 19/19).
- Local: `check-run-artifacts` OK, `check-tools-untouched` OK (vs `f5e1b418`),
  `gate-l1-unit` PASS, `ds-usage` PASS, `gate-l2-integration` PASS-NA (docs-only).
- `INV-UI-E2E-PREVIEW` stayed `proposed`; its `test_ref` was not required at s20a.

## s20b

- Host stand-runner `deploy-preview` rc=0 (`PR-97acbfa145ee`):
  `notebook-stand:test2-2412e70`, digest `sha256:4a5303b4ab403f82f9c5780723e13b99a90c2642bd8d3c99079372e59605fc9a`,
  build args hash `sha256:eb27c613…`, url `https://test2.nexus.ukituki.tech`.
- `preview-deploy.json` at execution root `.orc-eval/E1763/`; provenance and `/healthz`
  checked (`PR-5dcdbfd24d6f`); `check-run-artifacts` OK.
- No manual `git worktree add`; ORC/host-runner resolved the eval worktree.

## s20c

- Host stand-runner `e2e-preview` rc=0 (`PR-1bbc53171367`):
  Playwright chromium **30/30 passed** (30.4 s); `scenario-evidence.json` **20/20 pass**
  with screenshots; `evidence-manifest.json` 24 files,
  `sha256:4f551e5cf54d93912dfa7bafb489ad70f8d6ae81f8d3ffa85835e3f56ab95466`.
- `preview-verdict.json`: `pass/verified/ui`, `ref=2412e70`,
  `evaluated_sha=2412e7030fe364f21e3510d7896d685306b76978`; provenance matches
  `preview-deploy.json` and `/healthz`; manifest digest matches `artifact_digest`
  (`PR-5b090d806cf6`).
- Evidence materialized in the **execution root** (not tracked in git):
  `.orc-eval/E1763/doc/идеи/f-v4-note-search/{scenario-evidence.json,evidence-manifest.json,screenshots/}`.
- `INV-UI-E2E-PREVIEW` remained `proposed` in the evaluated tree.
- ORC accepted s20c with `gate_status=gates_passed`; the pinned gate
  `gate-e2e-preview` itself returned **PASS-NA**: the increment is docs-only and has no
  UI-surface change vs `f5e1b418` (reproduced: `PR-2fdf5d9164a9`). The E2E evidence was
  therefore verified independently (`PR-5b090d806cf6`), not by the gate.

## Checklist

| check | result |
|---|---|
| `check-run-artifacts` PASS | PASS (branch tip and eval worktrees) |
| `INV-UI-E2E-PREVIEW` proposed until s20c | PASS (still `proposed`) |
| s20b/s20c without manual `git worktree add` | PASS |
| test2 lease active for s20b/s20c | PASS (released at STOP) |
| scenario-evidence materialized from execution root | PASS |
| E1868 evidence not in git | PASS (`scenario-evidence`/`evidence-manifest`/`screenshots` untracked) |
| gate bundle vs gate tools digest not mixed | **observation** — ORC reports both `sha256:755214cf…` (identical) in every E1763 manifest; no operator substitution was made, but independence cannot be confirmed |
| no force / waiver / `na` override / SQL / container-DB patch | PASS for operator actions; **note** s20c gate emitted PASS-NA (platform conditional, see below) |
| main / prod / test1 untouched | PASS |

## Blockers / residuals

1. **s20c gate is PASS-NA, not a strict evidence check.** Because the execution base
   already contains the feature and this run adds only docs, `ui_surface` reports no UI
   delta, so `gate-e2e-preview` returns PASS-NA before validating `scenario-evidence`.
   The real E2E was run and passed, but if "no NA" is a hard acceptance criterion, this
   run does not satisfy it and needs a platform/increment change (not a run-time fix).
2. **`gate_tools_digest == gate_bundle_digest`** (`sha256:755214cf…`) in ORC verification
   manifests on platform `49ec7ced`; distinct values could not be observed.
3. **Verify-only commit binding**: ORC rejects the deployed commit for s20b/s20c
   (`commit_bound_to_other_step`), so per-step docs commits `b922315` / `b83b0fa` were
   used. Gate/docs-only tolerance accepted them.
4. **E2E local-mode auto-detection**: `run-stand-e2e.sh` runs locally when `npx` exists
   even if no browser binary is installed; the first attempt failed with
   `browserType.launch: Executable doesn't exist` (`PR-ee5955b32f3c`). The same commit
   passed via the intended host-runner queue. Recommend an explicit host-runner flag or
   a browser-presence probe.
5. **Start preconditions**: `orc_start` required `gate_base_ref` at start (passed as
   `base_sha`), despite the missing-context hint saying not to pass it.
6. **Platform housekeeping (not a gate change)**: a stale prunable ORC worktree
   `.clean-invariant` still held `dev/f-v4-note-search-clean-v2`; it was removed with
   `git worktree prune` (`PR-44d05f28c359`), inspected via `PR-f45c982d9c92`. These
   read-only/housekeeping proof runs were recorded under paused `E9275`; it was not
   resumed.

## Stop

Execution `E1763` is paused at s20c. `s21` was allocated but not started; `s24` was not
run. Next run, if needed, must be a new execution from 0.
