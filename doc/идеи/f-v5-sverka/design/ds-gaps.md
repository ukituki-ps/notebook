# DS gaps — f-v5-sverka (design intent)

- Feature: `f-v5-sverka`, execution `E7135`, step `s02c.design_intent`
- Pinned DS: **Notebook DS 1.0.1**, digest `sha256:4e0ef1052a1401a928588445f921f7d231b7c0e7c9b10c181fdbbb439108c85e`
- Registry: `design/registry.json` — **14 компонентов**, tokens: `design/tokens.json`
- Stack: vanilla JS + CSS. React/Tailwind не используются.
- Основание: `scope-report.md` OD-8 (DS minor release: table/multiselect/upload/badge)
  и ограничение шага «не выдумывать компоненты».

## Правило

Gap — это отсутствие компонента/токена в DS 1.0.1. В design intent gap
фиксируется, но **не превращается в новый компонент**: указывается временная
композиция из существующих primitives/patterns и предложение для DS 1.x.
Ни один id ниже не добавлен в `design/registry.json`; выдуманных DS-компонентов
в шаблонах нет.

## Что реально есть в DS 1.0.1

| id | selector | states |
|---|---|---|
| `primitives/card` | `.card` | default |
| `primitives/button` | `button` | default, hover, focus, disabled |
| `primitives/button-secondary` | `.logout` | default, hover, focus |
| `primitives/input` | `input` | default, focus, invalid |
| `primitives/textarea` | `textarea` | default, focus, invalid |
| `primitives/error` | `.error` | default |
| `patterns/notes-header` | `.notes-header` | default |
| `patterns/notes-list` | `.notes-list` | default |
| `patterns/note-item` | `.note-item` | default, pending |
| `patterns/search-field` | `.notes-search` | default, focus |
| `patterns/search-clear` | `.notes-search-clear` | default, focus |
| `states/loading` | `[data-testid="notes-loading"]` | loading |
| `states/empty` | `[data-testid="notes-empty"]` | empty |
| `states/search-empty` | `[data-testid="notes-search-empty"]` | empty |

## Gaps

### GAP-01 — Table / data table

- **Отсутствует:** таблица (шапка, sticky header, плотные строки, числовые
  ячейки, итоговая строка, горизонтальный скролл, мобильные карточки строк).
- **Где нужно:** свод по договорам (18 колонок), список расхождений (15
  колонок), история (8 колонок), таблица ошибок E3–E7 (3 колонки).
- **Временная композиция:** семантический `<table>` + `primitives/card` как
  контейнер; токены `--border-subtle` для линий, `--space-2/3` для плотности;
  на < 768 px — CSS-перестройка строки в карточку.
- **Предложение DS 1.x:** `patterns/data-table` (density, sticky, numeric,
  total-row, responsive stacked rows).
- **Blocking:** high (OD-8). Без него s03/s22a UI-гейты и качество больших
  таблиц под угрозой.
- **Статус:** accepted for intent; implementation requires DS minor или
  явное решение architect/designer.

### GAP-02 — Select

- **Отсутствует:** select/combobox (single).
- **Где нужно:** ГК, СК, фильтр «Договор», фильтр статуса/ГК/СК истории.
- **Временная композиция:** нативный `<select>` с теми же токенами
  (`--control-height`, `--border`, `--radius`, `--focus`); без кастомного
  dropdown (a11y и мобильные нативные пикеры важнее вида).
- **Предложение DS 1.x:** `primitives/select` + `disabled` state.
- **Blocking:** medium.

### GAP-03 — Multiselect / checkbox / filter panel

- **Отсутствует:** multiselect, checkbox, disclosure-панель фильтров.
- **Где нужно:** «Категория» (несколько значений), «Показывать для справки»,
  мобильные фильтры.
- **Временная композиция:** `<details>` + нативные `<input type="checkbox">`;
  видимый label, счётчик выбранных, «Сбросить фильтры». Никаких кастомных
  «чипов-мультивиборов».
- **Предложение DS 1.x:** `primitives/checkbox`, `primitives/multiselect`,
  `patterns/filter-panel`.
- **Blocking:** medium (без него фильтры остаются нативными).

### GAP-04 — Upload / dropzone / file chip

- **Отсутствует:** зона загрузки, drag-and-drop, карточка файла, прогресс
  загрузки.
- **Где нужно:** форма запуска (.xlsx, замена файла, E1/E2, имя+размер).
- **Временная композиция:** `<input type="file" accept=".xlsx">` + видимая
  кнопка «Выбрать файл»; drop-зона — обычный контейнер с обработчиками
  `dragover/drop`; имя файла + размер + «Заменить»/«Удалить» на
  `primitives/button`. Drag-and-drop — не единственный способ.
- **Предложение DS 1.x:** `patterns/file-upload`, `patterns/file-chip`.
- **Blocking:** high (без загрузки нет фичи).

### GAP-05 — Badge / status chip / category tag

- **Отсутствует:** badge/status-chip/category-tag.
- **Где нужно:** статусы сверки (3), статусы ЗХ/заявок, 13 категорий,
  «Есть заявки», маркер «Переход между ЮЛ».
- **Временная композиция:** текст в `<span>` с нейтральным фоном
  (`--bg`/`--card`) и рамкой `--border-subtle`; тон «внимание» —
  `--danger-bg` + `--danger` для расхождений. Всегда есть текст категории;
  цвет не единственный признак. 13 разных цветов не вводятся.
- **Предложение DS 1.x:** `primitives/badge` (tones: neutral/attention/
  success/warning) + `patterns/status-chip`.
- **Blocking:** medium (без него статусы читаются, но UI-аудит s22a отметит
  самодельный вид).

### GAP-06 — Inline notice / toast

- **Отсутствует:** info/warning-плашка, toast.
- **Где нужно:** W1/W2, E8 «Выгрузка доступна после завершения сверки»,
  «Сверка запущена», «Данные на момент открытия».
- **Временная композиция:** neutral-плашка на `primitives/card`/`note-item`
  с `role="status"`; ошибки — существующий `primitives/error`
  (`role="alert"`). Toast не вводится: сообщения inline рядом с источником.
- **Предложение DS 1.x:** `patterns/inline-notice` (info/warning/success),
  `patterns/toast` — только если появится реальная потребность.
- **Blocking:** medium (E8 в постановке описан как «всплывающее уведомление»;
  намеренно заменяем на inline + disabled-кнопку — см. design-intent
  `open_design_questions`).

### GAP-07 — Link / link-button

- **Отсутствует:** `primitives/link`; в `web/app.css` ссылка стилизована
  только внутри `.alt a` (login/register). Нет стиля для ссылок в таблице,
  ссылок-чисел свода, внешних ссылок.
- **Где нужно:** «Открыть сверку», исходный файл, договоры/заявки ЗХ,
  числа-фильтры в своде, «К списку сверок».
- **Временная композиция:** `<a>` с `--accent`, подчёркивание при hover/focus,
  `:focus-visible` из DS; числа свода — `<a href="?…">`, не JS-кнопка.
- **Предложение DS 1.x:** `primitives/link` (+ `link-external`).
- **Blocking:** medium (без него ссылки визуально неотличимы от текста).

### GAP-08 — Semantic status colors

- **Отсутствует:** токены success/warning/info; есть только `accent`,
  `danger`, `danger_bg`, `muted`.
- **Где нужно:** статусы, W1/W2, подсветка отличий, категории.
- **Временное решение:** 2 тона — нейтральный и `danger`; success-зелёный не
  вводится (нет токена и нет контрастной пары). Смысл дублируется текстом.
- **Предложение DS 1.x:** `color.success`, `color.warning`, `color.info` +
  парные `*_bg` с проверенным контрастом AA.
- **Blocking:** low (обход допустим, но ограничивает выразительность).

### GAP-09 — Layout tokens (wide / gutter)

- **Отсутствует:** `layout` в `design/tokens.json`; фактическая оболочка —
  `.app { max-width: 640px }` в `web/app.css`.
- **Где нужно:** экран результата (15 колонок) требует ~1120 px; история и
  форма остаются 640 px.
- **Временная композиция:** два контейнера: `app` (640) и `app-wide` (1120),
  отступы из `space` (16/24), без нового компонента.
- **Предложение DS 1.x:** `layout.content` (640), `layout.wide` (1120),
  `layout.gutter` (16/24).
- **Blocking:** medium (иначе таблица либо сжата, либо ломает оболочку).

### GAP-10 — Small type / tabular numbers

- **Отсутствует:** `font.small` (14 px), `font.mono`/tabular numerals.
- **Где нужно:** мета-строки в таблицах, заявки ЗХ (номер/тип/статус/дата),
  числовые колонки свода.
- **Временное решение:** базовый 16 px; табличные числа —
  `font-variant-numeric: tabular-nums` (CSS-свойство, не компонент); 14 px не
  вводится, пока нет токена.
- **Предложение DS 1.x:** `font.small`, `font.numeric`.
- **Blocking:** low.

### GAP-11 — Disclosure / collapsible section

- **Отсутствует:** disclosure/accordion.
- **Где нужно:** мобильные фильтры, «Показать все» у W1, «Подробнее» в
  мобильной строке, «еще N» у заявок.
- **Временная композиция:** нативный `<details>/<summary>`; для «еще N» —
  `primitives/button` с `aria-expanded`.
- **Предложение DS 1.x:** `patterns/disclosure`.
- **Blocking:** low.

### GAP-12 — Progress / indeterminate activity

- **Отсутствует:** progress/spinner/skeleton.
- **Где нужно:** I1 «Сверка выполняется», загрузка списка СК, загрузка
  истории, экспорт.
- **Временная композиция:** текстовый статус `states/loading`
  («Сверка выполняется…»), `aria-busy="true"`, без анимации; при
  `prefers-reduced-motion` — статичный текст.
- **Предложение DS 1.x:** `primitives/progress` (indeterminate) или
  `states/loading` с визуальным индикатором.
- **Blocking:** low (текст достаточен для приёмки, но UX-аудит может
  запросить индикатор).

### GAP-13 — Incremental list / pagination

- **Отсутствует:** pagination, «load more», виртуализация.
- **Где нужно:** большие таблицы (200+ строк, W2), «Показать ещё 200»,
  «еще N» заявок.
- **Временная композиция:** `primitives/button` «Показать ещё 200» +
  счётчик «Показано N из M»; `content-visibility: auto`; фильтры по всему
  снимку.
- **Предложение DS 1.x:** `patterns/load-more` / `patterns/pagination`.
- **Blocking:** low (OD-10 — клиентская фильтрация на этой поставке).

### GAP-14 — Metadata list / definition list

- **Отсутствует:** описание «ключ — значение» для шапки результата и карточки
  ошибок.
- **Где нужно:** ГК/СК/дата/автор/статус/файл; таблица ошибок.
- **Временная композиция:** `<dl>` внутри `primitives/card`; на mobile —
  стек; для ошибок — `<table>` (GAP-01).
- **Предложение DS 1.x:** `patterns/metadata-list`.
- **Blocking:** low.

## Сводка

| id | Компонент | Blocking | Временный обход |
|---|---|---|---|
| GAP-01 | table | high | семантический `<table>` + CSS, mobile cards |
| GAP-02 | select | medium | native `<select>` |
| GAP-03 | multiselect/checkbox | medium | `<details>` + native checkbox |
| GAP-04 | upload/dropzone | high | native file input + кнопка |
| GAP-05 | badge/status chip | medium | текст + 2 тона |
| GAP-06 | inline notice/toast | medium | card + role=status, inline |
| GAP-07 | link | medium | `<a>` на токенах |
| GAP-08 | semantic colors | low | neutral/danger + текст |
| GAP-09 | layout tokens | medium | app 640 / app-wide 1120 |
| GAP-10 | small type/numeric | low | 16 px + tabular-nums |
| GAP-11 | disclosure | low | native `<details>` |
| GAP-12 | progress | low | текстовый loading |
| GAP-13 | incremental list | low | button + content-visibility |
| GAP-14 | metadata list | low | `<dl>` в card |

**OD-8:** рекомендуемый путь — minor-релиз DS (table, select, multiselect,
upload, badge) **до** s03. Если релиз не делается, реализация допустима только
на перечисленных временных композициях, и это должно быть явно принято на
s03/s22a; design intent не повышает версию DS и не добавляет компонентов.
