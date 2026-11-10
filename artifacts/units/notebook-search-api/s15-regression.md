# s15 unit regression — notebook-search-api

- Execution: E6636 (E6636-s20.sde_5fexecution-u01), unit `notebook-search-api`
- Step: s15.unit_regression (auditor)
- HEAD: effe113474e421f63bbd94ec32dc73177469d05e
- Base: 1722a1e5
- Evidence: PR-eac6aef69ac7, exit 0 (sha256:6c2b80a122856c42d94dd27f8e3b97fd64f8ce4524e4510b8a789ec186d9ddee)

## Что проверялось

Регрессия от тестовой дельты юнита: не сломаны ли существующие тесты/поведение,
не удалены ли/ослаблены ли тесты, нет ли зависимости от порядка исполнения.

| Check | Command | Result |
|---|---|---|
| build | `GOWORK=off go build ./...` | PASS |
| vet | `GOWORK=off go vet ./...` | PASS |
| full suite | `go test -count=1 ./...` | ok, 8.831s |
| shuffled suite | `go test -count=1 -shuffle=on ./...` | ok, 8.844s (порядок не влияет) |
| main.go vs base | `git diff 1722a1e..HEAD -- main.go` | пусто (поведение не менялось) |
| удалённые тест-функции | `git diff ... | grep '^-func Test'` | 0 |
| удалённые строки в main_test.go | `git diff --numstat` deletions | 0 |
| инвентарь тестов | base 32 → HEAD 35 | только добавления |

## Дельта

```
47  0  main_test.go     (+3 TestNotesSearch*: TrimsQuery, EmptyStore, DoesNotMatchOtherOwner)
```

Единственный изменённый non-test Go-файл отсутствует; `main.go`, `go.mod`, `go.sum`
и прочие `.go` вне `main_test.go` не тронуты. Существующие тесты (auth, notes CRUD,
delete, wire contract, healthz) проходят без изменений и в обычном, и в shuffled режиме.

## Новые находки

`new_findings: []` — регрессий и новых дефектов не обнаружено.
Ранее открытые CR-1..CR-3/RT-1/RT-2 относятся к unit `notebook.delete-note` и не
затрагиваются этой дельтой (не новые, повторно не заводились).
