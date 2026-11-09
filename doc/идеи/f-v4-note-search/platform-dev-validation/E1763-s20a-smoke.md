# E1763 — s20a smoke (clean v2, gate dry run)

- Date: 2026-11-09T14:15Z
- Process: `path-1.feature@4.0.0`, entry `integrate`
- Execution: `E1763` (new, from 0; E1278/E9275 not resumed)
- Session: `ses_e3f5afc22ffeikTMEL7HsMXque`
- Work branch: `dev/f-v4-note-search-clean-v2`
- Base SHA / gate base ref: `f5e1b4182726c0ca997456c320aacf69b8cdb5e3`
- `gate_bundle_digest`: `sha256:755214cf300e0e00ed2559041a59f17b5d89cd3f011073cd5a41c58481841347`
- Evidence root: `/app/orc-repos/f41f0adb-67d9-4ddf-8ba9-0efd9c6e50a9/.orc-eval/E1763`
- test2 lease: `efe7125f-93d0-49c5-88ff-68ae23684997`, active until `2026-11-09T16:12:27Z`

## Purpose

Clean run of the s20a → s20c smoke on `dev/f-v4-note-search-clean-v2`.
The previous clean branch failed s20a because `INV-UI-E2E-PREVIEW` was
`active` and its `test_ref` required per-run evidence that is intentionally
untracked. On `f5e1b418` the invariant is `proposed`, so s20a does not require
its `test_ref`, while `check-run-artifacts` still passes.

## Gate dry run (s20a)

`orc_gate_dry_run` is not exposed; dry run used `orc_proof_run` on the evaluated
commit plus local gate commands (not a blocker).

| id | command | result |
|---|---|---|
| `PR-b90c03d2e0f0` | remote tip `== f5e1b418`, tracked per-run artifact scan, `go build/vet/test` on `git archive f5e1b418` | pass (`ok ... 8.208s`) |
| `PR-9f1a5b5886f3` | all 19 `active` invariant `test_ref`s on the archived tree | pass (19/19) |
| local | `bash tools/check-run-artifacts.sh .` | OK |
| local | `GATE_BASE_REF=f5e1b418… bash tools/check-tools-untouched.sh .` | OK (tools/deploy/.orc-trust unchanged) |
| local | `bash tools/gate-l1-unit.sh` | PASS |
| local | `bash tools/path1-gate.sh ds-usage E1763` | PASS |
| local | `ORC_BASE_SHA=f5e1b418… bash tools/check-integration-on-stand.sh E1763` | PASS-NA (no changed Go; docs-only) |

`INV-UI-E2E-PREVIEW` stays `proposed` and is not executed at s20a
(`require_test_ref_for: active`). It must remain `proposed` until s20c.

## Guardrails

- New execution only; `E1278`, `E9275` and `E1868` were not resumed.
- No force, waiver, `na`, or step skip; no SQL; no container/DB patch.
- `main`, prod and test1 untouched; test2 is the only leased stand.
- `gate_bundle_digest` above is the execution bundle digest and is not
  substituted with `gate_tools_digest` (verified separately in the
  verification manifest).
- ORC creates its own eval worktree; no manual `git worktree add`.
- A stale prunable ORC worktree registration `.clean-invariant` (branch
  `dev/f-v4-note-search-clean-v2`, path `/srv/archkit/...` non-existent) was
  removed with `git worktree prune` (`PR-44d05f28c359`); this is platform
  housekeeping on the base clone, not a gate change.

## Next

s20b preview deploy on test2, then s20c E2E on test2. Stop after s20c;
`s24` is not started.
