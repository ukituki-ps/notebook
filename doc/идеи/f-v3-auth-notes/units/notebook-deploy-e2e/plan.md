# Unit plan — notebook-deploy-e2e (U03)

- unit_id: notebook-deploy-e2e
- domain: notebook-deploy
- sde: sde-infra
- change_class: security
- files: deploy/Dockerfile, deploy/path1/e2e-preview.sh, path1.project.json,
  path1.ui.json, .dockerignore
- base_sha: e2436c9d022cf66240ecbba15b4c82d6f13a6605

## Tasks (порядок)

1. T0007 — deploy/Dockerfile: build stage COPY *.go + COPY web/ до go build;
   runtime/ENTRYPOINT/EXPOSE не менять; .dockerignore (web/e2e,
   web/node_modules; embed-файлы включены).
2. T0008 — deploy/path1/e2e-preview.sh: health JSON, register/login A/B,
   authed GET/POST/DELETE, 401, A/B isolation, foreign/repeat 404, invalid id
   400, Playwright chromium, fail-close без браузеров.
3. T0009 — path1.project.json: graph.source_roots=['web'],
   e2e.frontend_dir='web', e2e.command без изменений, audit.mode='app',
   audit.database=false, canaries.require_dsn=false,
   deploy.stand_command path10 без изменений, CANARY-DELETE-STATUS сохранён;
   path1.ui.json platform='web'.

## Acceptance

`bash -n`, jq-ассерты adapter, `git diff --exit-code deploy/path1/preview-deploy.sh`,
docker build/E2E на s20b/s20c.
