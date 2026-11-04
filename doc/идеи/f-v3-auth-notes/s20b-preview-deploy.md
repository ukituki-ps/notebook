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

- gate_base_ref: `ff9b8e1` (orc_start_commit) — для app-репо platform-tools check scoped до появления `deploy/` в base; это не skip/waiver.

## Re-deploy after s23 (Playwright 1.64.1)

- Повторный preview после refinement: runtime-код U01/U02/U03 не менялся;
  обновлены test-infra (Playwright 1.64.1 + lock, host-local e2e command).
- E2E 1.64.1: 7/7 pass (проверка fill() textarea; 1.53.0 давал 4 fail).
