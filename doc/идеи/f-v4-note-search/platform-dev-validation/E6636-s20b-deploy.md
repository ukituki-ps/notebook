# E6636 — s20b preview deploy (test2)

- Date: 2026-11-10T11:06Z
- Execution: `E6636`, step `s20b.preview_deploy` (role `orc`)
- Branch: `dev/path10-runner-13`
- Deployed commit / evaluated sha: `6503f66117f74cd012205543fd7405e56708ef6c` (`6503f66`)
- Base: `9e7fae353c61e717505dc40019627a1d7ab48820`
- Stand: `test2` — https://test2.nexus.ukituki.tech (leased stand of E6636)
- Transport: `git` (image built from `.orc-eval/E6636/6503f66`)
- Image tag: `notebook-stand:test2-6503f66`
- Image digest: `sha256:c7d0ae7203a281411f6f96c61feb52c1bb545840fdf2c790c828cbea1184c626`
- `build_args_hash`: `sha256:8c29b443e5345174a45c1888c9ae91f0ff6b37621fe07ce56932d7d8fa93610a`
- `gate_bundle_digest`: `sha256:042082ac96b6f5f705919f851425d618a73e99710bcb573a13397e65d95aca2d`
- Provenance: `.orc-eval/E6636/preview-deploy.json` (schema `orc.preview-deploy/v1`)
- Stand DSN ref: `.orc-eval/E6636/test2.dsn` (runtime only, untracked)

## Deploy

`tools/deploy-preview-stand.sh E6636` via the host-runner bridge
(`tools/stand-runner-client.sh` queue) — ORC container has no docker:
docker build from the eval worktree at `6503f66`, export, retag, stand restart;
result `preview-deploy: GREEN test2 on notebook-stand:test2-6503f66`.

## Health

`GET https://test2.nexus.ukituki.tech/healthz` → 200:

```json
{"status":"ok","build_ref":"6503f66","commit":"6503f66117f74cd012205543fd7405e56708ef6c",
 "image_digest":"sha256:c7d0ae7203a281411f6f96c61feb52c1bb545840fdf2c790c828cbea1184c626",
 "build_args_hash":"sha256:8c29b443e5345174a45c1888c9ae91f0ff6b37621fe07ce56932d7d8fa93610a",
 "gate_bundle_digest":"sha256:042082ac96b6f5f705919f851425d618a73e99710bcb573a13397e65d95aca2d"}
```

`build_ref`, `commit`, `image_digest`, `build_args_hash` and
`gate_bundle_digest` all equal the deploy provenance — the preview answers from
this execution's build, not a retagged or foreign image.

## Next

`s20c.preview_verify`: Playwright `web/e2e/notes-search.spec.js` (20 scenarios
SEARCH-E2E-1..20 + CR-01..CR-03) on this deployed build, `scenario-evidence.json`
20/20 with screenshot / sha256 / pngdiff.
