# UI Audit — f-v3-auth-notes (s22a, E4312)

- **Platform:** web
- **Stand:** `https://test2.nexus.ukituki.tech`
- **Preview ref / stand.sha:** `ea1e61ffca92b6a7b9982e58c8c3fa97c106e1c7` (`ea1e61f`; UI/API идентичны `80478e4`; E2E 7/7 на Playwright 1.64.1)
- **Audit scope:** чек-лист A–L, фактические `web/index.html`, `web/app.js`, `web/app.css`, actualized `arch/structure/ui-pages/*.yaml`, `web/e2e/auth-notes.spec.js`, `spec/core.md`.
- **Evidence:** `doc/идеи/f-v3-auth-notes/scenario-evidence.json` + screenshots `E2E-1.png … E2E-7.png` (per-run артефакты execution root, в git не коммитятся).

## Итог

**OK. 0 blockers, 0 majors, 9 minors, 6 cosmetics, 0 open critical/high.**

Все блоки A–L присутствуют. Ни один minor/cosmetic не блокирует приёмку: это остаточные замечания и зафиксированное расхождение spec §6.4, где код принят как истина.

| Блок | Verdict | Кол-во items | Комментарий |
|---|---|---|---|
| A — визуальная иерархия/типографика | OK | 1 | Один h1 на экран, card/label/body шкала, system-ui без внешних шрифтов |
| B — адаптивность <=640px | OK | 1 | Breakpoint 640px, full-width controls, note-item в колонку, 44px тач-таргеты |
| C — навигация/переходы | OK | 1 | register→login (prefill), login→notes, 401→login, logout; всё через `location.replace` |
| D — формы/валидация | OK | 2 | visible labels, confirm-password, 400/409 inline, `aria-invalid` на register |
| E — состояния | OK | 1 | loading / empty / list / error / submitting / delete-pending |
| F — a11y | OK | 2 | labels, `role=alert`, `aria-live=polite`, accessible names, focus-visible, 44px |
| G — консистентность текста/переходов | OK | 1 | Расхождение spec §6.4 (success-сообщение + ~0.8s) — cosmetic, код=истина |
| H — обработка ошибок UX | OK | 1 | 400/401/404/409 → человеческие inline-сообщения, без stack/secrets |
| I — производительность/ресурсы | OK | 1 | Только локальные `/app.css` и `/app.js`, без CDN/внешних шрифтов |
| J — security UX | OK | 2 | Пароль не в storage/DOM, token только localStorage + Authorization, logout/401 очищают storage |
| K — UI-граф/testid | OK | 1 | 27/27 data-testid из actualized login/register/notes |
| L — E2E-покрытие | OK | 1 | 7/7 pass, screenshots E2E-1…E2E-7, scenario-evidence.json |

## Minor (9)

1. **C1** — переходы реализованы через `location.replace`; 401-редирект намеренно отложен на 200 ms, чтобы пользователь увидел banner. Поведение корректное, отмечено как residual.
2. **D1** — негативные UI-пути 400/409 подтверждены кодом и статическими проверками; в 7 E2E-сценариях они не сняты отдельными скриншотами.
3. **E1** — loading-состояние `notes-loading` — обычный `<p class="muted">`, без `role=status`/`aria-live`; spec §6.7 этого не требует.
4. **F1** — `aria-invalid` выставляется только на register (так и задумано в graph); login/notes его не используют.
5. **F2** — focus-visible присутствует (`outline: 3px solid #ffbf47; outline-offset: 2px`), но контраст к белому 1.64:1 — рекомендация WCAG 1.4.11, не блокер по spec §6.7.
6. **H1** — для неизвестных статусов и сети используются generic-сообщения; секреты и внутренние детали не раскрываются.
7. **J1** — token хранится в `localStorage` по требованию spec §6.2 (XSS-риск принят дизайном), в DOM и логах токена/пароля нет.
8. **K1** — 27/27 testid подтверждены `TestUISemantics`; legacy testid отсутствуют.
9. **L1** — 7/7 сценариев покрывают happy path, reload, isolation и unauth 401; login-401 и 400/409 UI-пути остаются за пределами E2E-набора.

## Cosmetic (6)

1. **A1** — единый системный шрифт и простая иерархия; визуальных расхождений с эталоном нет.
2. **B1** — мобильный breakpoint один (640px), промежуточных брейкпоинтов нет; для текущей card-вёрстки достаточно.
3. **D2** — одновременно видна одна ошибка, новая заменяет старую; текст сохраняется, кроме пароля при 401.
4. **G1** — spec §6.4 обещает «Аккаунт создан. Войдите.» и задержку ~0.8 s; фактический код сразу делает `location.replace('/login')` (E2E-1). Зафиксировано как cosmetic, без блокера.
5. **I1** — `/app.css` и `/app.js` локальные, внешних запросов нет; `go:embed` использует явные паттерны.
6. **J2** — logout не вызывает API, только очищает `notebook.token`/`notebook.user` и делает `location.replace('/login')` — соответствует spec §6.2.

## Подтверждение stand.sha

`stand.sha` в `ui-audit.json` равен ровно:

```
ea1e61ffca92b6a7b9982e58c8c3fa97c106e1c7
```

Это preview-deploy ref (`ea1e61f`), на котором выполнен E2E-прогон 7/7; UI/API идентичны `80478e4`.

## Evidence

- `doc/идеи/f-v3-auth-notes/scenario-evidence.json` — 7/7 pass, sha256 скриншотов.
- `doc/идеи/f-v3-auth-notes/screenshots/E2E-1.png` — register → login (prefill).
- `doc/идеи/f-v3-auth-notes/screenshots/E2E-2.png` — login → notes, token в localStorage.
- `doc/идеи/f-v3-auth-notes/screenshots/E2E-3.png` — создание заметки.
- `doc/идеи/f-v3-auth-notes/screenshots/E2E-4.png` — reload persistence.
- `doc/идеи/f-v3-auth-notes/screenshots/E2E-5.png` — delete + empty state.
- `doc/идеи/f-v3-auth-notes/screenshots/E2E-6.png` — A/B isolation.
- `doc/идеи/f-v3-auth-notes/screenshots/E2E-7.png` — unauth 401 + `WWW-Authenticate: Bearer`.

Выполненные локальные оракулы:

```sh
go test -count=1 -run 'TestUISemantics|TestNoSecretLeak|TestWireContract|TestAuthRequired|TestLoginInvalid' ./...
# ok github.com/ukituki-ps/notebook
```

`web/*`, `main.go`, adapter, UI-граф и deploy-скрипты не изменялись. Коммит не создавался.
