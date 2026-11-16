# Notebook → path-1.feature@5.0.6

Проект `f41f0adb-67d9-4ddf-8ba9-0efd9c6e50a9` привязан к
`path-1.feature@5.0.6` (active).

## Что это меняет

- Новые execution используют 5.0.6.
- Старые execution на 3.2.2 остаются замороженными; их не переоткрывать.
- Gate bundle платформы: `orc-fe-gates-418-batch-preflight`.

## Профили

### backend / unit_batch

Для backend-фич использовать `entry_point=unit_batch` и
`feature_profile=backend`. Design/OpenPencil-шаги не применяются.

### frontend / full

Полный design-batch 5.0.6 требует:

- OpenPencil canonical;
- design system / DS lock;
- `route-fact-sheets/`;
- `review-packet.json`;
- `batch.json` с `batch_id`/`template_id`;
- project tools `design_gate.py`, `design_snapshot.py`, `check-design-gates.py`
  (добавить до первого frontend execution).

Пока этих артефактов в notebook нет — frontend design-batch не запускать.

## Запуск

Backend:

```text
process=path-1.feature
entry_point=unit_batch
context.work_branch=...
context.unit_briefs=...
project_id=f41f0adb-67d9-4ddf-8ba9-0efd9c6e50a9
```

Frontend design batch — только после добавления design tools/assets.
