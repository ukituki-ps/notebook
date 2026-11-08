# E6816 design-unit note-search — proto/state matrix

- base_sha: `8d522f782b566156dc650257e7bbc4d5e2922264`
- unit: `s03.proto_visualize#note-search`
- DS: Notebook DS 1.0.1 (`sha256:4e0ef105…`)
- proto: `units/note-search/proto.html` (`?state=idle|results|no-results|empty|loading|error|offline|offline-zero`)
- state matrix: `units/note-search/state-matrix.md` (8 renderable states + `normal` alias)
- exports: `prototypes/v7/exports/` (16 frames, 8 states x 390/1200)
- gate: `unit-proto-coverage --screen note-search` PASS.

No new UI components; only Notebook DS registry classes/tokens, no local CSS.

## s04a.unit_ds_resolve

- ds-lock/component-map/component-refs pinned to DS 1.0.1 (`sha256:4e0ef105…`), constraint `=1.0.1`.
- registry: 14 components, 12 used + GAP-1/GAP-3 path6-required, GAP-2 missing disabled state, GAP-4 registry omissions.
- gate: `unit-ds-lock --screen note-search` PASS.
