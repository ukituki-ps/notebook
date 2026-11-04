# s22 — Result audit: f-v3-auth-notes (E4312)

- verdict: **pass**
- execution: E4312
- audit_head: `e91be09e972c542efd9ea277b2a7a2b47a5ec602`
- preview: test2, build_ref `4fbfbb1` (UI/API идентичны `80478e4`; commit добавляет
  actualized UI-граф), health 200, unauth `/api/notes` 401
- feature: регистрация, логин, заметки, per-user isolation, web UI, tests, E2E
- prod/main/stage/canary: не затрагивались; s45/s46 не выполнялись

## Acceptance criteria

| id | statement | oracle | proof |
|---|---|---|---|
| AC-API-AUTH | register 201/400/409/405; login 200/400/401/405; bearer TTL 24h; no secrets | `go test` TestAuthRequired/TestLoginInvalid/TestNoSecretLeak/TestWireContract | s20a `go build/vet/test` PASS (`PR-5386aac82ddf`); API smoke test2 GREEN |
| AC-NOTES-ISOLATION | own notes only; DELETE own 204; foreign/missing 404; no auth 401; wrong method 405 | `go test` TestNotesIsolation/TestDeleteForeignNote/TestNotesMethodNotAllowed | U01 accepted; E2E-6; API smoke 404/405/204 |
| AC-UI | login/register/notes, 27/27 testids, a11y, 401→/login, add/delete/empty/loading | `go test` TestUISemantics + 27/27 testids | U02 accepted; s21 actualized graph; s22a UI audit PASS |
| AC-E2E | 7/7 Playwright E2E-1..7 with screenshots/evidence | `npx playwright test web/e2e/auth-notes.spec.js` | preview-verdict `80478e4` status=verified mode=ui; screenshots E2E-1..7 |
| AC-PREVIEW | test2 health 200, build_ref matches, unauth 401 | `curl /healthz`; `curl -i /api/notes` | health 200 build_ref `80478e4`/`4fbfbb1`; 401 + WWW-Authenticate: Bearer |
| AC-UI-AUDIT | s22a checklist A–L | `python3 tools/ui-audit-check.py --platform web --expect-sha 4fbfbb1` | gate-ui-audit PASS; 15 items, blockers=0, majors=0 |

## Проверки

- Contract parity: 5 операций, drift 0, divergent [].
- Fault catalog: 20 items, **15 covered / 5 na / 0 gap**; `fault-verdicts.json`
  с detector proofs; gate `fault-catalog` PASS.
- UI audit (s22a): 15 items A–L, blockers 0, majors 0, minors 9, cosmetics 6.
- E2E: 7/7 на preview `80478e4`; scenario-evidence + screenshots
  (per-run, не в git); UI/API на `4fbfbb1` идентичны.
- Playwright-перепрогон на `4fbfbb1` в контейнере runner упал из-за
  `libnspr4.so` (окружение runner, не фича); для s24 нужен passing
  preview-verdict на итоговом билде — исправление в s23/platform.

## Новые findings

Нет. Открытых critical/high по execution: 0.

## Остаточные замечания (не блокеры)

- spec §6.4 обещает success-сообщение и задержку ~0.8 s; код сразу делает
  `location.replace('/login')` (cosmetic, код принят как истина).
- Focus-contrast `#ffbf47` на белом — minor recommendation (WCAG 1.4.11).
- Playwright-контейнер runner без `libnspr4` — platform/infra, не код фичи.
