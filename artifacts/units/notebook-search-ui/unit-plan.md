# Unit plan — notebook-search-ui (E1546 s20, u02)

- **Unit:** notebook-search-ui (domain notebook-web, sde-frontend, change_class plain)
- **Base:** 11b752cd32ba34e15ffd7f1a4d93a6d612614528
- **Files:** web/index.html, web/app.js, web/app.css, web_ui_test.go

## Scope

Labelled search input `data-testid=notes-search`; live client-side filtering of
the loaded owner-scoped list; clear control restores the full list;
`notes-search-empty` for a non-empty query with no matches; create/delete/reload
re-apply the active query. No auth/persistence change.

## Tasks / oracles

| # | Task | Oracle |
|---|---|---|
| 1 | search markup + testids | TestUISemantics |
| 2 | filter/clear/empty logic | TestUISemantics, E2E |
| 3 | UI semantics tests | TestUISemantics |
