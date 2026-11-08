# Visualized brief — f-v4-note-search

- Feature: `f-v4-note-search` · Execution E0809 · step `s03a.design_integrate`
- Screen: `note-search` (one screen; login/register unchanged)
- Platform: `web` · feature profile: `full` · branch `dev/f-v4-note-search-e2e`
- Design system: **Notebook DS 1.0.0** (`ds/v1.0.0`), pinned in `ds-pin.json`
- `ds_digest`: `sha256:02f027a86bbf8993bd1c14bbb91d5c3ba4453f47e886be73487a28d2044dda3d`
- Release manifest: `design/releases/1.0.0/manifest.json` (`sha256:72e26a2d354cb67b5d24c5974ee20442a5b607bf883ac4d89ebcc3549ef79bf2`)
- DS sources: `design/tokens.json`, `design/registry.json`, implementation `web/app.css`. No Kubiki, no `frontend/src/ui/kit`, no v6 imports.
- Prototype: `doc/идеи/f-v4-note-search/units/note-search/proto.html` (`?state=<state>`, one state per render)
- Design-unit: `doc/идеи/f-v4-note-search/units/note-search/`

## States

The screen has **7 renderable states** plus the `normal` alias of `idle` (8 names in `proto.json`). The note creation form (visible label «Новая заметка», textarea, `Add`) stays visible above the search field in every state. Count «Найдено N» (`aria-live="polite"`) is visible only in `results` / `no-results`.

| State | Rendered content | Query / primary action | Export evidence |
|---|---|---|---|
| `normal` (alias of `idle`) | Note form; empty search; all 4 loaded notes with «Удалить»; clear and count hidden. | Empty query. | `exports/export-390-idle.png`, `exports/export-1200-idle.png` |
| `idle` | Same as `normal`: note form, labelled search field, all 4 loaded notes (2 match «план», 2 do not), per-row delete; clear/count hidden. | Empty query; type, add, or delete. | `exports/export-390-idle.png`, `exports/export-1200-idle.png` |
| `results` | Note form; query «план»; clear visible; count «Найдено 2»; exactly 2 matching rows with «Удалить». | Client-side filter of the loaded owner-scoped list. | `exports/export-390-results.png`, `exports/export-1200-results.png` |
| `no-results` | Note form; query «отпуск»; clear visible; count «Найдено 0»; list hidden; message «Ничего не найдено. Сократите запрос или очистите поиск.» (`role="status" aria-live="polite"`). | Clear or broaden the query. | `exports/export-390-no-results.png`, `exports/export-1200-no-results.png` |
| `empty` | Note form; empty query; list hidden; muted message «Пока нет заметок. Добавьте первую выше.»; clear/count hidden. | Add the first note. | `exports/export-390-empty.png`, `exports/export-1200-empty.png` |
| `loading` | Note form; muted «Загрузка...» (`role="status" aria-live="polite"`); search disabled via native `disabled` + `aria-disabled="true"` + `aria-describedby="notes-loading"`; count/list hidden; list `aria-busy="true"`. | Wait for the notes request. | `exports/export-390-loading.png`, `exports/export-1200-loading.png` |
| `error` | Note form; `.error` alert «Не удалось загрузить заметки. Попробуйте ещё раз.» (`role="alert"`) + «Повторить»; search disabled with `aria-describedby="notes-error"`; count/list hidden. | Press «Повторить». | `exports/export-390-error.png`, `exports/export-1200-error.png` |
| `offline` | Note form; offline banner composed from DS `.note-item` (`role="status"`) with muted «Нет сети — показаны загруженные заметки.» + single-line 44px «Проверить сеть»; search disabled with placeholder «Поиск недоступен без сети»; count hidden; all 4 loaded notes with «Удалить» visible. | Re-check connectivity or delete a loaded note. | `exports/export-390-offline.png`, `exports/export-1200-offline.png` |

State matrix detail: `units/note-search/state-matrix.md`. Machine-readable states/nodes: `units/note-search/proto.json`.

## Layout — 390 / 1200

- Shared implementation: `web/app.css` `.app` max-width 640px, `.card`, 640px media query. The design does not invent a second grid or local CSS.
- **390px:** single centered column; `.app` padding 16px 12px 32px; card padding 16px; inputs/buttons full width at `44px` min height; search row stacks; note rows stack with a full-width danger delete. Measured content 12..376 (no horizontal overflow; `scrollWidth == clientWidth == 390`).
- **1200px:** centered 640px column/card; search row inline (input + clear); note rows inline (text + delete). Measured content 296..902; offline accent button 168×45px on one line.
- Vertical scroll exists only at 390 with real rows (idle ≈926px, offline ≈1067px at an 844px viewport); no horizontal scroll at either width.

## Component list (Notebook DS 1.0.0)

12 registry components are actually used (all ids verbatim from `design/registry.json`):

| Registry id | Selector | Nodes | States |
|---|---|---|---|
| `primitives/button` | `button` | `n-button`, `n-note-add`, `n-retry`, `n-offline-check` | default, hover, focus, disabled |
| `primitives/input` | `input` | composed in `n-search-field` | default, focus, invalid (no disabled state — GAP-2) |
| `primitives/textarea` | `textarea` | `n-note-textarea` | default, focus, invalid |
| `primitives/error` | `.error` | `n-error` | default |
| `patterns/notes-header` | `.notes-header` | `n-notes-header` | default |
| `patterns/notes-list` | `.notes-list` | `n-notes-list` | default |
| `patterns/note-item` | `.note-item` | `n-note-item`, `n-offline` | default, pending |
| `patterns/search-field` | `.notes-search` | `n-search-field` | default, focus |
| `patterns/search-clear` | `.notes-search-clear` | `n-search-clear` | default, focus |
| `states/loading` | `[data-testid="notes-loading"]` | `n-loading` | loading |
| `states/empty` | `[data-testid="notes-empty"]` | `n-empty` | empty |
| `states/search-empty` | `[data-testid="notes-search-empty"]` | `n-search-empty` | empty |

Compositions and reuse:

- `n-note-form` (`.note-form`): composition of `primitives/textarea` + `primitives/button`; no registry id (proto's `patterns/note-form` is not in DS 1.0.0).
- `n-offline`: composition `patterns/note-item` + `primitives/button` (second `note-item` occurrence, not a separate pattern).
- `n-retry`, `n-offline-check`: reuse `primitives/button`; no dedicated components.
- Not counted: `.card` (`primitives/card`) and `.logout` (`primitives/button-secondary`) exist in markup but have no `node_id` and no screen state depends on them.

Total node model: **18 nodes**. `registry_components`: **12**. `local_instances`: **0** (no local CSS, no local instance classes).

## Path 6 / design gaps

| Gap | Node | Kind | Blocking | Status | Disposition |
|---|---|---|---|---|---|
| `GAP-1` | `n-count` (`[data-testid=notes-search-count]`) | missing pattern | false | accepted | Count label has no registry component; rendered with `.muted` tokens, hidden via `[hidden]`. Candidate `patterns/count-label` for DS 1.x. |
| `GAP-3` | `n-delete` (`.delete-note`) | registry omission | false | accepted | Danger variant exists in `web/app.css:248-257` but is absent from `design/registry.json`; used as-is, no local CSS. Candidate `primitives/button-danger` for DS 1.x. |
| `GAP-2` | `n-search-field` (`input`) | missing state | false | accepted | `primitives/input` has no visual `disabled` state; the screen uses native disabled + `aria-disabled` + `aria-describedby`, UA styling only. Candidate DS 1.x state. |

`path6_required` = `["n-count", "n-delete"]`. `GAP-2` is a missing DS state, not a path6-required node.

## Reviews

| Review | Session | Verdict | Blockers | Majors | Minors |
|---|---|---|---|---|---|
| UI (`designer`) | `ses_e44805f58ffeQQzurMGcmR2JRm` | **accept** | 0 | 0 | 2 |
| UX (`product-ux`) | `ses_e446e93b4ffe3yWt9AYmiK6bbm` | **accept** | 0 | 0 | 7 |

Author session: `ses_e44864e8affeXebq0BijhUo077`. Combined summary: **accept, 0 blockers, 0 majors**; residual minors are documented in `design-review.fragment.json` (open items are s20 implementation notes, not DS blockers).

## Residual token drift (from `ds-pin-evidence.md`)

Not fixed at s03a and not blocking; no DS/ files are edited:

1. Typography drift: `font.h1` 22px vs `h1` 1.4rem (22.4px); `font.body` 15px vs browser default 16px; `font.secondary` 13px has no consumer.
2. `color.border_subtle` (`#D0D7DE`) is declared as `--border-subtle` but never referenced.
3. `color.accent_hover` maps to CSS `--accent-dark` (values match; name drift only).
4. `radius.sm` (8px) is correct but hardcoded in four CSS rules, not tokenized.
5. Spacing uses off-scale values (6/10/14/18/20/48/88px) outside the declared 4/8/12/16/24/32 scale.
6. Manifest provenance notes: `code.sha256` derivation undocumented; `commit` is the pre-tag snapshot; `design/README.md` tag name differs. These do not change the pinned `ds_digest`.

## Constraints

- DS release is **1.0.0 only**; no Kubiki.
- No changes under `design/`, `web/`, or application code by this step; no commit.
- Feature-level artifacts: `design-impact.md`, `ds.lock.json`, `component-refs.json`, `component-map.yaml`, `design-gaps.json`, `design-review.fragment.json` (this file is `visualized-brief.md`).
