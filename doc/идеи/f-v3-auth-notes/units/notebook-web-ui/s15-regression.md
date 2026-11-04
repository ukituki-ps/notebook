# s15 — REGRESSION: notebook-web-ui (U02)

- regression_status: **pass**
- verified_by: auditor
- commit: 910800f58386bb0910fc02b190a5b2dfd4140732

## Прогон

- `go test -count=1 ./...` — PASS, TestUISemantics PASS.
- `go build ./...`, `go vet ./...` — PASS.
- `node --check web/app.js`, `web/e2e/auth-notes.spec.js` — PASS.
- testids YAML↔HTML — 27/27, MISSING [], EXTRA [].
- 7 Playwright сценариев, без skip/fixme.
- Embed не включает web/e2e; API-логика main.go не изменена (только static hunk).
- Базовые backend-тесты (из base) не сломаны.

## Регрессии

Не обнаружено. Playwright-прогон 7/7 — на preview (s20c) после merge U01.
