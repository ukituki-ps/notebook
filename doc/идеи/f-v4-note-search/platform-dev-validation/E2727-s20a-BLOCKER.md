# E2727 — deployed gate still runs the old tools-untouched (no fallback)

- Date: 2026-11-09T08:21Z
- Process: `path-1.feature@4.0.0`, entry `integrate`
- Dev deploy claimed: `905993c2`, gate bundle `sha256:8fe63252…`,
  base process `0a82fd1` (clone_head shows `0a82fd1b…`)
- Branch: `dev/f-v4-note-search-fix` @ `95127c7`

## Result: s20a 11/12, same failure

```
gate-tools-untouched: FAIL — allowlist_missing:
.orc-trust/tools-allowlist.yaml @ ff9b8e1f6841200246c151f4758bd801f147409d
```

`ff9b8e1f` is `origin/main` again. With execution base `9b972e6`
(fallback target) or `74d6cec`, `git diff .. HEAD -- tools/` is empty.

## Two independent facts prove the fix is not in the executed gate

1. **Context still drops `gate_base_ref`.**
   `E2727` was created with `context.gate_base_ref=74d6cec…`; `orc_status.context`
   contains no `gate_base_ref` (and no `gate`/`params`). So the process mapping
   `{context.gate_base_ref}` resolves to empty, and the gate gets no
   `GATE_BASE_REF`.

2. **The executed gate tool is unchanged.**
   `gate-tools-untouched` output hash is **`sha256:0b7dc912fdef9b7aecb5165e8e28f694e253d088ecc84a8392a68da7302bc18f`**
   in E6177, E6284, and E2727 — before and after deploy `905993c2`.
   The executed command is `/opt/gate-tools/tools/check-tools-untouched.sh`
   (pinned bundle), not the repo copy. The repo copy has an
   `ORC_BASE_SHA`/`.orc-eval-base-sha` fallback; the executed copy evidently
   does not (otherwise the fallback to `9b972e6` would have fired).

In `details`, `gate_tools_digest=sha256:8fe63252…` matches the new bundle, but the
tool output is byte-identical to the old one — i.e. the bundle digest changed
without the tools-untouched implementation changing.

## Required fix

1. Preserve/inject the typed gate base:
   - whitelist `gate_base_ref` in creation context (do not drop unknown keys), or
   - set `GATE_BASE_REF=9b972e6` (execution base) directly in the step env.
2. Ensure the **executed** `/opt/gate-tools/tools/check-tools-untouched.sh`
   contains the execution-base fallback and is actually in bundle `8fe63252`.
   The unchanged output hash `0b7dc9…` is the proof it is not.

After that, a new `integrate` execution should pass s20a without allowlist.

## State

- E2727: paused at s20a, no accepts.
- E6469: cancelled. E6284: paused. E6177: paused (not resumed).
- test2 lease `f2f58b83…`: released; stand free.
- Branch artifacts up to s20a (incl. search smoke fix, ui-audit DS 1.0.1,
  s20a report) are committed and pushed at `95127c7` (blocker doc commit follows).
