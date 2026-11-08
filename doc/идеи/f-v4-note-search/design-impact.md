---
schema_version: "1.0"
feature_id: f-v4-note-search
ds_release: "1.0.0"
ds_digest: sha256:02f027a86bbf8993bd1c14bbb91d5c3ba4453f47e886be73487a28d2044dda3d
ds_lock: ds.lock.json
component_refs: component-refs.json
component_map: component-map.yaml
review_fragment: design-review.fragment.json
screens: [note-search]
path6_requests: [n-count, n-delete]
---

# Design impact — f-v4-note-search

- Execution E0809 · step `s03a.design_integrate` · screen `note-search`
- Pinned Design System: **Notebook DS 1.0.0** (`ds/v1.0.0`); constraint `=1.0.0`
- `ds_digest`: `sha256:02f027a86bbf8993bd1c14bbb91d5c3ba4453f47e886be73487a28d2044dda3d`
- Release manifest: `design/releases/1.0.0/manifest.json` — `sha256:72e26a2d354cb67b5d24c5974ee20442a5b607bf883ac4d89ebcc3549ef79bf2`
- Unit input: `doc/идеи/f-v4-note-search/units/note-search/`
- Prototype: `doc/идеи/f-v4-note-search/units/note-search/proto.html`

## DS impact

**None to the Design System.** This step creates feature-level design-contract artifacts only. No files under `design/`, `web/`, or any application code are modified; no commit is made. There is no new DS release: the feature is locked to Notebook DS 1.0.0 (`=1.0.0`), the only release in scope. Kubiki is not used; `web/app.css` remains the DS implementation under comparison.

The unit (`note-search`) and the feature aggregate share `design_system_version = 1.0.0` and the same `ds_digest`; exactly one feature `ds.lock.json` is emitted.

## Reused registry components

12 registry ids from `design/registry.json` 1.0.0 are actually used (verbatim ids, nothing invented):

- `primitives/button` — Add, retry, offline-check, generic buttons (`n-button`, `n-note-add`, `n-retry`, `n-offline-check`)
- `primitives/input` — search `<input>` composed inside `patterns/search-field` (`n-search-field`)
- `primitives/textarea` — note composer (`n-note-textarea`)
- `primitives/error` — load/error alert (`n-error`)
- `patterns/notes-header` — header (`n-notes-header`)
- `patterns/notes-list` — list container (`n-notes-list`)
- `patterns/note-item` — note row and offline banner (`n-note-item`, `n-offline`)
- `patterns/search-field` — search row (`n-search-field`)
- `patterns/search-clear` — clear control (`n-search-clear`)
- `states/loading` — loading message (`n-loading`)
- `states/empty` — base empty message (`n-empty`)
- `states/search-empty` — no-results message (`n-search-empty`)

Compositions / reuse without new registry ids:

- `n-note-form` — composition `primitives/textarea` + `primitives/button`; the proto's `patterns/note-form` is not in DS 1.0.0 and is rejected.
- `n-offline` — composition `patterns/note-item` + `primitives/button` (second `note-item` occurrence), not a gap.
- `n-retry`, `n-offline-check` — plain `primitives/button` reuse.

Not counted: `primitives/card` (`.card`) and `primitives/button-secondary` (`.logout`) are present in markup but have no node id and no screen state depends on them.

## Path 6 gaps

- **GAP-1 — `n-count`** (`[data-testid=notes-search-count]`, kind `missing-pattern`, blocking `false`, accepted). The «Найдено N» count label has no registry component in ND DS 1.0.0. It is rendered with existing tokens (`.muted` → `--muted` on `--card`, 6.0:1 AA) and hidden via `[hidden]`; no local CSS. Proposal for DS 1.x: `patterns/count-label`.
- **GAP-3 — `n-delete`** (`.delete-note`, kind `registry-omission`, blocking `false`, accepted). The danger button variant exists in `web/app.css:248-257` (transparent background, `--danger` border/text, `--danger-bg` hover) but is absent from `design/registry.json` 1.0.0. It is used as-is without local CSS or local instance classes; contrast is AA (6.57:1 default, 6.07:1 hover). Proposal for DS 1.x: `primitives/button-danger` or a delete state in `patterns/note-item`.
- **GAP-2 — `n-search-field` `input` disabled state** (kind `missing-state`, blocking `false`, accepted, not path6-required). `primitives/input` declares default/focus/invalid but no visual `disabled` state. The screen uses native `disabled`, `aria-disabled="true"`, and `aria-describedby` to the visible status; appearance falls back to the UA style. Proposal for DS 1.x: add `disabled` to `primitives/input`.

`path6_required = [n-count, n-delete]` — this exactly matches the front matter `path6_requests`, `component-refs.path6_required`, and `design-gaps.path6_required`.

## Local instances

**0 local instances.** No local `<style>` block, no local CSS, no local instance classes; the prototype uses only Notebook DS classes/tokens from `web/app.css` and `design/tokens.json`. `component-refs.screens[].local_instances` and `summary.local_instances` are empty/0.

## Residual token drift (from ds-pin-evidence)

The following drift is recorded and accepted for this feature; it does not change the pinned digest and no DS file is edited here:

1. Typography: `font.h1` 22px vs `h1` 1.4rem (22.4px); `font.body` 15px vs browser default 16px; `font.secondary` 13px unused.
2. `color.border_subtle` (`#D0D7DE`) is declared as `--border-subtle` but never referenced.
3. `color.accent_hover` maps to CSS `--accent-dark`: values match, name differs.
4. `radius.sm` 8px is correct but hardcoded in four rules, not exposed as a CSS variable.
5. Spacing uses off-scale values (6/10/14/18/20/48/88px) outside the 4/8/12/16/24/32 scale.
6. Provenance notes (non-blocking, no digest change): manifest `code.sha256` derivation undocumented; manifest `commit` is the pre-tag snapshot; `design/README.md` tag name differs from `ds/v1.0.0`.

## Artifacts

- `visualized-brief.md`
- `design-impact.md` (this file)
- `ds.lock.json`
- `component-refs.json`
- `component-map.yaml`
- `design-gaps.json`
- `design-review.fragment.json`
