---
schema: design.intent.route/v1
route: /sverka
template: tpl-sverka-launch
feature_id: f-v5-sverka
execution_id: E7135
ds_release: "1.0.1"
manifest: design-intent.json
content_spec: design/content-specs/tpl-sverka-launch.md
---

# Design intent — `/sverka` «Сверка застрахованных»

## Задача экрана

Сотрудник ГК приходит с файлом от СК. Он должен понять три обязательных входа
(ГК, СК, файл), запустить сверку и увидеть, что файл принят или какие ошибки
исправить. Ниже — история сверок всех сотрудников: открыть, скачать файл,
повторить.

## 3-second test

За 3 секунды на 360×640 пользователь отвечает: «нужно выбрать ГК, СК и файл;
кнопка запуска пока неактивна». Провал — если файл кажется необязательным или
не видно зависимости СК от ГК.

## Above the fold (360×640)

`h1` → поле ГК → поле СК (disabled) → метка зоны файла. История — ниже.

## Раскладка

- Одна колонка 640 px, карточки: «Новая сверка» и «История сверок».
- Форма: ГК → СК → «Скачать шаблон» → зона файла → «Запустить сверку».
- Ошибки E1/E2 — inline под зоной; E3–E7 — сводка с фокусом + таблица
  «Строка / Колонка / Ошибка».
- История: счётчик, три фильтра, таблица на desktop / карточки на mobile.
- «Повторить» — вторичная кнопка в строке; новая сверка появляется сверху.

## Состояния

`S-RUN-*` и `S-HIST-*` из `state-matrix.json`: default, GK selected, SK
loading/empty/error, file selected/invalid, validating, validation errors,
submitting, submit error; history loading/empty/error/ready/filter-empty,
repeat pending/error. Плюс `S-GLOBAL-UNAUTHORIZED`, `S-GLOBAL-HR-FORBIDDEN`.

Ключевые различия: «Сверок пока нет» (I1 истории) ≠ «По выбранным фильтрам
сверок нет»; ошибка валидации сохраняет ГК/СК/файл.

## DS

Reuse: card, button, button-secondary, input, error, notes-header, states
loading/empty/search-empty. Gaps: select, upload, status chip, link, layout,
small type, progress, metadata list — `design/ds-gaps.md`.

## Non-goals

Удаление и сравнение сверок, модальные окна, toast, кастомные dropdown,
изменение DS.
