# s20a — unit integration report (E6177)

- Base: `74d6cec`, feature branch `dev/f-v4-note-search-fix`
- Units merged: notebook-search-api, notebook-search-ui, notebook-search-deploy-e2e
- Unit sessions (distinct): `ses_e438fe…` (api), `ses_e438fdd7…` (ui), `ses_e42f307b…` (deploy-e2e); parent `ses_e439…`
- All three child executions: done, 0 failed, 0 new findings.
- Verification: `go test ./...` ok; 30/30 Playwright local; `ds-token-drift` PASS 20 checks.
- Regression found and fixed during u03: `deploy/path1/e2e-preview.sh` now includes search smoke (q, no-match [], 512 accepted, 513 -> 400).
- Contract parity: 0 drift; model/code deltas 0.

## E6469 continuation

- gate base corrected to `74d6cec`; tools diff empty; re-running s20a.
- test2 lease `8371bd14…` for E6469.

## E2727 continuation

- s20a rerun on deploy 905993c2 with gate-base fallback; test2 lease `f2f58b83…`.
