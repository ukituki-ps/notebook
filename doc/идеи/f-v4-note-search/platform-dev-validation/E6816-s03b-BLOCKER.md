# E6816 — BLOCKER at s03b: human approval gate binds prototypes/v6

- Execution: `E6816`, `path-1.feature@4.0.0`, work_branch `dev/f-v4-note-search-fix`
- Completed: s01, s02, s02a, s03 (+ 4 unit steps), s03a — all gates passed.
- Current: `s03b.prototype_accept` (not accepted).
- Date: 2026-11-08T20:56Z

## Evidence

The command gate `gate-prototype-accept` targets v7 and passes:

```
gate-prototype-accept: PASS — .../prototypes/v7/prototype-review.json (1 screens, verdict=approved)
```

The approval gate `gate-prototype-human-approval` in the frozen E6816 process has
**no target/profile** in `orc_ctx` (only `id/kind/layer/on_fail`). ORC resolves it to v6:

- gate payload digest: `sha256:625ab0048fe8948e0b14fc9d8ba9072f5e97db430d6a7904516fd58f54711e81`
- `sha256(prototypes/v6/prototype-review.json)` = exactly `625ab004…`
- approved v7 review blob = `sha256:1b570b8b4bcba7bb93eba955711fd8960a9fc3d3f6822fff7865793a34f521f4`

Signed cards obtained during the run:

- `apr_2faf314331cdbfcb0089f046ede1d22e` (approved) — payload `sha256:eb40fd6…`
  = raw sha of `prototypes/v7/prototype-review.json` **at `8add996`**, i.e. the
  earlier `changes_requested` blob (P-99 open), not the approved blob.
- `apr_7ea97b641ba579c67b7ce9a8bcae8cac` (pending, created after the approved
  revision) — Nexus still returned `eb40fd6…`, i.e. it read a stale project-root
  copy instead of the work_branch approved blob.

Result: no signed assertion matches the approved v7 blob, and the gate is bound
to v6. Approving v6 to make it pass is explicitly forbidden.

## Required platform fix

1. In the frozen `path-1.feature@4.0.0` canon, bind the human approval gate to the
   versioned review, e.g.:
   `target: '{context.feature_dir}/prototypes/{context.prototype_version}/prototype-review.json'`
   with `context.prototype_version = v7` (the current E6816 context already has
   `prototype_version: v7`, but the gate ignores it).
   Alternatively set it literally to `prototypes/v7/prototype-review.json` for this run.
2. Make `orc_human_request` read the artifact from the current `work_branch` HEAD
   (`9cbf320…`) rather than a stale project-root copy at `8add996…`.
3. Re-request approval for the exact approved v7 blob
   (`sha256:1b570b8b…`) and retry s03b.

No v6 approval, no waiver, no self-approval was used.

## Current state

Execution is paused at s03b to avoid retry/escalation. All artifacts up to
s03a are committed and pushed; the unit branch
`orc-exec-E6816-s03.proto_5fvisualize-u01` is complete.
