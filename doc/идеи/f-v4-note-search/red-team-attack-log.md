# Red-team attack log — f-v4-note-search, E1546 (build a95876d)

Stand: `https://test2.nexus.ukituki.tech` · Probed: 2026-11-07 16:59–17:01 UTC · Mode: read-only, live HTTP probes + source review.
Accounts (fresh, timestamped): A=`rta1794070799` (user 15), B=`rtb1794070799` (user 16), C=`rtc1794070799` (user 17). Notes created: A→21 "alpha one", 22 "beta two", 23 "gamma secret"; B→24 "beta three", 25 "omega four"; C→none. (Note ids continue from earlier E2E runs on the stand.)

## P1 — Deploy identity

```
$ curl -fsSi https://test2.nexus.ukituki.tech/healthz
HTTP/2 200  (nginx)
{"status":"ok","build_ref":"a95876d","commit":"a95876da78b26233045cd4d54df8b712756675af",
 "image_digest":"sha256:375537906f5ef4a166527bfcb71cd66a478581e44cb6553067c13e3600e2685f",
 "build_args_hash":"sha256:fc622d57001151d17e4c18a62d7eeb44eee8cc199a764f39f65574016dd60414",
 "gate_bundle_digest":"sha256:ff34ca0067aa8cd4726acfa20fece93d3d5da9b1b73d577f0182469f56cb7dad"}
```
→ **commit=a95876d ✓, gate_bundle_digest=sha256:ff34ca00… ✓**

Asset integrity (sha256, stand vs `a95876d` worktree):
- `/app.js` `d5bdf2af24b81424157bd6d438cfac43d4d1f5d65c6c51188d1551ffffa28721` == repo `web/app.js` ✓
- `/app.css` `0f7fe03cfa2b76d54c2a75d860f0e812f912aa2c9b3eb6d0bc11b9d308483b4a` == repo ✓
- `/login`, `/register`, `/notes` → `4976f733804d030089d6c3e136e456338f139d10fba0349205cce2e6fb50dc1c` == repo `web/index.html` ✓ (all three pages identical; `/index.html` itself 404 by design — only page routes served)

## P2 — Unauth 401 + WWW-Authenticate (auth before method/query)

| probe | observed |
|---|---|
| `GET /api/notes` | 401, `www-authenticate: Bearer`, `{"error":"unauthorized"}` |
| `GET /api/notes?q=x` | 401, `www-authenticate: Bearer` |
| `DELETE /api/notes/1` | 401, `www-authenticate: Bearer` |
| `POST /api/notes` | 401 |
| `PUT/DELETE/PATCH /api/notes` (unauth) | 401 each |

→ auth precedes method/query handling; no side effects. ✓

## P3 — Owner scoping / narrowing

| probe (token) | observed |
|---|---|
| A `GET /api/notes` | `[{"id":21,"text":"alpha one"},{"id":22,"text":"beta two"},{"id":23,"text":"gamma secret"}]` |
| B `GET /api/notes` | `[{"id":24,"text":"beta three"},{"id":25,"text":"omega four"}]` |
| A `GET /api/notes?q=beta` | `[{"id":22,"text":"beta two"}]` — narrows, owner-scoped |
| B `GET /api/notes?q=alpha` | `[]` — A's text not visible to B |
| B `GET /api/notes?q=gamma` | `[]` |
| B `GET /api/notes?q=BETA` | `[{"id":24,"text":"beta three"}]` — case-insensitive, own notes only |
| C (no notes) `GET /api/notes` / `?q=nope` / `?q=beta` | `[]` `[]` `[]` — **never `null`** |

→ q can only narrow; no cross-user read. ✓

## P4 — Cross-user delete / id forms

| probe | observed |
|---|---|
| A `DELETE /api/notes/21` | 204 (own note) |
| A `DELETE /api/notes/24` (B's) | 404 `{"error":"not found"}` — indistinguishable from missing |
| B `DELETE /api/notes/21` (A's) | 404 |
| B `DELETE /api/notes/0021` | **404** (Atoi accepts `0021` → 21, owner check ran) — RT-08 reconfirmed |
| B `DELETE /api/notes/+21` | 404 (same, `+21`→21) |
| B `DELETE /api/notes/-21` | 404 (→ -21, absent) |
| B `DELETE /api/notes/21abc` | 400 `{"error":"invalid id"}` |
| B `DELETE /api/notes/99999999999999999999` | 400 `invalid id` (int overflow rejected) |
| B `DELETE /api/notes/` | 400 `invalid id` |
| B `DELETE /api/notes/21/2` | 400 `invalid id` (slash rejected) |
| B `DELETE /api/notes/%2e%2e` | 404 `not found` (path cleaned; no traversal) |
| B `DELETE /api/notes/0x21` | 400 `invalid id` |
| B `DELETE /api/notes/21%00` | **nginx** `400 Bad Request` HTML page (NUL rejected at edge, RT-E1546-2) |

→ non-canonical int forms accepted by the store layer but owner-scoped; canonical/foreign answers identical, so no oracle. ✓ (RT-08, low, unchanged)

## P5 — Query semantics & encoding safety (all A-token, all 200 unless noted)

| probe | observed |
|---|---|
| `q=` (empty) | 3 notes (all) |
| `q=%20%20` (whitespace) | 3 notes (all) — OD-1 |
| `q=+` raw on wire | 3 notes (decodes to space → whitespace-only → all) |
| `q=%2B` (literal `+`) | 0 notes (`[]`) |
| Cyrillic `пoe`, uppercase `%D0%9F%D0%9E` | 0, no crash |
| emoji `😀` | 0, no crash |
| `</script><svg onload=x>` | 0, no crash (data, never interpreted) |
| quotes/`;backtick | 0, no crash |
| invalid percent `q=%%` | 3 notes (Go decodes `%%` leniently as literal `%`; trim→whitespace→all) |
| tab+newline `%09%0A`, vertical tab `%0B` | 3 notes (whitespace-only → all) |
| ampersand `%26` | 0 |
| NUL in query `%00` | 0, no crash (app tolerates; NUL in **path** is stopped by nginx, see P4) |
| control char 0x04 | 0 |
| `beta%00zz` | 0 |
| multiple `?q=alpha&q=beta` | first value used → `[]` (21 already deleted) |
| 512-byte q | 200 (`[]`) |
| 513-byte q | **400 `{"error":"query too long"}`** — cap enforced pre-scan |

→ no 5xx/panic in the app layer on any encoding class. ✓

## P6 — Body / text limits, methods, unknown paths

| probe | observed |
|---|---|
| `POST /api/notes {"text":""}` / `{"text":"   "}` / `{"text":null}` | 400 `{"error":"text required"}` |
| `POST` non-JSON body | 400 `{"error":"invalid request body"}` |
| `POST` text 5000 bytes | 400 `text required` (>4096 cap) |
| `POST` text 4096 bytes | 201 (id 27) |
| `POST` 2 MB body | 400 `invalid request body` (MaxBytesReader 1 MiB) |
| `PUT/PATCH/DELETE /api/notes` (auth) | 405 `{"error":"method not allowed"}` + `Allow: GET, POST` |
| `GET /api/notes/extra` (unauth) | 401 (auth-first design, f-v3) |
| `GET /api/notes/extra` (auth, DELETE) | 400 `invalid id` |
| `GET /api/`, `/api/unknown` | 404 `{"error":"not found"}` |
| `GET /api` | **301** (nginx) → `/api/` → 404 JSON (RT-E1546-3) |
| `POST/PUT /app.js` | 405; `HEAD /app.js` 200 `text/javascript; charset=utf-8` + `cache-control: no-store` |

## P7 — UI / XSS (source review of served == repo assets)

- Sinks grep over `web/`: `innerHTML|outerHTML|document.write|eval(|new Function|insertAdjacentHTML|srcdoc` → **no matches** (only static hardcoded `href` in `index.html`).
- Dynamic rendering: `makeNote` clones a static `<template>` row, `text.textContent = "#" + note.id + " " + note.text`; `notesList.textContent = ""`; errors via `el.textContent`; aria-label via `setAttribute`. All data → text nodes only. **No XSS sink.**
- `location` only ever set to fixed literals (`/login`, `/register`, `/notes`) via `location.replace`; no user-controlled URL construction.
- Dead-end scan: every error branch (login 400/401, register 400/409, notes 401 → auto-redirect, network errors, delete 400/404 → `loadNotes()` reload) leaves a recoverable state; search clear/empty states mutually consistent. No new dead-end from the feature.

## P8 — New finding repro (RT-E1546-1, low)

1. A on `/notes` types `confidential topic` into `#notes-search` → `input` handler writes `sessionStorage['notebook.search']`.
2. User navigates manually to `/login` (no Logout click — Logout is the only UI path that clears `SEARCH_KEY`).
3. Login as B → `TOKEN_KEY` overwritten → `/notes`.
4. `initNotes()`: token present → `searchQuery = readStorage(sessionStorage, SEARCH_KEY)` → B's search box is pre-filled with A's query and the filter is applied to B's notes.
- Code refs: `web/app.js` `initNotes()` (restore on token present), `handleUnauthorized()`/logout (clear paths), `notesSearch.addEventListener("input")` (write). SEARCH-E2E-8 covers only the **no-token** path; the re-login-overwrite path is not covered.
- Impact: previous account's query string visible to next account in the same tab. No note data exposed (filter runs on B's own notes). Low, non-blocking.

## Result

No critical/high issues. No 5xx, no panics, no scope widening, no XSS sinks, no traversal. Verdict **pass**; follow-ups: RT-E1546-1 (clear search query on login overwrite), RT-08 (canonicalise DELETE id, optional), RT-E1546-2/3 (edge-layer envelope cosmetics, optional).
