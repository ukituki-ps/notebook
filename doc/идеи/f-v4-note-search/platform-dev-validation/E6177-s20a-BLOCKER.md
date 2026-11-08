# E6177 — BLOCKER at s20a: gate-tools-untouched base is origin/main, not execution base

- Execution: `E6177`, `path-1.feature@4.0.0` (entry prototype), branch `dev/f-v4-note-search-fix`
- Completed: s03b (signed v7), s04–s19, s20 fan-out (3 units, all 10 steps each), merges
- Current: `s20a.unit_integrate` (11/12 gates pass; 1 fails)
- Date: 2026-11-08T21:29Z

## Exact failure

```
gate-tools-untouched: FAIL — allowlist_missing: .orc-trust/tools-allowlist.yaml @ ff9b8e1f6841200246c151f4758bd801f147409d
```

- `GATE_BASE_REF` was resolved to `ff9b8e1f…` = `origin/main`.
- Expected base: execution base `74d6cec9db4990fb94f3fbf4a021acbeb6a32615`.
- Since `origin/main`, the feature branch *adds* the whole `tools/` tree
  (bootstrap commit `e6aeb44`), including `tools/check-tools-untouched.sh`.
- The gate hard-denylists `tools/check-tools-untouched.sh` and `.orc-trust/**`:
  no allowlist can cover an added copy, so `tools-allowlist.yaml` cannot fix it.
- Relative to the execution base `74d6cec`, `tools/` is **unchanged**
  (`git diff --stat 74d6cec..HEAD -- tools/` is empty), so the gate would PASS
  with the correct base.

## Attempts (non-bypass)

- `orc_set_context` with `context.gate_base_ref=74d6cec…` → ignored by the
  frozen step env (still `ff9b8e1`).
- `orc_set_context` with `context.gate={"base_ref":"74d6cec…"}` → ignored.
- No allowlist/waiver/force was used.

## Required platform fix

For `E6177` / `s20a.unit_integrate`, inject the typed gate base:
`GATE_BASE_REF=74d6cec9db4990fb94f3fbf4a021acbeb6a32615` (or fix the typed
`gate.base_ref` resolution so `context.gate.base_ref` is honoured), then retry
s20a. With the execution base, `tools/` has no diff and the gate passes.

Also note: `gate-ds-usage` was failing before this because `ui-audit.json` was
still 1.0.0; it is now re-certified to DS 1.0.1 and PASSes locally.

## State

- s20a is running with 11/12 gates green; no step was accepted.
- Search API smoke missing in `deploy/path1/e2e-preview.sh` was found and fixed
  on the u03 branch (q, 512 accepted, 513 -> 400), merged into the parent.
- Execution should be paused at s20a.
