# E1688 — residuals & s23 rationale

- Execution: `E1688` (f-v4-note-search), stand `test2`, build `872acd2`.
- Approval request: `apr_a1fb457b77a085091c0ac99a0cf037be` (s24), decided `approved` (waited 8s).

## Accepted residuals (all low/info; 0 confirmed critical/high)

- RT-08 (low): DELETE id accepts Atoi alternate forms (0027,+27); owner-scoped, no escalation.
- RT-09 (info): unbounded per-user note count (self-DoS, pre-existing).
- RT-10 (info): per-rune ToLower (no full Unicode folding); consistent.
- RT-11 (info): UI filters cached notes; stale-query handled (SEARCH-E2E-8).
- CR-F4-01 (low): non-canonical DELETE ids.
- CR-F4-02 (info): invariants.json provenance stale (E9294).
- CR-F4-03 (low): stale per-tab query pre-filters successor user's own notes (cosmetic).
- CR-F4-04 (refuted): XSS.

## Why s23.refinement was skipped

`s23` is `optional: true` with no gates. s22b/s22c returned `verdict=pass` with 0
confirmed critical/high; only the low/info items above. Code changes at this point
would change the deployed SHA and invalidate the validated `872acd2` deploy + 15/15
E2E evidence, with no re-deploy loop before s24. The residuals are surfaced here and
at s24 for the human decision.
