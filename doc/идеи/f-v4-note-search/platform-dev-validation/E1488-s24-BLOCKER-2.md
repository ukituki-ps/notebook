# E1488 — s24 BLOCKER #2: host stand-runner not on f6a5fcf1 (no feature scoping)

- Platform (ORC container): `f6a5fcf1`; `ORC_GATE_BUNDLE_DIGEST=sha256:263c48a44e1abaaedb7378066cfe7fc831faade7bb5dc3418756a4eed15bf1e8` ✅
- Context re-pinned: `gate_bundle_digest=sha256:263c48a4…` ✅
- Evidence fix committed: `033886b` (per-scenario colored banner → screenshots distinguishable) ✅
- Stand `test2` re-leased ✅

## New-bundle deploy WORKS (manual queue request, no feature keys)

`preview-deploy.json` / `/healthz`:
```
ref=033886b
commit=033886bc47f0515b5a52368d4e84a2d42846cd80
image_digest=sha256:265c12f9232d1007e3cd62e11c9a2406e8ea2a148571ed7e09a807e9661e1e58
build_args_hash=sha256:6cf07ce4f3b87a59597639b62ad0c891af9baecf366ef9d667362335502cc982
gate_bundle_digest=sha256:263c48a44e1abaaedb7378066cfe7fc831faade7bb5dc3418756a4eed15bf1e8
```
Queue result: `{"rc":0,"reason":"ok"}` (6 s).

## BLOCKER: UI mode is unreachable — host runner is stale

The pinned client (`/opt/gate-tools/tools/stand-runner-client.sh`, f6a5fcf1) adds
`feature_dir`/`feature_id` to the request; the **host** stand-runner rejects them:

- with `feature_dir` + `feature_id`: `stand-runner: reject: request-fields-invalid`
- with `feature_id` only (ASCII): **also** `request-fields-invalid`
- manual request with `gate_bundle_digest` only (no feature keys): accepted, deploys OK

So the host runner is the **pre-f6a5fcf1** build: it accepts `gate_bundle_digest`
but not the feature keys. Consequently `run-stand-e2e.sh` runs `mode=api`
(`_feature_dir.py --name scenarios.json` is `ambiguous`: f-v3 + f-v4 both changed),
never `mode=ui`, so `preview-verdict.evidence_manifest_sha256` becomes
`sha256(e2e stdout)` (a run digest), not the feature manifest sha.

That makes `gate-evidence-authentic` fail at s24 (§2b) exactly as before:
```
gate-evidence-authentic: FAIL — evidence-manifest.json изменён после s20c (sha не совпадает с preview-verdict)
```

## step_reopen is also blocked

`orc_step_reopen(E1488, s20b.preview_deploy)`:
- `downstream step "s22.result_audit" is done; reopen is unsafe`
- `downstream step "s22b.red_team_audit" is done; reopen is unsafe`
- `downstream step "s21.graph_actualize" is done; reopen is unsafe`
- reopening `s24` returns applied but keeps it `running`; retries hit `cas_conflict` (last_seq drifts).

So the operator-specified `step_reopen s20b → run s20b…s24` cannot be executed on
this platform state.

## Requested fix

1. Update/restart the **host** stand-runner to `f6a5fcf1` so it accepts
   `feature_dir`/`feature_id` → `run-stand-e2e.sh` selects `mode=ui` and anchors
   `MANIFEST_SHA` (then the committed evidence can match).
2. Allow `step_reopen` cascade (or reset E1488 to s20b) with explicit downstream
   invalidation; the current done/running guard + CAS drift blocks it.

No force/skip/waiver used. Stand lease released.
