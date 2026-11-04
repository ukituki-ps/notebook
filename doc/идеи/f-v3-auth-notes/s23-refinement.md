# s23 — Refinement по s22c findings (E4312)

- execution: E4312
- input: `code-review.json` (`qwen3.8-fast` / `llama-proxy`, independent)
- verdict before: pass (0 critical/high; 2 low, 3 info)
- scope: только замечания s22c + test-infra; фича/API/UI не переделывались

## Findings и решение

| id | sev | решение |
|---|---|---|
| CR-5 | low | **fixed**: `.gitignore` дополнен `node_modules/`, `package-lock.json` (npm install e2e больше не пачкает дерево) |
| CR-1 | low | **accepted/deferred**: `decodeJSON` игнорирует trailing-контент; spec §1.4 этого не требует, поведение не нарушает контракт. Строгий JSON — отдельная итерация (изменение wire-контракта + тесты) |
| CR-2 | info | **deferred**: `usersByID` write-only, не влияет на поведение/wire; удаление — рефакторинг вне scope s23 |
| CR-3 | info | **deferred**: глобальный `pbkdf2Iterations` не мутируется в тестах; активной гонки нет. `-race` обязателен в CI (AC-20) |
| CR-4 | info | **accepted**: trailing-slash `/login/` → JSON 404; spec §6.1 трактует путь без слэша, UI никогда не ссылается на `/login/` |

## Test-infra fix (важно для preview/s24)

`path1.project.json` `e2e.command` очищен (`""`), чтобы штатный `stand-runner`
использовал **native UI mode** (Playwright в своём контейнере), а не host-local
`e2e-preview.sh` с glibc-браузером и missing `libnspr4`. `integration.command`
остаётся API-only (`E2E_API_ONLY=1`) для s20a. `deploy.stand_command` не изменён.

## Проверки

- `go build ./...`, `go vet ./...`, `go test -count=1 ./...` — GREEN (без
  изменения кода фичи).
- `git diff` в s23: `.gitignore`, `path1.project.json` (e2e.command), этот отчёт.
- Playwright 7/7 — перепрогон native runner на preview после выката s23 HEAD.

## Ограничения

prod/main/stage/canary не затрагивались; s45/s46 не выполнялись; E1320 не тронут;
fake evidence/self-sign/force/skip/waiver не применялись.

## Native runner version alignment (1.64.1)

- `@playwright/test` — **1.64.1** (lock закоммичен). Версия 1.53.0 непригодна для
  этого UI: после `fill()` textarea остаётся пустым (`value=""`, Add disabled),
  E2E-3/4/5/6 падают; на 1.64.1 — 7/7 pass.
- `playwright.config.js` использует `/ms-playwright` образа при наличии,
  иначе host-кэш (host-local).
- `path1.project.json` `e2e.command`:
  `npm ci --no-audit --no-fund && npx --no-install playwright test`
  (host-local runner; системные Chromium deps на pr01 установлены).
