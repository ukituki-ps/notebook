# Red-team audit — f-v4-note-search (s22b)

- **Execution:** E8363 · **Step:** s22b.red_team_audit · **Platform:** web
- **Stand:** https://test2.nexus.ukituki.tech · **Build:** c267619 (commit c2676199e5876abbb61a0030c01049bd782248ac)
- **Reviewer:** ses_e4ce0fbfbffeipFcUHF5hacXaf · **Author:** ses_e4cffab3effecevpjqsiAV9qT2
- **Mode:** read-only + live probing of test2 only; synthetic users/notes; no prod/preprod/test1; no code changes.

## Result

- Verdict: **pass**
- Attempts: **23** (all safe)
- Findings: **0 critical / 0 high / 0 medium / 0 low**

## Attack log

- `A-REG` — POST /api/register rt3k7hml9ojh → expected 200/201; observed 201 {'id': 22, 'username': 'rt3k7hml9ojh'}; **safe**
- `A-LOGIN` — POST /api/login rt3k7hml9ojh → expected 200 token; observed 200 token=yes; **safe**
- `B-LOGIN` — POST /api/login rti4apphnath → expected 200 token; observed 200 token=yes; **safe**
- `A-CREATE` — POST /api/notes 'Buy milk' → expected 200/201; observed 201; **safe**
- `A-CREATE` — POST /api/notes 'Project plan' → expected 200/201; observed 201; **safe**
- `A-CREATE` — POST /api/notes 'milk chocolate' → expected 200/201; observed 201; **safe**
- `NOAUTH-LIST` — GET /api/notes → expected 401; observed 401; **safe**
- `BADTOKEN-LIST` — GET /api/notes Bearer bad → expected 401; observed 401; **safe**
- `A-ALL` — GET /api/notes (A) → expected 200 own notes; observed 200 n=3; **safe**
- `A-Q-MILK` — GET /api/notes?q=milk (A) → expected 200 only matching; observed 200 texts=['Buy milk', 'milk chocolate']; **safe**
- `B-Q-MILK` — GET /api/notes?q=milk (B) → expected 200 [] (no A notes); observed 200 n=0; **safe**
- `A-Q-EMPTY` — GET /api/notes?q= (A) → expected 200 all own; observed 200 n=3; **safe**
- `A-Q-WS` — GET /api/notes?q=%20%20%09 (A) → expected 200 all own (whitespace no-op); observed 200 n=3; **safe**
- `A-Q-PCT` — GET /api/notes?q=%25 (A) → expected 200 no wildcard broadening; observed 200 n=0; **safe**
- `A-Q-UNDER` — GET /api/notes?q=_ (A) → expected 200 no wildcard broadening; observed 200 n=0; **safe**
- `A-Q-LONG` — GET /api/notes?q=<5000 a> (A) → expected 200, no 500; observed 200; **safe**
- `A-Q-NUL` — GET /api/notes?q=%00 (A) → expected 200/400, no 500; observed 200; **safe**
- `PUT-NOTES` — PUT /api/notes (A) → expected 405 + Allow; observed 405 allow=GET, POST; **safe**
- `DEL-BAD-ID` — DELETE /api/notes/abc (A) → expected 400; observed 400; **safe**
- `DEL-MISSING` — DELETE /api/notes/999999999 (A) → expected 404; observed 404; **safe**
- `UNKNOWN-API` — GET /api/nope (A) → expected 404 JSON; observed 404; **safe**
- `B-DEL-A` — DELETE A note as B → expected 404 (not deleted); observed 404; **safe**
- `A-SECRET-STILL` — GET ?q=secret (A) → expected A note still present; observed 200 n=1; **safe**

## Notes

- Search is an owner-scoped `ListNotes(session.UserID)` snapshot filtered by case-insensitive `strings.Contains`; there is no SQL/LIKE, so `%` and `_` stay literal.
- `requireAuth` runs before method/query handling; missing/bad tokens return 401 before any note access.
- Notes are rendered with `textContent`, never `innerHTML`; no XSS surface in the search or list rendering.
- The independent extended probe (58 attempts, separate reviewer session) additionally noted two low hardening items (invalid percent-escape degrades to empty q; unbounded notes-per-user). Neither is a blocker; both are recorded as residual risks in the execution report.
