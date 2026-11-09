# Red-team review — note-search (E1868 / s22b)

- Target: test2, build `9c1763c`, image `sha256:cb271106…`
- Reviewer: independent reviewer session (not the executor)
- Attack log: `attack-log.json` — 10/10 probes pass
- Attacks: no-token 401; owner isolation on search; no-match `[]`; 512 accepted; 513 → 400 `query too long`; stored XSS text is literal (UI E2E-15 proves textContent render); delete missing → 404; delete invalid → 400; cross-user delete → 404.
- Verdict: **pass**; 0 critical/high, 0 medium, 0 low.
- Residual: none from the attack surface tested. The response JSON escapes `<` as `\u003c`; storage is literal and rendering is textContent.
