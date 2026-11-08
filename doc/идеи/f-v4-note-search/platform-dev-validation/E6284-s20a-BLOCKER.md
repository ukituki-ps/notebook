# E6284 — gate_base_ref is dropped at execution creation (platform)

- Date: 2026-11-08T21:48Z
- Process: `path-1.feature@4.0.0`, entry `integrate`, base process f0f2f0e,
  gate bundle `sha256:b6ae9333…`, dev-ORC 8390.
- Branch: `dev/f-v4-note-search-fix` @ `6090550` (pushed).

## Exact failure (s20a, 11/12 gates pass)

```
gate-tools-untouched: FAIL — allowlist_missing:
.orc-trust/tools-allowlist.yaml @ ff9b8e1f6841200246c151f4758bd801f147409d
```

`ff9b8e1f` is `origin/main`; the gate therefore takes the fallback base and
sees `tools/` as newly added, hitting the hard denylist. With the execution
base `74d6cec`, `git diff 74d6cec..HEAD -- tools/` is empty.

## Root cause: context key is filtered at creation

The gate mapping is `{context.gate_base_ref}`, but ORC does not preserve the key.

1. `E6469` created with `context.gate_base_ref=74d6cec…` → status context shows
   **no** `gate_base_ref`; gate env is empty → `origin/main` → FAIL.
2. `orc_set_context` added `gate_base_ref` and `gate.base_ref`; `orc_step_reopen`
   restored the creation snapshot and **removed them again**.
3. `E6284` created with all three forms at creation:
   `gate_base_ref`, `gate={"base_ref":…}`, `params={"gate_base_ref":…}`.
   Status context still contains **none of them**; only required keys survive.

Therefore `context.gate_base_ref` is always empty at gate time and the new
`base_ref = {context.gate_base_ref}` mapping cannot work.

## Required platform fix (one of)

1. Preserve `gate_base_ref` / `gate.base_ref` in the execution context
   (add it to `required_context` for entry `integrate`, or whitelist the typed
   key so unknown-key filtering does not drop it), **or**
2. Make `gate-tools-untouched.base_ref` fall back to `context.base_sha`
   (`8ae7b39`/`74d6cec` in this execution) when `context.gate_base_ref` is absent.

Then create the integrate execution again; s20a should pass with no allowlist.

## State

- E6469: cancelled (gate context dropped).
- E6284: paused at s20a, no accepts.
- test2 lease: released; stand is free (re-lease on the working execution).
- s01–s20 (E6177) and s20a artifacts/fixes are on the branch and pushed.
