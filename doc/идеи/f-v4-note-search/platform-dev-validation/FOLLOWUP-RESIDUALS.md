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
  - image digest `sha256:0c6e3b29465cffa8e4a78e0cd9fa2a0cf38e46a944ccec64e7a35c6d44b931b3`;
  - `build_args_hash` `sha256:bd78244b9836221dd8de66ff5806d580ce4b4ff79d675060f16fb3ece6045088`;
  - `gate_bundle_digest` `sha256:9a794119a62426e9e6f3d5eac63a772f999ec7d7ff279d81915c9b143afaaf48`
    (non-empty in `/healthz` and both provenance files).
- Live API: `GET /api/notes?q=<513 bytes>` → `400 {"error":"query too long"}`;
  `GET /api/notes?q=ok` → `200 []`.
- Playwright on test2: **15/15 passed**, including `SEARCH-E2E-7`
  (whitespace-only clear control hidden) and `SEARCH-E2E-8`
  (no-token path clears the leftover query).
