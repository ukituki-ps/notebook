# E1488 — residuals & s23 rationale

- Execution: `E1488` (f-v4-note-search), stand `test2`, build `a579a38`.
- Approval request: `apr_645aff96d280fc319c9faac64e0602dc` (s24), decided `approved` (waited 4s).

## Accepted residuals (all low/info; 0 confirmed critical/high)

- CR-F4-01 (low): whitespace-only `q` > 512 bytes returns 400 before trim (INV-SEARCH-EMPTY-Q); API-only, web UI filters client-side.
- CR-F4-02 (info): 512-byte q cap missing from contract docs.
- CR-F4-03 (info): SEARCH-E2E-7/8 lack scenarios.json traceability entries (tests pass).
- CR-F4-04 (info): dead CSS `.notes-search-empty`.
- RT-NS-1/2/5 (low/info): unbounded notes/user and lazy session pruning (dev stand only).

## Why s23.refinement was skipped

`s23` is `optional: true` with no gates. `s22b`/`s22c` returned `verdict=pass` with 0
confirmed critical/high; only the low/info hygiene items above. Code changes at
this point would change the deployed SHA and invalidate the validated
`a579a38` deploy + 15/15 E2E evidence, and the DAG has no re-deploy loop before
s24. The residuals are surfaced here and at s24 for the human decision.
