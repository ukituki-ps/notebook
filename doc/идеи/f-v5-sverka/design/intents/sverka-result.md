---
schema: design.intent.route/v1
route: /sverka/{runId}
template: tpl-sverka-result
feature_id: f-v5-sverka
execution_id: E7135
ds_release: "1.0.1"
manifest: design-intent.json
content_spec: design/content-specs/tpl-sverka-result.md
---

# Design intent — `/sverka/{runId}` «Результат сверки»

## Задача экрана

За 3 секунды ответить: сверка готова? сколько расхождений? есть ли
предупреждения? Затем дать разобраться: свод по договорам, фильтры, список
расхождений с подсветкой, живые договоры и заявки ЗХ.

## 3-second test

На 360×640: статус «Готова», «Итого расхождений: N» и W1/W2 (если есть) — выше
сгиба. Провал — если пользователь принимает предупреждение за ошибку или не
находит итог.

## Above the fold (360×640)

«← К списку сверок» → `h1` → «ГК — СК» → статус + итог → W1/W2.
В обработке: статус «Обрабатывается» и «Сверка выполняется. Результат появится
автоматически».

## Раскладка

- Широкая колонка 1120 px (GAP-09); шапка, предупреждения, KPI, фильтры, список.
- Свод: 18 колонок, sticky header и «Договор», итоговая строка; числа > 0 —
  ссылки-фильтры (`?contract=…&category=…`).
- Список: 15 колонок; пары ФИО/ДР/программа подсвечены в обеих ячейках;
  «Договоры ЗХ», «Заявки ЗХ» (3 + «еще N»), «Действия с нашей стороны».
- Mobile: свод — горизонтальный скролл; расхождения — карточки строк; фильтры —
  `<details>`.
- Большие таблицы: первые 200 строк + «Показать ещё 200»; фильтры по полному
  снимку.

## Состояния

`S-RES-*`: loading, processing (I1 базовой v2), error, no-data, ready,
empty (I2), filter-empty, export disabled/pending/error, ZX no-contracts /
no-actions (I1 дополнения 3), big table, long values. Плюс глобальные
unauthorized/forbidden/offline/not-found/server-error.

## Решения

- I2 и пустой фильтр — разные состояния и тексты.
- «Совпало» в списке не показывается; только в своде.
- Экспорт disabled до «Готова» + helper; E8 — inline-защита, не toast.
- Данные ЗХ — на момент открытия экрана, с явным примечанием.
- Ссылки карточек — в новой вкладке; без настроенного URL-шаблона номер
  остаётся текстом (OQ-D7).

## DS

Reuse: card, button, button-secondary, input, error, notes-header, search-field,
search-clear, states loading/empty/search-empty. Gaps: table, select,
multiselect/checkbox, status chip, inline notice, link, semantic colors, layout,
small type, disclosure, progress, incremental list, metadata list.

## Non-goals

Редактирование строк, комментарии, создание заявок, пользовательская
сортировка, виртуализация, toast, модальные окна, изменение DS.
