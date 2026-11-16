# AGENTS.md

## UI kit `@kub/ui-kit` доступен локально

Handover лежит **вне git-репозиториев**: `/workspace/kub-ui-kit-handover`
(не перемещать и не удалять). Проверен 2026-11-15, SHA256 сходится с registry.

| Файл | Что это |
|---|---|
| `kub-ui-kit-1.0.4.tgz` | рабочая версия (рекомендуется) |
| `kub-ui-kit-1.0.2.tgz` | тот же билд, версия с git-тегом `v1.0.2` |
| `SHA256SUMS` | `sha256sum -c SHA256SUMS` |
| `README.md`, `npmrc.example`, `tailwind.config.example.js` | инструкция и примеры |

Версии `1.0.2`, `1.0.3`, `1.0.4` имеют **идентичный `dist`** (703 файла
побайтно), различается только `version` в `package.json`. Использовать `1.0.4`.

### Установка (без GitLab-токена)

```bash
npm install /workspace/kub-ui-kit-handover/kub-ui-kit-1.0.4.tgz
```

Нужен доступ к `registry.npmjs.org`: tarball тянет 80 пакетов (24 прямые
зависимости). Это не офлайн-установка.

Другие версии из registry — project-endpoint читается анонимно:

```ini
@kub:registry=https://gitlab.kubiki.pro/api/v4/projects/30/packages/npm/
```

group-endpoint `.../api/v4/packages/npm/` требует PAT `read_api` (отдаёт 401).
Репозиторий `kub/kub-ui-kit` (CI, тесты, история) недоступен — нет PAT/членства/SSH.

### Подключение

```tsx
import '@kub/ui-kit/tokens.css'; // токены + шрифты, классы собирает Tailwind
```

```js
// tailwind.config.js
module.exports = {
  content: [
    './src/**/*.{js,ts,jsx,tsx}',
    './node_modules/@kub/ui-kit/dist/**/*.js',
  ],
  presets: [require('@kub/ui-kit/tailwind.config')],
};
```

Фактически нужны **React 18** и **Tailwind >= 3.4.1**; `peerDependencies` в
пакете устарели (`react >=17`, `tailwindcss >=3.0`).

```tsx
import { Button, Input, Modal } from '@kub/ui-kit';

<Button.Root variant="primary" mode="filled" size="medium">Сохранить</Button.Root>
```

45 из 50 компонентов экспортируют `.Root`. Без `.Root`:
`avatar-empty-icons`, `command-menu`, `datepicker` (`Calendar`),
`radio` (`Group`/`Item`), `rating` (`Rating`).

### Известные дефекты (учитывать, не диагностировать заново)

- **Badge**: классы `verified-*`, `highlighted-*`, `stable-*`, `away-light`,
  `away-lighter`, `feature-dark` отсутствуют в `tailwind.config.js`
  (CSS-переменные в `tokens.css` есть) → часть вариантов без фона/текста.
- **Datepicker**: CSS `react-day-picker` не подключён — импортировать отдельно.
- **Лицензия**: 40/50 компонентов — производные AlignUI; в `package.json` MIT,
  файла LICENSE нет → нужна юридическая проверка.
- **Нет тестов и typecheck-гейта**; changelog отсутствует.
- Сторис и тесты в пакет не входят; Storybook в GitLab Pages недоступен.

### Исходники компонентов

В `dist/**/*.map` есть `sourcesContent` — полный код 50 компонентов, hooks и
utils доступен без GitLab. Распакованная временная копия:
`/tmp/kilo/uikit/sources`, распакованные пакеты: `/tmp/kilo/uikit/package`,
`/tmp/kilo/uikit102/pkg102`. `/tmp` может чиститься — при необходимости
извлечь заново из `/workspace/kub-ui-kit-handover/*.tgz`.
