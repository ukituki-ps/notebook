# E1278 — s20a BLOCKER: clean branch vs active E2E invariant

- Date: 2026-11-09T13:51Z
- Process: `path-1.feature@4.0.0`, entry `integrate`
- Execution: `E1278` (paused at s20a)
- Session: `ses_e3f73c1a8ffeQzwhsgFuFByRxi`
- Work branch: `dev/f-v4-note-search-clean`
- Base SHA: `39d08e40dae262bff2a4ef6c1ff6b1fdd6634dc5`
- s20a artifact commit: `10fb3b044242d6e169a9c99c1d502ccf8f2e7806`
- `gate_bundle_digest`: `sha256:6e40186c4fe60222cb96e2a02fb136d93b3f266c4d9ff3208270421655adfb93`
- Eval worktree: `/app/orc-repos/f41f0adb-67d9-4ddf-8ba9-0efd9c6e50a9/.orc-eval/E1278/10fb3b044242d6e169a9c99c1d502ccf8f2e7806`
- test2 lease: `d23b925f-e16c-40ae-a4aa-57898fe2acbd` (active 13:48:04Z, released 13:50:41Z at STOP)
- E1868/E9275 were not resumed. No force/waiver/`na`/skip used. No SQL or container/DB patch.

## Result

`orc_accept(E1278, s20a.unit_integrate)` failed an L1 machine gate:

```
gate: invariant-enforced
checked: 20, failed: 1
INV-UI-E2E-PREVIEW  run: fail  exit_code: 2
reason: прогон завершился с ненулевым кодом
```

The declared invariant command is:

```
python3 tools/check-scenario-coverage.py \
  --brief doc/идеи/f-v4-note-search/scenarios.json \
  --evidence doc/идеи/f-v4-note-search/scenario-evidence.json
```

In the s20a eval worktree (`10fb3b0`) the evidence file is absent by design:

```
ls: doc/идеи/f-v4-note-search/scenario-evidence.json: No such file or directory
check-scenario-coverage: ERROR: [Errno 2] No such file or directory: '.../scenario-evidence.json'
```

Reproduction evidence: `PR-8b32f20595cd` (E1278).

## Root cause

`dev/f-v4-note-search-clean` @`39d08e4` removes E1868 per-run evidence
(`scenario-evidence.json`, `evidence-manifest.json`, `screenshots/`) from git and
gitignores it, so `check-run-artifacts` passes (required for s20b). But
`doc/идеи/f-v4-note-search/invariants.json` still marks
`INV-UI-E2E-PREVIEW` as `active` with:

- `test_ref` = a command that requires the now-untracked `scenario-evidence.json`, and
- `activation_evidence: "E1868 s20c: 30/30 E2E on test2 build 9c1763c; scenario-evidence 20/20; ..."`

The invariant cannot be satisfied at s20a on the clean branch:

1. tracking the evidence again makes `check-run-artifacts` fail at s20b
   (exactly the E9275 failure), and
2. leaving it untracked makes the active invariant's `test_ref` fail at s20a.

So the clean branch and the current active invariant model are mutually
inconsistent. This is not a deploy/E2E failure; s20b/s20c were not reached.

## What passed before the gate

| id | check | result |
|---|---|---|
| `PR-e725b8124733` | remote tip == `10fb3b0` + exact-tree `go build/vet/test` | pass (`ok ... 8.141s`) |
| `PR-e725b8124733` | per-run artifact scan of commit `10fb3b0` | none tracked |
| local | `check-tools-untouched` vs `39d08e4` | OK |
| local | `go test -count=1 ./...` | pass |

s20a gates passed 19/20 invariants; only `INV-UI-E2E-PREVIEW` failed.

## Environment note

`orc_start` initially failed with `HEAD==target` because a prunable ORC worktree
`/srv/archkit/dev/orc-repos/.../.clean-smoke` still held
`refs/heads/dev/f-v4-note-search-clean`. It was pruned with
`git worktree prune` (`PR-9b516c074b8d`); no branch or worktree content was
created, changed, or checked out. This was platform housekeeping, not a gate bypass.

## Recommended remediation (needs architect/product decision)

Reset the run-scoped activation for this clean run, e.g. one of:

1. mark `INV-UI-E2E-PREVIEW` `proposed` (remove the E1868 `activation_evidence`)
   until this execution's s20c proves it, or
2. change its `test_ref` to a check runnable at s20a (e.g. scenario/spec
   presence) and leave the E2E-pass enforcement to `gate-e2e-preview` at s20c, or
3. give `check-scenario-coverage.py` an execution-root fallback for per-run
   evidence (like the s20c gate already has).

Then resume paused `E1278` (re-lease test2) and continue s20a → s20b → s20c.
No force/waiver is required for options 1–3 if the model is corrected at the source.
