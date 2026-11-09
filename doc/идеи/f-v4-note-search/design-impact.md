---
schema_version: "1.0"
execution: "E4138"
revalidated_at: "2026-11-09T22:07:00Z"
feature_id: f-v4-note-search
ds_release: "1.0.1"
ds_digest: sha256:4e0ef1052a1401a928588445f921f7d231b7c0e7c9b10c181fdbbb439108c85e
ds_lock: ds.lock.json
component_refs: component-refs.json
component_map: component-map.yaml
review_fragment: design-review.fragment.json
screens: [note-search]
path6_requests: [n-count, n-delete]
---

# Design impact — f-v4-note-search

- New run `path-1.feature@4.0.0` · step `s03a.design_integrate` · screen `note-search` · execution **E4138**
- Pinned Design System: **Notebook DS 1.0.1** (`ds/v1.0.1`); constraint `=1.0.1`
- `ds_digest`: `sha256:4e0ef1052a1401a928588445f921f7d231b7c0e7c9b10c181fdbbb439108c85e`
- Release manifest: `design/releases/1.0.1/manifest.json` — `sha256:dbc2983b548da8fbce8c860e8c6cff745b517dfd44caaf564a077a913c93e29b`
- Unit input: `doc/идеи/f-v4-note-search/units/note-search/`
- Prototype: `doc/идеи/f-v4-note-search/units/note-search/proto.html`

## DS impact

**None to the Design System.** This step creates feature-level design-contract artifacts only. No files under `design/`, `web/`, or any application code are modified; no commit is made. There is no new DS release: the feature is locked to Notebook DS 1.0.1 (`=1.0.1`), the current approved release. Kubiki is not used; `web/app.css` remains the DS implementation under comparison.

The unit (`note-search`) and the feature aggregate share `design_system_version = 1.0.1` and the same `ds_digest`; exactly one feature `ds.lock.json` is emitted.

## Reused registry components

12 registry ids from `design/registry.json` 1.0.1 are actually used (verbatim ids, nothing invented):

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

- `n-note-form` — composition `primitives/textarea` + `primitives/button`; the proto's `patterns/note-form` is not in DS 1.0.1 and is rejected.
- `n-offline` — composition `patterns/note-item` + `primitives/button` (second `note-item` occurrence), not a gap.
- `n-retry`, `n-offline-check` — plain `primitives/button` reuse.

Not counted: `primitives/card` (`.card`) and `primitives/button-secondary` (`.logout`) are present in markup but have no node id and no screen state depends on them.

## Path 6 gaps

- **GAP-1 — `n-count`** (`[data-testid=notes-search-count]`, kind `missing-pattern`, blocking `false`, accepted). The «Найдено N» count label has no registry component in Notebook DS 1.0.1. It is rendered with existing tokens (`.muted` → `--muted` on `--card`, 6.0:1 AA) and hidden via `[hidden]`; no local CSS. Proposal for DS 1.x: `patterns/count-label`.
- **GAP-3 — `n-delete`** (`.delete-note`, kind `registry-omission`, blocking `false`, accepted). The danger button variant exists in `web/app.css:248-257` (transparent background, `--danger` border/text, `--danger-bg` hover) but is absent from `design/registry.json` 1.0.1. It is used as-is without local CSS or local instance classes; contrast is AA (6.57:1 default, 6.07:1 hover). Proposal for DS 1.x: `primitives/button-danger` or a delete state in `patterns/note-item`.
- **GAP-2 — `n-search-field` `input` disabled state** (kind `missing-state`, blocking `false`, accepted, not path6-required). `primitives/input` declares default/focus/invalid but no visual `disabled` state. The screen uses native `disabled`, `aria-disabled="true"`, and `aria-describedby` to the visible status; appearance falls back to the UA style. Proposal for DS 1.x: add `disabled` to `primitives/input`.

`path6_required = [n-count, n-delete]` — this exactly matches the front matter `path6_requests`, `component-refs.path6_required`, and `design-gaps.path6_required`.

## Local instances

**0 local instances.** No local `<style>` block, no local CSS, no local instance classes; the prototype uses only Notebook DS classes/tokens from `web/app.css` and `design/tokens.json`. `component-refs.screens[].local_instances` and `summary.local_instances` are empty/0.

## Token alignment (DS 1.0.1)

DS 1.0.1 fixes the token drift that 1.0.0 accepted:

1. `font.h1` is now `22.4px` (matches `h1 { font-size: 1.4rem }`).
2. `font.brand` is now `19.2px` (matches `.brand { font-size: 1.2rem }`).
3. `font.body` is now `16px` (matches `body { font-size: 16px }`).
4. `control.textarea` is now `88px` (matches `textarea { min-height: 88px }`).

`tools/check-ds-token-drift.py` verifies 20 token checks and passes on
`web/app.css`; the gate is wired into s22a and s24.

## Remaining residuals (explicit, non-blocking)

1. Registry omissions: `.delete-note` (GAP-3) plus `.brand`, `.user-name`,
   `.note-text`, `.notes-search-row`, `.muted` are real `web/app.css` classes
   with no `design/registry.json` entry. They are DS code, not local
   instances; tracked as registry gaps for DS 1.x.
2. `primitives/input` has no visual `disabled` state (GAP-2); the screen uses
   native disabled + `aria-disabled` + `aria-describedby`.
3. `radius.sm` (8px) is hardcoded in four rules instead of a CSS variable.
4. Spacing still uses off-scale values (6/10/14/18/20/48px) outside the
   4/8/12/16/24/32 scale.
5. `control.height` is a minimum: Chromium renders a 45px control because
   line-height + padding + border exceed 44px; the token contract is
   `min-height`, and `ds-token-drift` checks the declared value; Chromium
   renders textarea at 92px (rows=3) against the 88px minimum. Exact 44/88px
   would require a DS 1.0.2 change.
6. Provenance: release manifest `commit` records the pre-tag snapshot
   (`41a1141`); tag `ds/v1.0.1` resolves to `773acb1`. The manifest digest is
   frozen and is not edited.

## Artifacts

- `visualized-brief.md`
- `design-impact.md` (this file)
- `prototypes/v7/manifest.json`, `prototypes/v7/prototype-review.json`, `prototypes/v7/exports/*.png`
- `ds.lock.json`
- `component-refs.json`
- `component-map.yaml`
- `design-gaps.json`
- `design-review.fragment.json`
