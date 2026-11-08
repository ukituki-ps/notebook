# DS pin evidence — f-v4-note-search (s02a.ds_pin)

- Execution: E0809, step `s02a.ds_pin`
- Branch: `dev/f-v4-note-search-e2e`
- Design system: **Notebook DS 1.0.0** (approved)
- Pinned artifact: `doc/идеи/f-v4-note-search/ds-pin.json`
- Verified at: 2026-11-08T14:02:32Z
- DS source is **`web/`** (`web/app.css`, `web/app.js`, `web/index.html`). **Not** Kubiki. `frontend/src/ui/kit` was not read and is not a DS source for this feature.

## 1. Release manifest verification

Source: `design/releases/1.0.0/manifest.json` (bytes hashed from the working tree; working tree is clean, so these equal the `ds/v1.0.0` blobs).

| Field | Manifest value | Observed / recomputed | Result |
|---|---|---|---|
| `release` | `1.0.0` | `1.0.0` | OK |
| `tag` | `ds/v1.0.0` | tag `ds/v1.0.0` exists, resolves to `9f9c5d6aadebfb70a74bb9883817ac24975710d5` | OK |
| `digest` | `sha256:02f027a86bbf8993bd1c14bbb91d5c3ba4453f47e886be73487a28d2044dda3d` | same string in manifest; used verbatim as `ds_digest` in the pin | OK (declared) |
| `tokens.sha256` | `sha256:9cca3164b76bcc2d648143cbccfc563503df046563a3cb81044fede5e4964068` | `sha256sum design/tokens.json` = `9cca3164b76bcc2d648143cbccfc563503df046563a3cb81044fede5e4964068` | **OK — matches** |
| `registry.sha256` | `sha256:c2d4c3ae3ff5fb5293ecbd6e27444504fcb903c5be80b92df67a0ca9eed3d9d1` | `sha256sum design/registry.json` = `c2d4c3ae3ff5fb5293ecbd6e27444504fcb903c5be80b92df67a0ca9eed3d9d1` | **OK — matches** |
| `code.path` | `web` | `web/` exists; DS code path is web | OK |
| `code.sha256` | `sha256:5f032e0a84204a04a5c83e92f32d29ebafef9ae4b8d42ae8742520b8fd44587b` | not reproducible from the `web/` tree: neither `cc4218a` nor `ds/v1.0.0` web trees, nor concatenations of their per-file sha256s, produce this value; no hashing formula for `code.sha256` is documented in the repo | NOTE — declared value, derivation undocumented |
| `commit` | `cc4218a50ca9fb2065e634a8863174bd8cd16ffe` | commit `cc4218a` exists ("docs(f-v4-note-search): s03b human approval v1") and is the **parent** of the tag commit `9f9c5d6`; the tag commit itself modified `web/app.css` (+9/−6) | NOTE — factual: `commit` is the pre-tag snapshot, not the tag commit |
| `kit.sha256` | `sha256:d0867da377fb1cf09da93003f2e9cff1aad70041e17f44ef24c1cf81feea7a09` | S3 kit not fetched; not verifiable in this step | NOT VERIFIED (out of scope) |

Raw file hashes observed:

```
9cca3164b76bcc2d648143cbccfc563503df046563a3cb81044fede5e4964068  design/tokens.json
c2d4c3ae3ff5fb5293ecbd6e27444504fcb903c5be80b92df67a0ca9eed3d9d1  design/registry.json
72e26a2d354cb67b5d24c5974ee20442a5b607bf883ac4d89ebcc3549ef79bf2  design/releases/1.0.0/manifest.json
```

The manifest's own file sha256 (`72e26a2d…`) is **not** the release `digest`. The release `digest` is an opaque release-level value: it is not `sha256` of the manifest bytes (whole or with the `digest` field removed), nor a canonical-JSON serialization, nor a concatenation of the `tokens`/`registry`/`kit`/`code` hashes. Its derivation is not documented in this repo. This does not block the pin: the pinned value is exactly the value declared in the approved manifest, and both component hashes that the s03 design work consumes (`tokens.json`, `registry.json`) verify byte-for-byte.

Additional doc drift (non-blocking): `design/README.md` says the tag is `ds/notebook-1.0.0`, while the manifest and the actual git tag are `ds/v1.0.0`. `ds/v1.0.0` is what was verified and pinned.

## 2. Pin

`doc/идеи/f-v4-note-search/ds-pin.json`:

- `design_system_version` = `1.0.0`
- `ds_digest` = `sha256:02f027a86bbf8993bd1c14bbb91d5c3ba4453f47e886be73487a28d2044dda3d` (exact value observed in the manifest)
- `approved_by` = `team-lead` (per step input)
- `fallback_used` = `false`
- one screen: `note-search`, platform `web`, profile `full`, same version/digest

## 3. Tokens vs `web/app.css` — factual comparison

Token values: `design/tokens.json`. CSS values: `web/app.css` (line references below). DS is extracted from `web/app.css`; CSS is the implementation under comparison.

### Colors

| Token | Token value | CSS variable / usage | CSS value | Result |
|---|---|---|---|---|
| `color.bg` | `#F4F6F8` | `--bg` (L3), `body background` L30 | `#f4f6f8` | match (case only) |
| `color.card` | `#FFFFFF` | `--card` (L4), L46/L77/L234 | `#ffffff` | match (case only) |
| `color.text` | `#1F2328` | `--text` (L5), L31/L78 | `#1f2328` | match (case only) |
| `color.muted` | `#5B6470` | `--muted` (L6), L141/L150/L169 | `#5b6470` | match (case only) |
| `color.border` | `#8A837C` | `--border` (L7), card/input/borders L47/L75/L160/L176/L232/L251 | `#8a837c` | match (case only) |
| `color.border_subtle` | `#D0D7DE` | `--border-subtle` (L8) | `#d0d7de` defined but **never referenced** | value match; **unused token** |
| `color.accent` | `#1F6FEB` | `--accent` (L9), button L103, links L145 | `#1f6feb` | match (case only) |
| `color.accent_hover` | `#1554B8` | `--accent-dark` (L10), `button:hover` L110 | `#1554b8` | value match; **name drift** (`accent_hover` vs `accent-dark`) |
| `color.danger` | `#B42318` | `--danger` (L11), L91/L131/L134/L251/L252 | `#b42318` | match (case only) |
| `color.danger_bg` | `#FEF3F2` | `--danger-bg` (L12), L92/L133/L256 | `#fef3f2` | match (case only) |
| `color.focus` | `#1F6FEB` | `--focus` (L15), `:focus-visible` L119 | `#1f6feb` | match (case only) |

### Radius / control / typography

| Token | Token value | CSS evidence | Result |
|---|---|---|---|
| `radius.md` | `10px` | `--radius: 10px` (L13), `.card` `border-radius: var(--radius)` (L48) | match |
| `radius.sm` | `8px` | literal `border-radius: 8px` on input/textarea (L76), button (L102), `.error` (L132), `.note-item` (L233) | value match, but **not tokenized** (no `--radius-sm`; hard-coded 4×) |
| `control.height` | `44px` | `--control-height: 44px` (L14), inputs (L73), buttons (L99) | match |
| `focus.width` / `focus.offset` | `3px` / `2px` | `outline: 3px solid var(--focus)` (L119), `outline-offset: 2px` (L120) | match |
| `font.family` | `system-ui, -apple-system, "Segoe UI", Roboto, Arial, sans-serif` | `body { font-family: … }` (L29) | **exact match** |
| `font.h1` | `22px` | `h1 { font-size: 1.4rem }` (L53) → 22.4px at 16px root; `.brand` is `1.2rem` (L164) → 19.2px | **DRIFT: 22.4px rendered vs 22px token** |
| `font.body` | `15px` | no `font-size` on `body` (L28–33) → browser default 16px | **DRIFT: 16px rendered vs 15px token** |
| `font.secondary` | `13px` | no `13px` font-size anywhere in `app.css` (only `1.4rem`, `1.2rem`) | **DRIFT: token not applied** |
| `space.*` | `4/8/12/16/24/32px` | CSS uses off-scale values: `6px` (L60), `10px` (L74/L100/L130/L224/L231), `14px` (L60), `18px` (L125), `20px` (L49), `48px` (L38), `88px` (L83) | **DRIFT: off-scale spacing used; `space.1` (4px) has no usage found** |

## 4. Drift list (consolidated)

1. **Typography drift (real, visible):** tokens declare h1 `22px`, body `15px`, secondary `13px`; CSS renders h1 at `1.4rem` (22.4px), body at browser default 16px, and never applies 15px or 13px. `font.secondary` (`13px`) has no consumer in `web/app.css`.
2. **`color.border_subtle` (`#D0D7DE`):** defined as `--border-subtle` but referenced nowhere. Declared-but-unapplied token.
3. **`color.accent_hover` naming:** token key `accent_hover` maps to CSS `--accent-dark`; values are identical (`#1554B8` / `#1554b8`), only the name differs.
4. **`radius.sm` not tokenized:** `8px` is correct but hard-coded in 4 rules; only `radius.md` is a CSS variable.
5. **Spacing off-scale:** component padding/margins use 6/10/14/18/20/48/88px, outside the declared 4/8/12/16/24/32 scale.
6. **Manifest `commit` vs tag commit:** `commit` is `cc4218a` (parent); the tag `ds/v1.0.0` points to `9f9c5d6`, which also edited `web/app.css`. The `commit` field is therefore a pre-tag snapshot, not the tag's commit.
7. **Manifest `code.sha256` not reproducible** from either `web/` tree with any obvious concatenation; derivation undocumented. No formula stated in `design/`.
8. **README tag name drift:** `design/README.md` says `ds/notebook-1.0.0`; actual/manifest tag is `ds/v1.0.0`.

None of items 1–8 change the `ds_digest`, which is taken verbatim from the approved manifest, and none of them invalidate the pin. Items 1–5 are s03 mapping inputs: search UI must use the existing `web/app.css` values/styles and must not invent new tokens; token gaps go to DS as proposals rather than ad-hoc values.

## 5. Verification result

**OK with drift notes.** `release=1.0.0`, `tag=ds/v1.0.0` present, `tokens.json` and `registry.json` sha256 match the manifest exactly, `code.path=web`. The pinned `ds_digest` observed in the manifest is exactly:

```
sha256:02f027a86bbf8993bd1c14bbb91d5c3ba4453f47e886be73487a28d2044dda3d
```

No files under `design/`, `web/` or application code were modified by this step. No commit was made, and no approval is claimed.
