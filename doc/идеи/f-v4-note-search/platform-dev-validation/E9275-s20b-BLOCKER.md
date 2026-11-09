# E9275 — s20b gate BLOCKER (check-run-artifacts)

- Date: 2026-11-09T13:37Z
- Process: `path-1.feature@4.0.0`, entry `integrate`
- Dev ORC: `7d155eee`; gate bundle: `sha256:6e40186c4fe60222cb96e2a02fb136d93b3f266c4d9ff3208270421655adfb93`
- Execution: `E9275` (paused after this failure)
- Work branch: `dev/f-v4-note-search-smoke`
- s20a commit: `38d95df6ba6ae5286d56ee792e2130f1de37a597`
- Eval root: `/app/orc-repos/f41f0adb-67d9-4ddf-8ba9-0efd9c6e50a9/.orc-eval/E9275`
- Gate workdir: `.../.orc-eval/E9275/6620dcb81dce67523a453226f09c75d8ef5d9653`
- test2 lease `8b768200-b026-4930-a56a-a4aece4427e0` was active for the deploy and released after the stop.

## What passed

- Preview deploy executed through the host-runner queue; no manual `git worktree add`.
- Stand: `test2`, image `sha256:09ec3092833f161b566de78b76762137abf3ab7200a33c30fba2719421cd2efc`,
  build args `sha256:93523b589fd293b0ee0ad58f47b6e5b90095ecfec3bb04fc9db6da269b2e9b96`.
- `/healthz`: `status=ok`, `commit=38d95df`, `gate_bundle_digest=sha256:6e40186c…`.
- `preview-deploy.json` written to the execution root and carried the same bundle digest.
- `gate-tools-untouched`: OK (tools/deploy/.orc-trust unchanged vs `6620dcb`).

## What failed

`s20b.preview_deploy` / `gate-preview-deploy` → `check-run-artifacts`:

```
check-run-artifacts: FAIL — per-run артефакты в git (их не должно быть в истории):
  doc/идеи/f-v4-note-search/evidence-manifest.json
  doc/идеи/f-v4-note-search/scenario-evidence.json
  doc/идеи/f-v4-note-search/screenshots/*.png
```

These files were committed earlier on the feature branch (E1868) and are present
in history. The gate treats any per-run artifact in git history as a failure
(F-RUN-02/E7141). The failure is not caused by the deploy or by eval-worktree
recovery.

- Gate log: `/app/data/evidence/gate-logs/82c1c6adbb8b72ad-gate-gate-preview-deploy.log`
- Gate log sha256: `sha256:b1dc03064731347865ec747fb5e425492150a67572ff4540d4ac56df277bdab2`

## Stop state

- s20c was not started.
- s22b/s24 were not started.
- No force, waiver, `na`, skip, SQL, container patch, or database operation.
- test2 lease released: `2026-11-09T13:36:55Z`.
- E9275 is paused; E1868 was not resumed.
