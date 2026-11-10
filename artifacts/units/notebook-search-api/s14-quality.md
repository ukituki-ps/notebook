# s14 unit quality — notebook-search-api (crutch density)

- Execution: E6636 (E6636-s20.sde_5fexecution-u01), unit `notebook-search-api`
- Step: s14.unit_quality (architect)
- HEAD under check: d679af62cd4dca9de06c01fda78976e059c2a100
- Base for comparison: 1722a1e5
- Evidence: PR-6339efb0495c, exit 0 (sha256:a40d4c7dae266e367afe14c4ce755b9a3090789530abbf259f12b94831199431)

## Метрика

Crutch-маркеры (игнорирование/обход проверок и отсрочка):
`t.Skip|SkipNow|Skipf|waiver|--force|//nolint|go:build ignore|TODO|FIXME|HACK|XXX|time.Sleep`.
Считаются строки-совпадения в `main.go` + `main_test.go`.

| Ref | main.go | main_test.go | Всего строк | Crutch lines | Density |
|---|---|---|---|---|---|
| base 1722a1e | 0 / 604 | 0 / 1157 | 1761 | 0 | 0.00 |
| HEAD d679af6 | 0 / 604 | 0 / 1204 | 1808 | 0 | 0.00 |

Добавленные строки (`git diff 1722a1e..HEAD -- main.go main_test.go`, +47): 0 crutch-маркеров.

## Прочие quality-признаки

| Check | Result |
|---|---|
| `main.go` изменён | нет (продуктовый код не тронут) |
| `go.mod` / `go.sum` изменены | нет (новых зависимостей нет) |
| новые файлы вне тестов/артефактов | нет (+47 строк только в `main_test.go`) |
| skip/focus в тестах | 0 |
| тестовые ожидания | явные `t.Fatalf` с телом ответа; без «мягких» assert |
| build / full test | PASS (8.860s) |
| time.Sleep в тестах | 0 (нет флаки-подпорок) |

## Вердикт

`crutch_density_grew: false` — плотность 0.00 на base и на HEAD; новых обходов,
скипов, вейверов, временных костылей и зависимостей не появилось.
