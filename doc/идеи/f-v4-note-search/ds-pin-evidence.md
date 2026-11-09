# DS pin evidence — f-v4-note-search (s02a.ds_pin)

- Execution/step: **E6588** · `s02a.ds_pin` · role **architect**
- Process: `path-1.feature@4.0.0`, entry `default`, platform `web`, profile `full`
- Branch: `dev/path10-runner-06` · base `9e7fae353c61e717505dc40019627a1d7ab48820`
- Design system: **Notebook DS 1.0.1** (approved release `ds/v1.0.1`)
- Pinned artifact: `doc/идеи/f-v4-note-search/ds-pin.json`
- DS source is **`web/app.css`** (`design/tokens.json` `"source": "web/app.css"`).
  Not Kubiki; `frontend/src/ui/kit` is not a DS source for this feature.
- Verified at: 2026-11-09T18:18Z (worktree clean for `design/`, `web/`, code).

## 1. Release manifest verification

Source: `design/releases/1.0.1/manifest.json`. Working tree for `design/` and
`web/` equals the committed base, so the bytes hashed below are the released
blobs.

| Field | Manifest value | Observed / recomputed | Result |
|---|---|---|---|
| `release` | `1.0.1` | `1.0.1` | OK |
| `tag` | `ds/v1.0.1` | tag exists, resolves to `773acb1ffb0b3162c4baf9c811881a31659a79ce` | OK |
| `commit` | `41a1141f1d0649ae4ae272d9cd7fa7974c17d634` | commit exists and is an **ancestor** of the tag commit `773acb1` (tag commit is a later process change) | NOTE — `commit` is the pre-tag snapshot, as in 1.0.0 |
| `digest` | `sha256:4e0ef1052a1401a928588445f921f7d231b7c0e7c9b10c181fdbbb439108c85e` | same value in manifest; used verbatim as `ds_digest` | OK (declared) |
| `tokens.path` / `sha256` | `design/tokens.json` / `sha256:436af169ef28b64cac108288fae69d4ad6819330ac21ff048936a38af7265afb` | `sha256sum design/tokens.json` = `436af169…65afb` | **OK — matches** |
| `registry.path` / `sha256` | `design/registry.json` / `sha256:79d748c28c931af99fda53368d7217ac8ad1d838da7f99d5cd17104a7017c359` | `sha256sum design/registry.json` = `79d748c2…7c359` | **OK — matches** |
| `code.path` / `sha256` | `web/app.css` / `sha256:be611ba4cfcb39f122255e38d101150516f619dd3a97327793832248da7baced` | `sha256sum web/app.css` = `be611ba4…baced` | **OK — matches** |
| `kit.sha256` | `sha256:d0867da377fb1cf09da93003f2e9cff1aad70041e17f44ef24c1cf81feea7a09` | S3 kit not fetched; not verifiable in this step | NOT VERIFIED (out of scope) |

Raw file hashes observed:

```
436af169ef28b64cac108288fae69d4ad6819330ac21ff048936a38af7265afb  design/tokens.json
79d748c28c931af99fda53368d7217ac8ad1d838da7f99d5cd17104a7017c359  design/registry.json
be611ba4cfcb39f122255e38d101150516f619dd3a97327793832248da7baced  web/app.css
dbc2983b548da8fbce8c860e8c6cff745b517dfd44caaf564a077a913c93e29b  design/releases/1.0.1/manifest.json
```

The release `digest` (`4e0ef105…c85e`) is an opaque release-level value, not the
sha256 of the manifest bytes (`dbc2983b…e29b`) and not derivable from the
component hashes without a documented formula. The pin uses the manifest's
declared digest verbatim; every consumable component hash (`tokens`, `registry`,
`code`) verifies byte-for-byte.

## 2. Pin

`doc/идеи/f-v4-note-search/ds-pin.json`:

- `design_system_version` = `1.0.1`
- `ds_digest` = `sha256:4e0ef1052a1401a928588445f921f7d231b7c0e7c9b10c181fdbbb439108c85e`
  (exact value from the manifest)
- `approved_by` = `team-lead`; `pinned_at` = `2026-11-08T18:32:32Z`;
  `fallback_used` = `false`
- one screen, keys exactly `screen_id`, `screen_brief`, `platform`,
  `feature_profile`, `design_system_version`, `ds_digest`:
  - `screen_id` = `note-search`
  - `screen_brief` = owner-scoped note search over Notebook DS: search field,
    clear, idle/results/empty/loading/error/offline, 390/1200, read-only list
    with delete
  - `platform` = `web`, `feature_profile` = `full`
  - version/digest equal the top-level values
- no duplicate `screen_id`; no fallback entry.

The pin is unchanged by this step: it already matches the approved release and
passes the structural `ds-pin` contract. s02a re-verifies it and records the
evidence here.

## 3. Tokens vs `web/app.css`

Tokens: `design/tokens.json` (version `1.0.1`, source `web/app.css`).

| Area | Result |
|---|---|
| Colors (`bg`, `card`, `text`, `muted`, `border`, `accent`, `danger`, `focus`) | Values match the CSS custom properties in `web/app.css:3-15` (case only). |
| `color.accent_hover` | Value matches (`#1554B8`); CSS name is `--accent-dark` — name drift only. |
| `color.border_subtle` | `--border-subtle: #d0d7de` is defined (`web/app.css:8`) but referenced nowhere — declared-but-unapplied token. |
| `font.h1` / `font.brand` / `font.body` | Now match rendered CSS: `22.4px` / `19.2px` / `16px` (`web/app.css:30,54,165`); the 1.0.0 typography drift is resolved. |
| `radius.md` | `--radius: 10px` used by `.card`. |
| `radius.sm` | `8px` used literally in several rules; no `--radius-sm` variable. |
| `control.height` / `control.textarea` | `44px` / `88px` match. |
| `focus.width` / `focus.offset` | `3px` / `2px` match. |
| `space.*` | CSS still uses off-scale values (e.g. `gap: 10px` in `.notes-list`, `web/app.css:224`); `space.1` has no consumer. |

`web/app.css:215` now contains a real `.notes-search-empty` rule (the 1.0.0
"dead rule" note no longer applies).

## 4. Drift list (consolidated, non-blocking)

1. `color.border_subtle` is defined but not applied.
2. `color.accent_hover` is implemented as `--accent-dark` (same value, name drift).
3. `radius.sm` is not tokenized (literal `8px` in several rules).
4. Spacing uses off-scale values (10px, 6px, 14px, 18px, 20px, 48px, 88px)
   outside the declared 4/8/12/16/24/32 scale.
5. Manifest `commit` (`41a1141`) is a pre-tag snapshot; the tag `ds/v1.0.1`
   points to a later commit `773acb1`. Factual, not a pin blocker.
6. Manifest `kit.sha256` is not verified (S3 object not fetched at s02a).

None of these change `ds_digest` (taken verbatim from the approved manifest) and
none invalidate the pin. Items 1-4 are s03/s22a mapping inputs: the search UI
must use the existing `web/app.css` values/styles and must not invent new
tokens; gaps become DS proposals, not ad-hoc values.

## 5. Verification result

**OK with drift notes.** `release=1.0.1`, tag `ds/v1.0.1` present,
`tokens.json`, `registry.json`, and `web/app.css` sha256 all match the manifest
exactly, and the declared `ds_digest` is present in both the pin and the
manifest:

```
sha256:4e0ef1052a1401a928588445f921f7d231b7c0e7c9b10c181fdbbb439108c85e
```

Gate: `bash tools/path1-gate.sh ds-pin E6588` (ORC runs it in the eval
worktree; the runner container has no python3, so the structural contract was
pre-checked here with an equivalent JSON check). No files under `design/`,
`web/`, or application code are modified by this step.
