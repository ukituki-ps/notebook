# s14 — QUALITY: notebook-web-ui (U02)

- quality_score: **9/10**
- crutch_density: **low**
- commit: dbb9dcfee9ca269e37583ba34f42ffd0290848d7

## Оценка

- Разметка соответствует UI-графу (27/27 testid), a11y (labels, role=alert,
  aria-live), состояния loading/empty/list.
- Шаблон note-item/delete-note вместо фантомных строк; app.js клонирует
  template, без inline-генерации разметки.
- embed явный, без web/e2e; статика отдаётся с no-store.
- 7 Playwright сценариев, без skip/fixme; нет фреймворков/CORS/logout API.
- Ошибки per-screen, 401 очищает storage и делает replace('/login').

## Crutches

Не обнаружено.
