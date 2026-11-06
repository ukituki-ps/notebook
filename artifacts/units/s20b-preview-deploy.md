# s20b preview deploy — f-v4-note-search (E8363)

- Execution: `E8363`; step `s20b.preview_deploy`
- Stand: `test2` (https://test2.nexus.ukituki.tech), exclusive lease `f3de666b-418e-4bd5-960c-af0d1f253a9e`
- Transport: `git`; deployed commit: `b050e81b580865d685f52de9a71fd6c322ab2e40`
- Build ref: `b050e81`
- Image: `notebook-stand:test2-b050e81`
- Image digest: `sha256:6844e6224727e5ff89285f3da2cd5e77888d9319dce05f743923f1a3a41913e8`
- Build args hash: `sha256:681d9b3ca759162a30538d91eaf8d7db708aedfea26e8616568ebbd2098c7b20`
- Deployed at: `2026-11-06T22:47:59Z`

## Test2 /healthz after deploy

```json
{"status":"ok","build_ref":"b050e81","commit":"b050e81b580865d685f52de9a71fd6c322ab2e40","image_digest":"sha256:6844e6224727e5ff89285f3da2cd5e77888d9319dce05f743923f1a3a41913e8","build_args_hash":"sha256:681d9b3ca759162a30538d91eaf8d7db708aedfea26e8616568ebbd2098c7b20","gate_bundle_digest":""}
```

## Host runner evidence

- `run.log`: `preview-deploy: GREEN test2 on notebook-stand:test2-b050e81`
- `res.json`: `{"execution_id":"E8363","rc":0,"reason":"ok","duration_s":15,...}`
- `preview-deploy.json`: `schema=orc.preview-deploy/v1`, `commit=b050e81...`, `stand=test2`
- runtime `build-provenance.json` / `deploy-provenance.json` match the image digest and commit above.

## Notes

- The execution eval worktree was absent after s20a; it was recreated at
  `.orc-eval/E8363/b050e81...` with a **relative** `gitdir` so the same tree
  resolves on the host (`/srv/archkit/dev/orc-repos/...`). It contains no
  `/app/...` reference in `.git`.
- Only test2 was touched; test1/prod/preprod were not.
