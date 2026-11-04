# s20b — preview deploy (E4312)

- execution: E4312
- stand: test2 (`https://test2.nexus.ukituki.tech`), dev-only
- transport: `git`, deploy через `stand-runner` (host pr01, dev-runner)
- commit: HEAD ветки `dev/f-v3-auth-notes` на момент s20b
- provenance: `preview-deploy.json` в execution root
  (`stand`, `ref`, `commit`, `evaluated_sha`, `stand_image_digest`,
  `build_args_hash`)
- проверки: `/healthz` → `200`, `build_ref=HEAD`; unauth
  `GET /api/notes` → `401`; API-smoke (register/login/CRUD/isolation/404/400/204).
- Playwright UI (7 сценариев) — s20c, не в Alpine-контейнере.

Prod/canary не затрагиваются; s45/s46 не выполняются.
