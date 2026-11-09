# DS pin evidence — f-v4-note-search (s02a.ds_pin)

- Execution: **E9108**, step `s02a.ds_pin` (path-1.feature 4.0.0)
- Branch: `dev/path10-runner-08`; step base `5e7b1b0` (execution base `9e7fae3`)
- Design system: **Notebook DS 1.0.1** (approved)
- Pinned artifact: `doc/идеи/f-v4-note-search/ds-pin.json`
- Verified at: 2026-11-09T20:26Z against the tree at `5e7b1b0`
- DS source is **`web/app.css`** (1.0.1 narrows `code.path` to the stylesheet).
  `frontend/src/ui/kit` is not read and is not a DS source for this feature.

## 1. Release manifest verification

Source: `design/releases/1.0.1/manifest.json`.

| Field | Manifest value | Observed / recomputed | Result |
|---|---|---|---|
| `release` | `1.0.1` | `1.0.1` | OK |
| `tag` | `ds/v1.0.1` | tag `ds/v1.0.1` exists in this repository | OK |
| `commit` | `41a1141f1d0649ae4ae272d9cd7fa7974c17d634` | commit object exists | OK (declared) |
| `digest` | `sha256:4e0ef1052a1401a928588445f921f7d231b7c0e7c9b10c181fdbbb439108c85e` | same string in manifest; used verbatim as `ds_digest` in the pin | OK (declared) |
| `tokens.sha256` | `sha256:436af169ef28b64cac108288fae69d4ad6819330ac21ff048936a38af7265afb` | `sha256sum design/tokens.json` = `436af169…65afb` | **OK — matches** |
| `registry.sha256` | `sha256:79d748c28c931af99fda53368d7217ac8ad1d838da7f99d5cd17104a7017c359` | `sha256sum design/registry.json` = `79d748c2…17c359` | **OK — matches** |
| `code.path` | `web/app.css` | file exists | OK |
| `code.sha256` | `sha256:be611ba4cfcb39f122255e38d101150516f619dd3a97327793832248da7baced` | `sha256sum web/app.css` = `be611ba4…7baced` | **OK — matches** |
| `kit.sha256` | `sha256:d0867da377fb1cf09da93003f2e9cff1aad70041e17f44ef24c1cf81feea7a09` | S3 kit not fetched; not verifiable in this step | NOT VERIFIED (out of scope) |

The release digest is the value declared by the approved manifest; the component
hashes consumed by design work (`tokens.json`, `registry.json`) and the code
snapshot (`web/app.css`) all verify byte-for-byte. The earlier 1.0.0 note that
`code.sha256` was not reproducible is resolved in 1.0.1.

## 2. Pin

`doc/идеи/f-v4-note-search/ds-pin.json`:

- `design_system_version` = `1.0.1`
- `ds_digest` = `sha256:4e0ef1052a1401a928588445f921f7d231b7c0e7c9b10c181fdbbb439108c85e`
- `approved_by` = `team-lead`
- `fallback_used` = `false`
- one screen: `note-search`, platform `web`, profile `full`, same version/digest

This matches the gate criteria: non-empty approved version, digest equal to the
manifest, non-empty `screens`, exactly the six required keys per screen, no
duplicate `screen_id`.

## 3. Tokens vs `web/app.css` (1.0.1)

Prior 1.0.0 typography drift is fixed in the release and in the CSS:

| Token | Token value | CSS evidence | Result |
|---|---|---|---|
| `font.h1` | `22.4px` | `h1 { font-size: 1.4rem }` (`web/app.css:54`); root `font-size: 16px` (`:30`) → 22.4px | match |
| `font.brand` | `19.2px` | `.brand { font-size: 1.2rem }` (`:165`) → 19.2px | match |
| `font.body` | `16px` | `body { font-size: 16px }` (`:30`) | match |
| `control.textarea` | `88px` | `min-height: 88px` on the note textarea (`:84`) | match |

Remaining minor notes (none change the digest and none block s03):

1. `color.border_subtle` (`#D0D7DE`) is declared (`tokens.json:12`,
   `web/app.css:8`) but referenced nowhere.
2. Token key `accent_hover` maps to CSS `--accent-dark` (`web/app.css:10,111`);
   values are identical, only the name differs.
3. `radius.sm` (`8px`) is correct but hard-coded in four rules
   (`web/app.css:77,103,133,234`), not tokenized.
4. Spacing still uses off-scale values: 20px (`:50`), 14px/6px (`:61`),
   10px (`:75,101,232`), 18px (`:126`), 48px (`:39`), 225 gap 10px (`:225`).
5. `design/README.md` still says the tag is `ds/notebook-1.0.0`; the actual and
   manifest tag is `ds/v1.0.1`.

## 4. Verification result

**OK with minor notes.** `release=1.0.1`, `tag=ds/v1.0.1`, `tokens.json`,
`registry.json`, and `web/app.css` hashes match the manifest. The pinned
`ds_digest` is exactly:

```
sha256:4e0ef1052a1401a928588445f921f7d231b7c0e7c9b10c181fdbbb439108c85e
```

Gate: `bash tools/path1-gate.sh ds-pin E9108` (with
`ORC_FEATURE_DIR=doc/идеи/f-v4-note-search`).

Correction to the previous revision of this file: it described DS 1.0.0 while
`ds-pin.json` had already been moved to 1.0.1 (`49ec90e`). This revision makes
the evidence match the pinned artifact.

No files under `design/`, `web/`, or application code are modified by s02a.
