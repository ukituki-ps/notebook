# Adversarial code review — note-search (E0722 / s22c)

- Build under review: `4347f16` (code identical to the evaluated tree; docs-only commits after it).
- Reviewer: independent session `ses_e3f30112fffeJjQ4O6A5NsyOJp`, model
  `qwen3.8-fast`, provider `llama-proxy` (cross-pair; distinct from the author
  `ses_e3f4150e…` and from the s22b reviewer `ses_e3f3490c…`).
- Verdict: **pass** — no confirmed critical/high finding.
- Proof: `go build`, `go vet`, `go test -count=1 ./...` clean; full invariant test
  set PASS; 13 targeted httptest probes on a `/tmp` copy (repo untouched);
  zero `innerHTML`/`eval`/`document.write` in `web/*.js`.

## Findings

| id | severity | status | summary |
|---|---|---|---|
| CR-01 | info | closed | auth-before-query; unauth 600B q → 401 with WWW-Authenticate |
| CR-02 | info | closed | owner-scope predicate before text filter; foreign search `[]`, foreign delete 404 |
| CR-03 | info | closed | 512-byte q cap before trim/scan; 512→200, 513→400; multi-byte boundary |
| CR-04 | low | closed | case-insensitive via `strings.ToLower` both sides; no locale-aware folding (non-goal) |
| CR-05 | info | closed | XSS: `textContent` only; no live nodes in SEARCH-E2E-15 |
| CR-06 | info | closed | delete auth/405/400/404/204; no IDOR |
| CR-07 | low | closed | load/delete generation guard prevents stale resurrection |
| CR-08 | low | confirmed | 200ms 401 redirect window leaves the previous rendered list visible; not cross-user exploitable |
| CR-09 | low | confirmed | client-side-only logout; captured token valid up to 24h (auth out of scope) |
| CR-10 | info | refuted | path-normalization auth bypass; Go mux 301-collapses, canonical path still enforces auth |
| CR-11 | low | confirmed | test/doc gaps: unregressed edge id/path forms; INV-UI-E2E-PREVIEW test_ref points at per-run evidence absent from the tree |
| CR-12 | info | closed | PBKDF2 210k iterations; below OWASP 600k but acceptable for this app |

## Residuals (low/accepted)

CR-08, CR-09 and CR-11 are low and accepted; none is a blocker. They are carried
into s23 triage. No code, invariant, evidence, or gate was modified by the reviewer.
