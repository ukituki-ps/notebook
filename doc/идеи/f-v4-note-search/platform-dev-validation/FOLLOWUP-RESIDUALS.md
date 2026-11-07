# Residual risks — follow-up closure (2026-11-07)

The E8895 report recorded five residuals. The reviewer-runtime item was fixed on
the platform (`730d144a`); this file closes the remaining four.

| ID | Status | Change |
|---|---|---|
| `gate_bundle_digest` empty on test2 | **fixed (platform)** | `stand-runner-client` sends the pinned digest; `stand-runner` exports `NEXUS_GATE_BUNDLE_DIGEST`; `deploy-preview-stand` refuses to write an empty digest. Next preview build bakes a non-empty value into `/healthz` and provenance. |
| RT-NEW-1 | **fixed** | `web/app.js`: the no-token path clears `sessionStorage["notebook.search"]`; the clear button is hidden for whitespace-only queries. Covered by `SEARCH-E2E-7` and `SEARCH-E2E-8`. |
| RT-NEW-2 | **fixed** | `GET /api/notes?q=` rejects queries longer than `maxQueryBytes` (512) with `400 query too long`; test `TestNotesSearchQueryTooLong`. |
| RT-NEW-3 | **closed** | The reviewer's canary run is copied from the gitignored runner directory to tracked evidence: `evidence/canary/` (config + three logs). |

Owner scope, auth-first behavior and the `[]` (not `null`) response contract are
unchanged.

## Verification (2026-11-07)

- test2 rebuilt from `e0d41a0` (the commit above):
  - commit `e0d41a0efe7d22f414ca2105ecf828cd3e5068a7`;
  - image digest `sha256:51ad01ad53f48612d93e5464310430eabda3dd0ec62d2aa6ff4f512cd022f05a`;
  - `build_args_hash` `sha256:a1b878f1e4433bf41968ff35c6a38f2d5aa015eae1ab9544ccb3204e19eebce3`;
  - `gate_bundle_digest` `sha256:a5b74e21002e87c2899374deb312eeb890b0fe44cb295a8c7d002e4a0b64f2f4`
    (non-empty in `/healthz` and both provenance files).
- Live API: `GET /api/notes?q=<513 bytes>` → `400 {"error":"query too long"}`;
  `GET /api/notes?q=ok` → `200 []`.
- Playwright on test2: **15/15 passed**, including `SEARCH-E2E-7`
  (whitespace-only clear control hidden) and `SEARCH-E2E-8`
  (no-token path clears the leftover query).
