# E1763 — s20b preview deploy (test2)

- Date: 2026-11-09T14:16Z
- Execution: `E1763`; previous step `s20a.unit_integrate` accepted on `2412e70`
- Work branch: `dev/f-v4-note-search-clean-v2`
- Base SHA: `f5e1b4182726c0ca997456c320aacf69b8cdb5e3`
- `gate_bundle_digest`: `sha256:755214cf300e0e00ed2559041a59f17b5d89cd3f011073cd5a41c58481841347`
- test2 lease: `efe7125f-93d0-49c5-88ff-68ae23684997` (active)

## Deploy

| field | value |
|---|---|
| stand | `test2` |
| eval target | `.orc-eval/E1763/2412e7030fe364f21e3510d7896d685306b76978` |
| image | `notebook-stand:test2-2412e70` |
| image digest | `sha256:4a5303b4ab403f82f9c5780723e13b99a90c2642bd8d3c99079372e59605fc9a` |
| build args hash | `sha256:eb27c613b0560f9f186a39bab5a9bcc7cc2b2c5f8b37950d0cae9f0c05c26d6a` |
| deployed ref / commit | `2412e70` / `2412e7030fe364f21e3510d7896d685306b76978` |
| url | `https://test2.nexus.ukituki.tech` |
| execution root | `.orc-eval/E1763/preview-deploy.json` |

- Host stand-runner `deploy-preview` rc=0 (`PR-97acbfa145ee`).
- `/healthz` returns `build_ref=2412e70`, matching commit, image digest and
  `gate_bundle_digest`; provenance checked in `PR-5dcdbfd24d6f`.
- `check-run-artifacts` on the execution root: OK (per-run artifacts untracked).
- No manual `git worktree add`; ORC/host-runner resolved the eval worktree.
- No force/waiver/`na`; no SQL; no container/DB patch; test1/prod/main untouched.

## Next

s20c E2E on test2. Stop after s20c; `s24` is not started.
