# s16 — SPEC-SYNC: notebook-web-ui (U02)

- drift_count: **0**
- verified_by: architect
- commit: 0e6c52334dd81f0b4c2e394d5a6da0938930bdc6

## Сверка spec/core.md §6 + UI-граф ↔ web/*

| Spec/граф | Реализация |
|---|---|
| login/register/notes | три секции index.html |
| 27 data-testid | 27/27 в index.html |
| labels/role=alert/aria-live | login/register/notes-error |
| notes-empty/notes-loading | состояния list |
| note-item/delete-note | template + cloneNode |
| token localStorage notebook.token | app.js |
| 400/401/409 показ | per-screen error + invalid/aria-invalid |
| 401 -> clear + /login | clearAuth + location.replace |
| go:embed index/app.css/app.js | main.go hunk |
| 7 Playwright сценариев | spec.js |
| no frameworks/CORS/logout API | проверено |

Drift: 0.
