# Unit plan — notebook-search-deploy-e2e (E1546 s20, u03)

- **Unit:** notebook-search-deploy-e2e (domain notebook-deploy, sde-infra, plain)
- **Base:** 11b752cd32ba34e15ffd7f1a4d93a6d612614528
- **Files:** deploy/path1/e2e-preview.sh, path1.project.json, web/e2e/notes-search.spec.js, doc/идеи/f-v4-note-search/UI-GRAPH.yaml

## Scope

Playwright 1.64.1 E2E on test2 (login, 2 notes, find one, find none, clear,
user-B isolation; pngdiff OK), API smoke adapter, UI graph actualization at s21.

## Tasks / oracles

| # | Task | Oracle |
|---|---|---|
| 1 | Playwright search scenarios | 6 E2E |
| 2 | API smoke adapter | integration smoke |
| 3 | UI graph actualization | s21 gate |
