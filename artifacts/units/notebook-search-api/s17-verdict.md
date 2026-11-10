# s17 unit verdict — notebook-search-api (machine outcome)

- Execution: E6636 (E6636-s20.sde_5fexecution-u01)
- Step: s17.unit_verdict (orc, C-14)
- HEAD: 62e25b990351e2babb91b914a3d91346f928ecf6
- Base: 1722a1e5

## Машиночитаемые входы (гейты предыдущих шагов)

| Step | Field | Value | Источник |
|---|---|---|---|
| s12.unit_check | `fixed_confirmed` | **true** | PR-e2bc2c8e97e9 |
| s14.unit_quality | `crutch_density_grew` | **false** | PR-6339efb0495c |
| s15.unit_regression | `new_findings` | **[]** | PR-eac6aef69ac7 |
| s16.unit_spec_sync | `synced` | **true** | PR-427f687b0369 |

## Правило вывода

```
outcome = clean        если fixed_confirmed && !crutch_density_grew
                            && new_findings is empty && synced
        = new_findings если есть новые находки регрессии
        = not_clean    иначе
```

Все четыре условия выполнены → `clean`.

## Сводка юнита

- Контракт `GET /api/notes?q=` подтверждён независимо (s13 pass): auth 401 →
  cap 512 B до скана (ровно 512 — 200, 513+ — 400 `query too long`) →
  owner-scoped `ListNotes` → case-insensitive trim-фильтр; `[]` не `null`;
  `UserID json:"-"`.
- Дельта: `main_test.go` +3 теста (trim, empty-store, cross-owner unique term);
  `main.go` не изменён; спека синхронизирована (drift `TestNotesList` устранён).
- Открытые находки CR-1..3 / RT-1..2 относятся к `notebook.delete-note`, не к
  этому юниту; в этой дельте новых нет.

## Итог

**outcome: clean** — юнит `notebook-search-api` готов к s18.unit_merge_unit.
