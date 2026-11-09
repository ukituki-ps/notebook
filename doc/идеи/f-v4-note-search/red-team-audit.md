# Red-team review — note-search (E0722 / s22b)

- Target: test2, build `4347f16`, image `sha256:dda878c9…`
- Reviewer: independent reviewer session `ses_e3f3490c9ffeR3J2cb07Y0u1Jk`,
  model `qwen3.8-fast`, provider `llama-proxy` (cross-pair; distinct from the
  execution author `ses_e3f4150e…`).
- Attack log: `attack-log.json` — **15/15 probes pass**.
- Attacks: no-token 401; auth-before-query on q=513 and DELETE; owner isolation on
  search; foreign delete 404; no-match `[]`; 512 accepted; 513 → 400
  `query too long`; stored XSS returned literally and rendered with `textContent`;
  delete invalid → 400; prefix/method status handling.
- Verdict: **pass**; 0 open critical/high, 0 open medium, 0 open low.
- Residual: one low closed note (live attack log used ASCII for the cap; the
  multibyte byte boundary is pinned by `TestNotesSearchQueryTooLong`), and a
  cosmetic note that the attack log did not record the `WWW-Authenticate` value
  (verified present live).
- No code, invariant, evidence, or gate was modified by the reviewer.
