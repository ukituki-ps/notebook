# Design System releases

Producer: path-6. Consumer: path-1 `s02a.ds_pin`.

- `tokens.json` — единственный источник токенов.
- `registry.json` — компоненты/паттерны/шаблоны (`registry_id`).
- `releases/<v>/manifest.json` — immutable: hashes, kit S3, code path, quality.
- `releases/<v>/changelog.md`, `provenance.json`.
- Код: `frontend/src/ui/kit`; git tag `ds/v<v>`.
- `.fig` в git не коммитится; S3 URI + sha256 в manifest.
