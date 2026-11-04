# s20c — Preview verify (E4312, after s23 re-run)

- execution: E4312
- stand: test2, build_ref **ea1e61f** (commit `ea1e61ffca92b6a7b9982e58c8c3fa97c106e1c7`)
- Playwright: **1.64.1** (lock committed; 1.53.0 bug с `fill()` textarea)
- E2E: **7/7 passed** (E2E-1…E2E-7), `mode=ui`, pngdiff OK
- preview-verdict: `result=pass`, `status=verified`,
  `artifact_digest=sha256:824e3e82f78f7375cbd31999546a2c5615cacb295bc23acb00107f5e80ecf860`
- scenarios: `doc/идеи/f-v3-auth-notes/scenarios.json` (git)
- per-run evidence: `scenario-evidence.json` + `screenshots/E2E-*.png`
  (execution root, **не в git**; платформенный sync починен)

## Примечание

Runner записал `artifact_digest` без префикса `sha256:`; при приёмке формат
нормализован (`sha256:` + тот же digest), значение evidence не менялось.
Запрошен platform-фикс: `run-stand-e2e.sh` должен писать digest сразу с
`sha256:` или gate должен нормализовать префикс.
