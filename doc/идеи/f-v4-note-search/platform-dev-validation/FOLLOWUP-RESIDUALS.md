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
