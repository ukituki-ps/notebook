# Red-team review — f-v4-note-search (E1546)

- **Step:** `s22b.red_team_audit` · **Execution:** E1546 · **Build under review:** `a95876d` (dev/f-v4-note-search-ae079e5c)
- **Stand:** https://test2.nexus.ukituki.tech · **Reviewed:** 2026-11-07T17:01:48Z
- **Reviewer:** qwen3.8-fast (llama-proxy), independent of author session `ses_e492b197fffeN08PUKpdAXLjP8` (deepseek/deepseek-flash)
- **Mode:** read-only adversarial audit — source review, live API/UI probes on the stand, integrity check of deployed assets. No source modified, no commit.

## Verdict: **PASS** — 0 confirmed critical/high

### 1. Deploy integrity

- `/healthz` → `{"status":"ok","build_ref":"a95876d","commit":"a95876da78b26233045cd4d54df8b712756675af","image_digest":"sha256:375537...","build_args_hash":"sha256:fc622d...","gate_bundle_digest":"sha256:ff34ca0067aa8cd4726acfa20fece93d3d5da9b1b73d577f0182469f56cb7dad"}` — commit `a95876d` and `gate_bundle_digest=sha256:ff34ca00...` confirmed.
- Served assets are byte-identical to the a95876d worktree (sha256):
  - `/app.js` → `d5bdf2af…a28721` (repo `web/app.js` match)
  - `/app.css` → `0f7fe03c…83b4a` (match)
  - `/login`, `/register`, `/notes` HTML → `4976f733…2dc1c` (all equal repo `web/index.html`)

So the audited source **is** the deployed binary's payload.

### 2. Feature diff scope (base `406fa965` → `a95876d`)

Server change is additive and small: optional `q` filter on `GET /api/notes` (trim → ToLower → substring) plus `maxQueryBytes=512` guard. UI change: labelled search input, clear control, search-empty state, client-side filter over a shared `notes[]` array, sessionStorage persistence of the active query. No new dependencies, no persistence, no schema change.

### 3. Auth and owner isolation (live probes)

- Unauth `GET /api/notes`, `GET /api/notes?q=x`, `POST /api/notes`, `DELETE /api/notes/1` (and PUT/PATCH/DELETE unauth) → **401 + `WWW-Authenticate: Bearer`** in every case; auth is evaluated before method and query handling. No side effects.
- Three fresh users (A, B, C). A: notes 21–23 ("alpha one", "beta two", "gamma secret"); B: 24–25 ("beta three", "omega four"); C: none.
- `A: q=beta` → exactly `beta two` (narrows, owner-scoped). `B: q=alpha`, `B: q=gamma` → `[]` — **the query cannot widen scope or leak the other user's text**. `B: q=BETA` → case-insensitive match of B's own note only.
- Cross-user `DELETE /api/notes/21` with B's token → `404 not found`, indistinguishable from a missing id; `DELETE` of own note → `204`. No existence oracle beyond what the owner's own listing reveals.

### 4. Query semantics and robustness (live probes)

- `q=` (empty) and whitespace-only (`%20%20`, tab+newline, vertical tab, raw `+`) → all of the user's notes (OD-1). Raw `+` on the wire decodes to space per net/url — no crash, documented behaviour.
- No matches and zero-note users → **`200 []`, never `null`**.
- Length boundary: `q` of 512 bytes → 200; 513 bytes → `400 {"error":"query too long"}` (cap enforced on decoded bytes, before the scan).
- Encoding classes — all `200`, no panic/500, static JSON envelopes: literal `+` (`%2B`), space, Cyrillic (`пoe`, `%D0%9F%D0%9E`), emoji, `</script><svg onload=x>`, quotes/semicolons/backtick, invalid percent (`%%`), ampersand, NUL (`%00` in query), ctrl-D, vertical tab, `beta%00zz`.
- `POST /api/notes`: empty/whitespace/`null` text → `400 text required`; non-JSON body → `400 invalid request body`; text > 4096 bytes → 400; 4096 bytes → 201; 2 MB body → `400 invalid request body` (MaxBytesReader).
- Methods: `PUT/DELETE/PATCH /api/notes` → `405 method not allowed` with `Allow: GET, POST`; unknown `/api/*` → `404 not found`.
- `DELETE` id parsing: `21abc`, `0x21`, `99999999999999999999` (overflow), empty, `21/2` → `400 invalid id`; `%2e%2e` traversal input is path-cleaned by Go's ServeMux / nginx → 404; **no path traversal, no panic, no 5xx anywhere in the app layer**.

### 5. XSS and UI state review (`web/app.js`, `web/index.html`)

- All dynamic DOM updates use `textContent` / `setAttribute` / `cloneNode` of a static `<template>` row. Grep for `innerHTML|outerHTML|document.write|eval(|new Function|insertAdjacentHTML|srcdoc` over `web/`: **zero sinks** (only static, hardcoded `href` attributes in HTML). Note text is data-only on the wire (JSON) and is rendered exclusively through `text.textContent`.
- No `location.href` from user data — only fixed `location.replace` targets.
- Dead-end check: login 400/401, register 400/409, notes 401 (auto-redirect to /login), notes network errors and delete 400/404 all resolve to recoverable states; search clear/empty states are mutually consistent (`notes-search-empty` only when a non-empty trimmed query filters a non-empty collection to zero; whitespace-only query keeps the full list and hides the clear control — SEARCH-E2E-7/8). No new dead-end introduced by the feature; the pre-existing "notes form stays disabled after a 500 load with no retry button" nuance is carried over from f-v3 (logout remains available).

### 6. Findings

| id | severity | status | note |
|---|---|---|---|
| RT-E1546-1 | low | open | Search query survives a re-login without Logout: `sessionStorage['notebook.search']` is only cleared on no-token/401/logout paths, so a manual `/login` re-authentication in the same tab restores the previous account's query text into the next account's session (query string only, no note data). Non-blocking; recommend clearing on successful login. |
| RT-E1546-2 | info | confirmed | `DELETE /api/notes/21%00` → nginx HTML `400` (NUL rejected at the edge before the app); envelope deviation on RFC-invalid input, no security impact. |
| RT-E1546-3 | info | confirmed | `GET /api` → nginx 301 → `/api/` → 404 JSON; edge cosmetic deviation from the "unknown /api/* → 404" contract. |
| RT-08 (E1688) | low | confirmed (re-verified) | `DELETE` accepts Atoi alternate forms: live `0021`/`+21`/`-21` reach the owner-scoped store (404/204 like the canonical form); no oracle/escalation. Unchanged. |
| RT-09 (E1688) | info | accepted | Unbounded per-user note count; self-DoS class only, in-memory. Unchanged. |
| RT-10 (E1688) | info | accepted | Per-rune `ToLower` on q and each note text per request; performance nuance, consistent ASCII behaviour live-verified. Unchanged. |
| RT-11 (E1688) | info | accepted | UI search filters the cached notes list by design (spec core.md §3); stale-query path covered by SEARCH-E2E-8. Unchanged. |

**Confirmed critical/high: 0.** The only new substantive item is RT-E1546-1 (low), which is a follow-up hardening candidate, not a release blocker.

### 7. Corroboration

- s22a UI audit on the same build: `ui-audit.json` → `open_critical_high: 0`, 0 blockers/majors, 1 cosmetic.
- Feature E2E (SEARCH-E2E-1..8) reported 15/15 passed on this stand; independent live probes above reproduce the search semantics (narrowing, case-insensitivity, empty/whitespace, `[]`, clear behaviour) without relying on that report.
- No 5xx, no panics, no envelope leaks observed across all probes.
