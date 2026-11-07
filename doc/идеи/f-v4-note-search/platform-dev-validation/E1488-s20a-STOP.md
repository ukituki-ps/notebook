# E1488 — s20a STOP on red gate `invariant-enforced` (dev contour)

- Date: 2026-11-07 (UTC)
- Execution: **E1488** — `path-1.feature@3.2.2`, entry point `integrate`
- Session: `ses_e4a29a379ffePYXhcGHsgKbTTf`
- Base (execution): `6e06bf335f3378da10a880f4825bed0d221af26a`
- Work branch: `dev/f-v4-note-search-ae079e5c`
- Stand: `test2` (lease `4faaea7b-fc93-41da-8eea-06c7f3abe61e`, released after stop)
- s20a artifact commit: `24592817fd2def57da7309a0cf132961790c235c`
  (`artifacts/units/E1488-integration-report.md`)

## What happened

`s20a.unit_integrate` work was completed (units from E8895 are merged into the
base; `go build/vet/test` green) and committed/pushed. `orc_accept` for s20a
then failed on the L1 gate `invariant-enforced`:

```json
{"checked":0,"failed":0,"gate":"invariant-enforced","invariants":[],
 "layer":"invariant-gate",
 "message":"invariant-enforced failed: invariants отсутствует — нечего прогонять (machine checker required)",
 "passed":false}
```

## Root cause

`gate-invariant-enforced` is defined (arch/processes/path-1.feature.yaml,
lines 2543–2559) with:

```
criteria:
  - 'step: s06.feature_brief_final'
  - 'invariants_key: invariants'
  - 'fail_on_missing: true'
  ...
```

It sources invariants from **step s06.feature_brief_final**. The `integrate`
entry point has `start_from: s20a.unit_integrate`, so `s06.feature_brief_final`
is skipped (like every step before s20a). Its `invariants` context therefore
does not exist and the gate fails closed.

The feature DOES have committed invariants:
`doc/идеи/f-v4-note-search/invariants.json` — 18 invariants, 16 `active` with
executable `test_ref` (`cmd:go test ...`). The gate reported `checked: 0` /
`invariants: []`, i.e. it did not read this file for the `integrate` run.

## Contrast with E8895 (same branch, older platform)

On the previously validated platform (`ae079e5c`), E8895 accepted
`s20a.unit_integrate` at `L5 human-accept`; its only failing gate was
`gate-l2-integration`. `gate-invariant-enforced` passed there despite s06 being
skipped. On platform `e151321b` the same `integrate` entry now fails
`invariant-enforced` with zero invariants — a platform/process regression for
entry points that start after s06.

## Not done / not bypassed

- No `force`, skip, waiver, or context injection was used.
- No prod / preprod / test1 / `main`; dev + `test2` only.
- `s20b`…`s24` were not reached; no deploy was performed for E1488.

## test2 `/healthz` (unchanged prior build, no E1488 deploy)

```
build_ref=e0d41a0
commit=e0d41a0efe7d22f414ca2105ecf828cd3e5068a7
image_digest=sha256:51ad01ad53f48612d93e5464310430eabda3dd0ec62d2aa6ff4f512cd022f05a
build_args_hash=sha256:a1b878f1e4433bf41968ff35c6a38f2d5aa015eae1ab9544ccb3204e19eebce3
gate_bundle_digest=sha256:a5b74e21002e87c2899374deb312eeb890b0fe44cb295a8c7d002e4a0b64f2f4
```

`gate_bundle_digest` is non-empty on the current stand, but it is the previous
`a5b74e2…` value, not the expected platform bundle
`sha256:c783b5dde7ae7bd01773dd45c6293f05dc79d17831440d32dd65a2f10f112d92`.

## Options to proceed

1. Platform fix: `gate-invariant-enforced` must read the committed
   `doc/идеи/<F>/invariants.json` (or inherit the s06 machine mirror) for
   entry points that start after s06.
2. Run `entry_point: default` (s01 → s24) after explicit operator approval; it
   executes s06, producing the `invariants` context the gate expects.
