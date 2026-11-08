# Unit plan — notebook-search-deploy-e2e (U03)

- **Unit:** `notebook-search-deploy-e2e` · domain `notebook-e2e` · `sde-infra` · `plain`
- **Execution:** `E0809-s20.sde_5fexecution-u03` · branch `orc-exec-E0809-s20.sde_5fexecution-u03`
- **Base:** `f5943f5ed87e8bbcaadf48ec23dd005ac2c38f95`
- **Files (4):** `web/e2e/notes-search.spec.js`, `deploy/path1/e2e-preview.sh`,
  `scenarios.json`, `scenario-evidence.json` (both under `doc/идеи/f-v4-note-search/`)
- **Scope:** 20 Playwright scenarios; API smoke incl. 512-byte cap; manifest +
  per-scenario evidence; `test2` only under the E0809 lease.

## Tasks (order)

1. **T0009 — Playwright 20 scenarios** (`web/e2e/notes-search.spec.js`).
   Keep SEARCH-E2E-1..8; add 9–20 (count, zero-notes, loading, error/retry,
   offline, offline-zero, XSS, keyboard/aria, 512 cap, 390/1200, clear focus,
   owner-B). Exactly 20 `test()` calls; no `skip`/`fixme`/`only`; unique
   per-scenario screenshot; fail-close when stand/browser/UI is missing.
   Oracle: `E2E_BASE_URL=<test2> npx --no-install playwright test
   web/e2e/notes-search.spec.js` → 20 passed.
2. **T0010 — API smoke + E2E entry** (`deploy/path1/e2e-preview.sh`).
   Keep health and existing auth/register/login A/B smoke; add search smoke:
   owner-scope find / not-found `[]`; unauth `401` + `WWW-Authenticate: Bearer`;
   decoded `q` > 512 bytes → `400 {"error":"query too long"}` before scan;
   exactly 512 bytes → `200` (accepted). Keep `E2E_BASE_URL` required and
   node/npx/browser fail-close; run API smoke before Playwright.
   Oracle: `bash deploy/path1/e2e-preview.sh` exit 0 on `test2`.
3. **T0011 — manifest + evidence** (`scenarios.json`,
   `scenario-evidence.json`). 20 entries `SEARCH-E2E-1..20` with `id`,
   `given/when/then`, `e2e_ref`; 20 `pass` entries with screenshot path +
   `sha256` and `pngdiff: OK`, execution `E0809`. No stale `E8895` data.
   Oracle: manifest count 20; evidence 20/20; distinct screenshots/hashes.
4. **T0012 — test2-only / freeze guard** (script + manifest evidence).
   Run only on `test2` under the lease; no prod/main/stage/test1/canary;
   platform and Notebook DS 1.0.0 frozen until s24; no `design/**` edits.
   Oracle: stand/lease proof; diff limited to the four files.

## DoD — 20 tests, all passing

1. search finds matching note; 2. non-matching query → search empty;
3. case-insensitive match; 4. clear restores full list; 5. create with active
query re-applies filter; 6. delete with active query keeps filter consistent;
7. whitespace-only query; 8. no-token path clears leftover query; 9. count
`Найдено N` only for non-empty query; 10. zero-notes → `notes-empty` wins,
search disabled; 11. loading visible, search disabled; 12. error + `Повторить`
retries `loadNotes`; 13. offline banner with loaded notes, no false empty;
14. offline-zero ≠ search-empty; 15. XSS/HTML text renders literally;
16. keyboard/focus/aria incl. `aria-live`; 17. 512-byte API cap via
`request` (>512 → `400 query too long`; 512 accepted); 18. 390/1200 no
horizontal overflow, stacked/inline row; 19. clear returns focus + full list;
20. owner-scope B never sees A's notes.

**Acceptance:** 20/20 Playwright; API smoke green incl. 512 cap; 20/20 real
evidence (screenshots + sha256 + `pngdiff`) recorded at **s20c only** — no
skip/fixme, no fabricated/stale evidence; `test2`-only rental proof.

## Out of scope

`main.go`, `web/index.html`, `web/app.js`, `web/app.css`, `web_ui_test.go`,
auth/session/persistence, prod/main/stage/test1/canary, s45/s46, DS/platform
changes, `design/**`, `UI-GRAPH.yaml` (s21).
