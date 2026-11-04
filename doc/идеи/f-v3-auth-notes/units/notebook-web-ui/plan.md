# Unit plan — notebook-web-ui (U02)

- unit_id: notebook-web-ui
- domain: notebook-web
- sde: sde-frontend
- change_class: security
- files: web/index.html, web/app.js, web/app.css, web/e2e/auth-notes.spec.js,
  playwright.config.js, web_ui_test.go, main.go (только embed/static hunk)
- base_sha: e2436c9d022cf66240ecbba15b4c82d6f13a6605

## Tasks (порядок)

1. T0004 — web/index.html + web/app.css: экраны /login /register /notes,
   data-testid, видимые labels, role=alert + aria-live=polite, notes-empty/
   notes-loading, mobile one-column, focus-visible, без phantom notes.
2. T0005 — web/app.js: fetch same-origin, Bearer, localStorage
   notebook.token/notebook.user, 400/401/409, 401 -> clear + replace('/login'),
   add/delete/loading/empty, client logout; main.go hunk: go:embed + static
   routes + `/` -> /login; web_ui_test.go TestUISemantics.
3. T0006 — playwright.config.js + web/e2e/auth-notes.spec.js: ровно 7
   сценариев (register, login, create, reload, delete, A/B isolation, 401).

## Acceptance

`node --check web/app.js`, `TestUISemantics`, `npx playwright test --list` = 7,
grep data-testid/role=alert/aria-live/notes-empty; никаких фреймворков/CORS.
