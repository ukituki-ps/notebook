# DS pin evidence — f-v4-note-search (s02a.ds_pin)

- Execution: E6247, step `s02a.ds_pin`
- Branch: `dev/path10-runner-07`, base `9e7fae3`; revalidated at `56c9f61`
  (earlier record: E0809 / `dev/f-v4-note-search-e2e`)
- Design system: **Notebook DS 1.0.1** (approved)
- Pinned artifact: `doc/идеи/f-v4-note-search/ds-pin.json`
- Verified at: 2026-11-09 (E6247 revalidation of the 2026-11-08T18:32:32Z pin)
- DS source is **`web/`** (`web/app.css`, `web/app.js`, `web/index.html`). **Not**
  Kubiki. `frontend/src/ui/kit` was not read and is not a DS source for this feature.

## 1. Release manifest verification

Source: `design/releases/1.0.1/manifest.json` (bytes hashed from the evaluated
tree; the pin, the manifest and the source hashes below were recomputed in this
step).

| Field | Manifest value | Observed / recomputed | Result |
|---|---|---|---|
| `release` | `1.0.1` | `1.0.1` | OK |
| `tag` | `ds/v1.0.1` | tag `ds/v1.0.1` exists; `git rev-parse ds/v1.0.1` = `a392b105…` (tag object, target `773acb1`) | OK (tag exists; see note) |
| `digest` | `sha256:4e0ef1052a1401a928588445f921f7d231b7c0e7c9b10c181fdbbb439108c85e` | same string in the manifest; used verbatim as `ds_digest` in the pin | OK (declared) |
| `tokens.sha256` | `sha256:436af169ef28b64cac108288fae69d4ad6819330ac21ff048936a38af7265afb` | `sha256sum design/tokens.json` = `436af169…` | **OK — matches** |
| `registry.sha256` | `sha256:79d748c28c931af99fda53368d7217ac8ad1d838da7f99d5cd17104a7017c359` | `sha256sum design/registry.json` = `79d748c2…` | **OK — matches** |
| `code.path` | `web/app.css` | file exists; DS code path is `web/app.css` | OK |
| `code.sha256` | `sha256:be611ba4cfcb39f122255e38d101150516f619dd3a97327793832248da7baced` | `sha256sum web/app.css` = `be611ba4…` | **OK — matches** (1.0.0 was not reproducible) |
| `commit` | `41a1141f1d0649ae4ae272d9cd7fa7974c17d634` | tag `ds/v1.0.1` targets `773acb1`; the manifest `commit` is not the tagged commit | NOTE — declared snapshot, not the tag commit |
| `kit.sha256` | `sha256:d0867da377fb1cf09da93003f2e9cff1aad70041e17f44ef24c1cf81feea7a09` | S3 kit not fetched; not verifiable in this step | NOT VERIFIED (out of scope) |

Raw file hashes observed:

```
436af169ef28b64cac108288fae69d4ad6819330ac21ff048936a38af7265afb  design/tokens.json
79d748c28c931af99fda53368d7217ac8ad1d838da7f99d5cd17104a7017c359  design/registry.json
dbc2983b548da8fbce8c860e8c6cff745b517dfd44caaf564a077a913c93e29b  design/releases/1.0.1/manifest.json
be611ba4cfcb39f122255e38d101150516f619dd3a97327793832248da7baced  web/app.css
```

The manifest's own file sha256 (`dbc2983b…`) is **not** the release `digest`
(`4e0ef105…`). The release digest is a declared release-level value; its
derivation is not documented in this repo. This does not block the pin: the
pinned value is exactly the value declared in the approved manifest, and every
component hash consumed by the design work (`tokens.json`, `registry.json`,
`web/app.css`) verifies byte-for-byte.

## 2. Pin

`doc/идеи/f-v4-note-search/ds-pin.json`:

- `design_system_version` = `1.0.1`
- `ds_digest` = `sha256:4e0ef1052a1401a928588445f921f7d231b7c0e7c9b10c181fdbbb439108c85e`
  (exact value observed in the manifest)
- `approved_by` = `team-lead`, `pinned_at` = `2026-11-08T18:32:32Z`
- `fallback_used` = `false`
- normalized screens: one entry
  - `screen_id` = `note-search`
  - `platform` = `web`, `feature_profile` = `full`
  - `design_system_version` / `ds_digest` equal the top-level pin
  - `screen_brief` = owner-scoped note search over Notebook DS (search field,
    clear, idle/results/empty/loading/error/offline, 390/1200, read-only list
    with delete)

No duplicate `screen_id`; the fallback `screen_id=feature` was not used.

## 3. 1.0.1 token/source alignment

Token values: `design/tokens.json` (`version: 1.0.1`). CSS: `web/app.css`.

| Token | Token value | CSS evidence | Result |
|---|---|---|---|
| `font.family` | `system-ui, -apple-system, "Segoe UI", Roboto, Arial, sans-serif` | `body { font-family: … }` (L29) | match |
| `font.h1` | `22.4px` | `h1 { font-size: 1.4rem }` (L54) → 22.4px at 16px root | match (1.0.0 drift fixed) |
| `font.brand` | `19.2px` | `.brand { font-size: 1.2rem }` (L165) | match |
| `font.body` | `16px` | `body { font-size: 16px }` (L30) | match (1.0.0 drift fixed) |
| `control.height` | `44px` | `--control-height: 44px` (L14), inputs/buttons (L74, L100) | match |
| `control.textarea` | `88px` | `textarea { min-height: 88px }` (L84) | match |
| `radius.md` | `10px` | `--radius: 10px` (L13), `.card` (L49) | match |
| `radius.sm` | `8px` | literal `border-radius: 8px` (not tokenized) | value match; not tokenized |
| `color.accent_hover` | `#1554B8` | `--accent-dark: #1554b8` (L10, L111) | value match; CSS name differs |
| `color.border_subtle` | `#D0D7DE` | `--border-subtle` defined (L8), no consumer found | defined but unused |

## 4. Drift and supersession notes

1. **Supersedes the E0809 / 1.0.0 record.** The previous evidence pinned 1.0.0
   and listed typography drift (`h1 22px` vs 22.4px, body `15px` vs 16px,
   `font.secondary` 13px). DS 1.0.1 updates the token file to the rendered
   values (`h1 22.4px`, `brand 19.2px`, `body 16px`, `textarea 88px`), so that
   drift is closed by the release, not by app code.
2. **`code.sha256` is now reproducible:** 1.0.1 declares `web/app.css` and its
   hash matches the file byte-for-byte (1.0.0 declared a `web/` tree hash with
   no documented formula).
3. **Remaining non-blocking notes:** `--border-subtle` is declared but unused;
   `radius.sm` is hard-coded rather than tokenized; some spacing values are
   outside the declared 4/8/12/16/24/32 scale. These are s22a/DS-proposal
   inputs, not pin blockers.
4. **Tag vs manifest commit:** the `commit` field is a declared snapshot, not
   the commit the tag object points to. The pin uses the release `digest`, not
   the tag commit, so this does not change `ds_digest`.
5. **Release digest derivation is undocumented** (it is not the manifest file
   sha256). The pin uses the declared value; component hashes verify.

## 5. Verification result

**OK.** `release=1.0.1`, `tag=ds/v1.0.1` present, `tokens.json`,
`registry.json` and `web/app.css` sha256 match the 1.0.1 manifest exactly, and
`ds-pin.json` version/digest plus the normalized `note-search` screen match the
manifest. Pinned digest:

```
sha256:4e0ef1052a1401a928588445f921f7d231b7c0e7c9b10c181fdbbb439108c85e
```

No files under `design/`, `web/` or application code were modified by this
step. The approved pin was revalidated, not re-signed.
