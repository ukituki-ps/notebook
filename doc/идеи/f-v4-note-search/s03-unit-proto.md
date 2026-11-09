# s03 — Unit proto + state matrix: note-search

- Execution: **E6588-s03.proto_5fvisualize-u01** · step **s03.unit_proto** · role **proto**
- Process: `path-1.feature@4.0.0`, platform `web`, profile `full`
- A/B arm: `path-10`, key `notebook-path10-08`
- Base: `ae5ad02710336b8806f0cffde3ee1e29355b547f` · work branch: `orc-exec-E6588-s03.proto_5fvisualize-u01`
- Feature: `f-v4-note-search` · screen/unit: `note-search`
- DS: Notebook `1.0.1` · `sha256:4e0ef1052a1401a928588445f921f7d231b7c0e7c9b10c181fdbbb439108c85e`
- Screen brief: "Owner-scoped note search over Notebook DS: search field, clear,
  idle/results/empty/loading/error/offline, 390/1200, read-only list with delete."

## Artifacts

| artifact | file | sha256 |
|---|---|---|
| proto + state matrix (machine) | `units/note-search/proto.json` | `a9abd5d2730f61e07d93508b5593a4799112f29e43e1efe8a680553cbf9dd38d` |
| proto (renderable) | `units/note-search/proto.html` | `15d15f11901925a1eef6a05dd487750b95e27608a67e75191e8510d6d14165af` |
| state matrix (human) | `units/note-search/state-matrix.md` | `b586ab73d773ea92b65119340c55d7b25953acd1b21886dc0170710ab6c402cc` |
| component map | `units/note-search/component-map.yaml` | `7f85baece3341c47f3b8d85f50948729b45a7cd958bf070a2aeb68051be659c2` |
| component refs | `units/note-search/component-refs.json` | `e639df580988fa4552da4c76fe6b6886fd5aa5d8162e18c0e999b44d3aff0086` |
| path6 gaps | `units/note-search/design-gaps.json` | `3d0da7f57f1eece4f10a51290df5e799a205a0b85deba325455b46f36ae21e00` |

The prototype renders one state per URL (`proto.html?state=<state>`) with no local
CSS — only Notebook DS classes from `web/app.css`.

## State coverage (screen_brief → proto/state matrix)

| screen_brief state | proto state(s) | note |
|---|---|---|
| idle | `idle` (alias `normal`) | empty query, all loaded notes, Delete per row |
| results | `results` | query «план» → 2 matches, clear + count «Найдено 2» |
| (no matches) | `no-results` | query «отпуск» → count 0, search-empty message |
| empty | `empty` | no notes; search disabled, add-first hint |
| loading | `loading` | status «Загрузка...», list `aria-busy=true` |
| error | `error` | alert + «Повторить», search disabled |
| offline | `offline` | banner + «Проверить сеть», loaded notes read-only (Delete disabled) |
| (domain) | `offline-zero` | no network and no cached notes; distinct from `empty` |

No unlabeled states: `proto.json.states` = normal, idle, results, no-results,
empty, loading, error, offline, offline-zero. `normal` is declared
`alias_of: idle`. Domain states `offline` and `offline-zero` are explicit.

## Component coverage

All 18 `proto.json.nodes[]` have an entry in `component-map.yaml` (and
`component-refs.json`): 16 map to a `design/registry.json` id or an existing
composition; `n-count` and `n-delete` are `path6_required` and tracked as
accepted, non-blocking items in `design-gaps.json`.

## Gate evidence

```
bash tools/path1-gate.sh unit-proto-coverage E6588-s03.proto_5fvisualize-u01 --screen note-search
unit-proto-coverage: PASS
```

- evidence_id: `PR-94f237d859ae`
- evidence sha256: `dc488551439ceb514bbccb221c71fb8b250f2481010b6b019e661a4b10b51012`
- exit_code: 0
