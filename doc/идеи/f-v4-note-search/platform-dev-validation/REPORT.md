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
  (project repo; NOT `/tmp/kilo/notebook-pdv`, not an HTTPS clone)

## Verdict

**P5 partially verified — blocked at s20b by a host-runner infrastructure
defect, not by path-1 code.**

- Unit commit + push over SSH: **PASS** (three unit branches pushed).
- `s11 → s18` for all three units: **PASS**, all gates green, no
  force/skip/waiver.
- `s20a.unit_integrate`: **PASS**, 11/11 gates after leasing `test2`
  (the `unit_batch` entry skips `s19`, so the L2 gate needs an explicit lease).
- `s20b.preview_deploy`: **routed to the host stand-runner and processed**
  (queue request/response present), but the runner **rejected the deploy** on
  its own hash-pin: `manifest-mismatch: deploy/ci/make-gate-bundle.py`.
- `s20c` E2E: **not reached**.
- `test2` remains on the previous build (`build_ref=406fa96`); no
  `preview-deploy.json` / deploy provenance was produced.

No gate was bypassed. The blocker is host-side provisioning/drift on `pr01`.

## What was validated

### Environment
- `ssh -T git@github.com` → `Hi ukituki-ps/notebook!`
- `origin` = `git@github.com:ukituki-ps/notebook.git`
- ORC host has **no docker** (`command -v docker` → none), as expected.

### Sessions (E8895)
| Unit | Child execution | Session |
|---|---|---|
| notebook-search-api | `E8895-…-u01` | `ses_e4d6a864dffepgOfSV1MMhaRS4` |
| notebook-search-ui | `E8895-…-u02` | `ses_e4d6a811effewnqV2rpCwg8I1J` |
| notebook-search-deploy-e2e | `E8895-…-u03` | `ses_e4d6a7b00ffegxb3upymIEckcX` |

3 distinct sessions, all different from the parent
`ses_e4de2edbeffePR726UuM1uWKKA`; sessions linked before step start; per-step
`step_start`/`attempt_allocated` carry the linked session.

### Unit commits (pushed)
| Unit | Tip | Notes |
|---|---|---|
| notebook-search-api | `bc215d97` | 32 tests, 8 search tests |
| notebook-search-ui | `5765aa6e` | TestUISemantics + search testids |
| notebook-search-deploy-e2e | `722e55ba` | 6 Playwright scenarios + UI graph |

Integration branch `dev/f-v4-note-search-ae079e5c`:
`734030dc` (api+ui) → `c84bafd` (e2e) → `1398f94f` (s20a report) →
`22102389` (s20b marker). `go build/vet/test` green at each merge.

### s20a
First accept failed `gate-l2-integration` because `unit_batch` skips
`s19.stand_lease`; after `nexus_stand_lease(test2, E8895)` the retry passed
**11/11 gates**.

### s20b (host stand-runner)
The official `tools/stand-runner-client.sh` was invoked from the ORC workspace
(no docker there). The request reached the shared queue and the host runner
responded:
1. `eval-worktree-missing` — the failed accept had removed
   `.orc-eval/E8895/22102389`. Recreating the worktree fixed the path.
2. `hash-pin: manifest-mismatch: deploy/ci/make-gate-bundle.py` — the host
   runner's CODE_ROOT does not match its `manifest.sha256`.

`/home/ukituki/lkfl-runner` and `/srv/archkit` are not visible from the ORC
container, so the manifest cannot be repaired from this environment.

## Unblock (on pr01, host runner)

```bash
cd /home/ukituki/lkfl-runner
find tools deploy -type f -print0 | sort -z | xargs -0 sha256sum > manifest.sha256
```

(or atomically redeploy runner code + manifest), then re-run:

```bash
STAND_RUNNER_PROJECT_ID=f41f0adb-67d9-4ddf-8ba9-0efd9c6e50a9 \
STAND_RUNNER_TRANSPORT=git \
STAND_RUNNER_COMMIT=<integrated-sha> \
tools/stand-runner-client.sh E8895 deploy-preview
```

and `orc_accept(s20b)`. After that, `s20c` Playwright/search E2E can run on the
deployed stand.

## Residual blockers

1. **Host-runner manifest drift (pr01, infra):** blocks s20b deploy and
   therefore s20c. Not path-1 code; not fixable from ORC or the unit agent.
2. **Test2 unchanged:** `build_ref=406fa96`; no new `image_digest`,
   `build_args_hash`, or deploy provenance.
3. **Stand lease:** `1ca22427-…` was used for s20a; released after the blocked
   run so test2 is not held.
4. **Execution state:** E8895 paused at `s20b.preview_deploy` (no gate bypass).

## Hygiene

- No platform code, `path-1`, Nexus, or deploy scripts modified.
- Only dev + test2 touched; no deploy/mutation of test2 occurred.
- No force/skip/waiver; the failed gate was left failing.
