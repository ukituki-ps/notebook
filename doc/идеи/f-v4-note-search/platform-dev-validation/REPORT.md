# Platform validation — f-v4-note-search / P5 retest (ae079e5c)

- Date: 2026-11-06 (UTC)
- Platform under test: `ae079e5cadd9398d29457d31213757ae67bdd52d`
  (Nexus `/healthz` commit and ORC `/version` revision match)
- Contour: dev + `test2` only. Prod/preprod/test1 untouched.
- Project: `f41f0adb-67d9-4ddf-8ba9-0efd9c6e50a9`
- Execution: **E8895** (fresh; `path-1.feature@3.2.2`, entry `unit_batch`)
- `execution_transport=git`
- `context.work_branch=dev/f-v4-note-search-ae079e5c`
- `context.target_repo_head=326ae62fce7d6513c2b389750b4f5ebed278d861`
- Worktrees: `/workspace/projects/notebook-ae079e5c[-u01..u03]`
  (project repo; not `/tmp/kilo/notebook-pdv`, not an HTTPS clone)

## Verdict

**PASS.** All unit work landed through the git transport, `s20a → s20b → s20c`
passed with real gates, and test2 is deployed on `2210238` with matching
provenance and a 13/13 Playwright E2E.

## Results

| Stage | Result |
|---|---|
| SSH / origin | `ssh -T git@github.com` → `Hi ukituki-ps/notebook!`; origin = `git@github.com:ukituki-ps/notebook.git` |
| Fresh execution | **E8895** with `execution_transport=git`, work branch + target head as above |
| Sessions | 3 distinct (`ses_e4d6a864…`, `ses_e4d6a811…`, `ses_e4d6a7b0…`), parent distinct; linked before steps |
| Unit push | `bc215d97` (api), `5765aa6e` (ui), `722e55ba` (e2e) — pushed over SSH |
| `s11 → s18` | all three units done; `s17`/`s18` gates passed; no force/skip/waiver |
| `s20a` | 11/11 gates passed after leasing test2 (unit_batch skips s19) |
| `s20b` | **gates_passed** — host stand-runner deploy GREEN |
| `s20c` | **gates_passed** — host stand-runner E2E 13/13 |

## Integration branch

`dev/f-v4-note-search-ae079e5c`:
`734030dc` (api+ui) → `c84bafd` (e2e) → `1398f94f` (s20a report) →
`22102389` (s20b marker) → validation reports.
`go build/vet/test` green at each merge (32 tests).

## s20b deploy evidence

- Runner: `deploy-preview` via `tools/stand-runner-client.sh` (queue
  `/app/orc-repos/.deploy-queue`); `client_rc=0`, `res.json rc=0`, 25s.
- Image: `notebook-stand:test2-2210238`
- `image_digest`: `sha256:a5aa4c8947b321e42604fd829a81c2a17ca37efefc86d6d254ec0b4147ead604`
- `build_args_hash`: `sha256:721b209f71e806fc8b7e9f2edbb1fcf8b30be18e7ed023e442bff13f958fe877`
- `gate_bundle_digest`: `""` (not set for this stand build)
- test2 `/healthz`: `build_ref=2210238`, `commit=22102389c6f02e7fc518dc958a32542ec5c3d9f1`,
  digest/args hash match the deploy.
- `preview-deploy.json` synced (sha256:8b02c3a7…).
- Provenance at `.orc-eval/E8895/2210238…/deploy/stands/.runtime/test2/`:
  `build-provenance.json` (built_at 21:00:30Z) and `deploy-provenance.json`
  (deployed_at 21:00:39Z), same commit/digest; plus `dsn`, `nginx.conf`.

## s20c E2E evidence

- Host stand-runner `e2e-preview` for E8895: queue `state=done`, `rc=0`,
  `duration_s=10`.
- `preview-verdict.json`: `result=pass`, `status=verified`, `mode=ui`,
  `ref=2210238`, `evaluated_sha=22102389…`, target/url =
  `https://test2.nexus.ukituki.tech`, image digest / build args hash match the
  deploy, `evidence_manifest_sha256=f7dbb9ad…`.
- Playwright: **13/13** (7 auth-notes + 6 search, `SEARCH-E2E-1..6`).
- Evidence: `.orc-eval/E8895/22102389…/doc/идеи/f-v3-auth-notes/`
  `scenario-evidence.json` + `evidence-manifest.json` + screenshots.
- `orc_accept(s20c)` → **gates_passed**; run artifacts `preview-deploy.json`
  and `preview-verdict.json` synced.

## State

- E8895: `s20a`, `s20b`, `s20c` = done; next step `s21` pending.
- test2 lease `79ae80d9-f521-4da0-a430-b611f662d2c5` released after accept.
- test2 remains on `2210238` (the deployed feature build).

## Hygiene

- No platform code, `path-1`, Nexus, or deploy scripts modified.
- Only dev + test2 touched; prod/preprod/test1 untouched.
- No force/skip/waiver; the earlier host-runner hash-pin and eval-worktree
  issues were fixed on pr01, not bypassed.
