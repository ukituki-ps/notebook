# E1488 — s24 acceptance BLOCKED by gate-evidence-authentic (api-mode E2E)

- Execution: `E1488`; step `s24.team_lead_accept`; branch `dev/f-v4-note-search-ae079e5c`.
- Human approval: request `apr_645aff96d280fc319c9faac64e0602dc` — **approved**, waited 4s, signed `nexus.approval/v1` (`.orc-approvals/apr_645aff96d280fc319c9faac64e0602dc.json`).
- s24 auto-gates: **10 / 11 pass**. Failing: `gate-evidence-authentic`.

## Exact failure

```
gate-evidence-authentic: scenario-evidence OK (6 сценариев, уникальные скриншоты)
gate-evidence-authentic: evidence-manifest OK (6 файлов)
gate-evidence-authentic: FAIL — evidence-manifest.json изменён после s20c (sha не совпадает с preview-verdict)
gate-evidence-authentic: FAIL — 1 проверок не прошло
```

- `preview-verdict.evidence_manifest_sha256` = `sha256:9fd03ffa…` (varies per run)
- `sha256(doc/идеи/f-v4-note-search/evidence-manifest.json)` = `5dbe8770fd08ddc97e0b6ca2b2fcdbc046abd728b9aeb518c033efe0ae2e51a1`

## Root cause

1. `run-stand-e2e.sh` selects `mode=api` because `_feature_dir.py --name scenarios.json`
   on the runner host is **ambiguous**: both `f-v3-auth-notes/scenarios.json` and
   `f-v4-note-search/scenarios.json` are changed relative to `origin/main` (ff9b8e1),
   so `FEAT_DIR_ABS`/`scen_path` are empty.
2. In api mode the runner computes `ART_SHA = sha256(e2e stdout)` and calls
   `verdict verified "$ART_SHA"`, so `preview-verdict.evidence_manifest_sha256`
   is a **run-artifact digest**, not the feature manifest sha.
3. `check-evidence-authentic.sh` §2b compares that value to
   `sha256(<feature>/evidence-manifest.json)` → never equal in api mode.
4. ui mode is the only path that writes `evidence-manifest.json` and anchors its
   `MANIFEST_SHA` — but it is unreachable: the pinned stand-runner client/runner
   have no feature-field, and the host `_feature_dir.py` cannot disambiguate two
   features with `scenarios.json`.

This is a platform regression for multi-feature repos / api-mode E2E; it is not
caused by the feature code (deploy, E2E 15/15, canary 3/3, reviews all green).

## Not bypassed

No `force`, skip, waiver, or forged evidence. The human approval is genuine
(Telegram signed assertion). The report bytes bound to the approval are unchanged.

## Suggested fix

- Give the stand-runner the execution feature (`ORC_FEATURE_ID`/`ORC_FEATURE_DIR`)
  so `run-stand-e2e.sh` selects ui mode and anchors `MANIFEST_SHA`; or
- Resolve `_feature_dir.py` by `work_branch`/execution feature for multi-feature
  repos; or
- Make the api-mode verdict anchor the feature `evidence-manifest.json` sha.

## State

`s24.team_lead_accept` remains `running` with a failed accept; E1488 not completed.
The stand lease is released.
