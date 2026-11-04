# T0004 — brief

- unit_id: **notebook-web-ui**
- domain: **notebook-web**
- sde: **sde-frontend**
- change_class: **security**
- task: HTML-каркас трёх экранов (`index.html`) + CSS
- files: `web/index.html`, `web/app.css`
- depends_on: —

## Scope

1. **`web/index.html`** — единый HTML-вход с тремя экранами-состояниями
   `/login`, `/register`, `/notes` (без фреймворков и сборки). Разметка
   синхронна `arch/structure/ui-pages/*.yaml`:
   - login: `login-card`, `login-form`, `login-username`, `login-password`,
     `login-submit`, `login-error`, `register-link`;
   - register: `register-card`, `register-form`, `register-username`,
     `register-password`, `register-confirm`, `register-submit`,
     `register-error`, `login-link`;
   - notes: `notes-header`, `user-name`, `logout`, `note-form`, `note-input`,
     `add-note`, `notes-error`, `notes-list`, `note-item`, `delete-note`,
     `notes-empty`, `notes-loading`.
2. **A11y/подписи.** У каждого input — видимый `<label for>`; submit-кнопки с
   текстами `Login`, `Register`, `Add`, `Delete` (Delete дополнительно
   `aria-label` с id заметки); ошибки — `role="alert"` + `aria-live="polite"`,
   скрыты при пустом значении; список — `role="list"`, элементы
   `role="listitem"`; `notes-empty` виден только при пустом успешном списке,
   `notes-loading` — только на время загрузки. `note-item` помечается
   `data-note-id="<id>"`.
3. **Никаких фантомных данных.** В HTML нет захардкоженных заметок: список
   заполняется только из ответа `GET /api/notes`.
4. **`web/app.css`** — колонка ≤ 640px по центру; один breakpoint 640px; уже —
   одна колонка, input/textarea/button на всю ширину; touch-target ≥ 44px;
   `overflow-wrap: anywhere` для длинного текста; читаемый контраст (WCAG AA);
   `:focus-visible`; состояния `submitting`/`delete-pending` (disabled,
   приглушение), ошибка заметна. Без внешних шрифтов/ассетов/CDN.
5. Экраны статичны: JS-поведение — T0005; здесь только разметка/селекторы/стили,
   которые T0005 и `TestUISemantics` будут искать.

## Acceptance / оракулы

```sh
grep -q 'data-testid="login-card"' web/index.html
grep -q 'data-testid="register-card"' web/index.html
grep -q 'data-testid="notes-list"' web/index.html
grep -q 'data-testid="notes-empty"' web/index.html
grep -q 'data-testid="notes-loading"' web/index.html
grep -q 'data-testid="delete-note"' web/index.html
grep -q 'role="alert"' web/index.html
grep -q 'aria-live="polite"' web/index.html
grep -q 'Login' web/index.html && grep -q 'Register' web/index.html
grep -q 'Add' web/index.html && grep -q 'Delete' web/index.html
grep -q 'max-width: 640px' web/app.css
grep -q 'min-height: 44px' web/app.css
```

- Все `data-testid` из `arch/structure/ui-pages/*.yaml` присутствуют.
- У каждого поля есть видимая подпись; у кнопок — accessible name.
- `role="alert"` + `aria-live="polite"` ровно в трёх error-областях.
- `notes-empty` и `notes-loading` присутствуют в разметке и скрыты по умолчанию.
- Нет захардкоженных заметок и внешних ассетов.

## Зависимости

- Нет. T0005 (app.js + embed + `TestUISemantics`) и T0006 (Playwright)
  опираются на эти селекторы.

## Что НЕ делать

- Не писать JS-логику, fetch, localStorage, embed/static-хендлеры — это T0005.
- Не создавать отдельные `login.html`/`register.html`/`notes.html` и второй
  HTML-вход; не добавлять фреймворки/сборщики/CDN/шрифты.
- Не создавать заметки/данные в разметке; не рисовать «фейковые» строки.
- Не менять `main.go`, `main_test.go`, `web/app.js`, `web/e2e/*`,
  `playwright.config.js`, `deploy/*`, adapter-файлы.
- Не менять `arch/structure/ui-pages/*.yaml` (актуализация — s21).
- Не добавлять второй UI-граф (`arch/frontend/pages/*`, `UI-GRAPH.yaml`).
- Не выходить за 3 экрана и перечисленные состояния/селекторы.
