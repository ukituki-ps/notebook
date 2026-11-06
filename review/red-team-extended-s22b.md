# Red-team audit — f-v4-note-search (s22b)

- **Execution:** E8363 · **Step:** `s22b.red_team_audit` · **Feature:** `f-v4-note-search` · **Platform:** web
- **Stand:** `https://test2.nexus.ukituki.tech` · **Build:** `c267619` (`c2676199e5876abbb61a0030c01049bd782248ac`)
- **Reviewer:** `ses_e4ce490f2ffeHQ74mtLOpgetm8` · **Author:** `ses_e4d243d58ffeXi7t5U6T5BP5Tx`
- **Mode:** read-only + live probing of test2 only; synthetic users/notes only; no prod/preprod/test1, no destructive writes, no code changes, no git writes.

## Stand / build attestation
- `GET /healthz` → `200 {"build_ref":"c267619","commit":"c2676199…"}` — stand self-reports the target commit.
- Served `/app.js` SHA256 `239a8af4…` == repo `web/app.js`; served `/login` SHA256 `cced7a79…` == repo `web/index.html`. Running build matches reviewed source.
- Worktree HEAD `eeec54c` is a docs-only descendant of `c267619`; `git diff c267619..HEAD -- main.go main_test.go web/` empty → source is byte-identical to the deployed build.

## Verdict
**PASS — no critical, high, or medium findings.** 58 adversarial attempts; all verdicts `safe`. Two low / informational hardening notes.

## Attack log

### 1. Auth bypass / order — SAFE
All missing/malformed bearer paths return `401` **before** method/query/id handling. Missing header, bare `Bearer`, `Bearer`+spaces, lowercase `bearer xyz`, wrong-scheme `Basic`, garbage bearer → `401`. No-token `PUT/POST/DELETE` → `401` (not `405`/`400`) confirms auth-before-method. Query + bad token still `401`, no scope leak.

### 2. Owner isolation — SAFE
User B: `GET /api/notes` → only B's notes; `q=SECRET_A`/`q=milk` → `[]`; `DELETE` A's notes → `404` (no 500, no cross-tenant delete); `q=shared` → only B's own `shared token`, not A's `shared` note. Symmetric from A: `q=SECRET_B` → `[]`; `DELETE` B's note → `404`. Search never widens scope.

### 3. `q` abuse — SAFE (no 500/panic; no wildcard broadening)
| probe | observed | note |
|---|---|---|
| `q=` / `q=%20` / `q=%20%20%20` | 200 all own | whitespace-only → all own (OD-1) |
| `q=%25` (literal `%`) | 200 only the literal-`%` note | **proves `strings.Contains`, not LIKE** (a LIKE `%` would return all) |
| `q=_` / `q=%5F` | 200 only literal-`_` notes | no single-char wildcard broadening |
| `q=%2B` / `q=%26` | 200 [] / literal-`&` note | decoded by net/http |
| `q=+` / `q=&milk=1` / `q=%0A%09` | 200 all own | `+`→space, `&`→empty; whitespace-only |
| `q=1' OR '1'='1` · `q=%3B+DROP+TABLE…` | 200 [] | literal substring; no DB → no injection, no 500 |
| `q=%zz` / `q=zz%` (invalid %) | 200 all **own** notes | value decodes to `""` → filter skipped; still owner-scoped (F1) |
| `q=hello%00world` / `q=%00` | 200 [] | null byte handled, no panic |
| `q=привет` (Cyrillic) | 200 [] | unicode handled, no 500 |
| `q=` ×20000 chars | **414** Request-URI Too Large | bounded at nginx ingress before the app (F2) |

Exact decode semantics confirmed against deployed Go `url` behaviour (`%zz`/`zz%`→`""`; `%25`→`%`; `%00`→`\x00`), matching live responses.

### 4. Method / status — SAFE
`PUT/PATCH/DELETE` on `/api/notes` → `405` (`Allow: GET, POST`); `GET/PUT/PATCH` on `/api/notes/{id}` → `405` (`Allow: DELETE`); `DELETE /api/notes` (no id) → `405`. `abc`/`/`/`35/extra` → `400 invalid id`. `999999`/`-5`/foreign/missing → `404` (no 500). Unknown `/api/foo` → `404`; `/api` → nginx `301` → `/api/` → `404`. Re-delete after `204` → `404`, no panic.

### 5. UI (served `/app.js`) — SAFE
- No per-keystroke network: search `input` handler calls only `renderNotes()`+storage; the sole `/api/notes` GET is in `loadNotes()` (init/reload).
- No phantom/hardcoded notes: `notes=[]` populated only from API `res.data`; template `.note-text` empty.
- Empty-state guard vs whitespace-only q: `hasQuery=searchQuery.trim()!==""`; `notes-search-empty` shown only when `hasQuery && !noNotes && visible==0` → whitespace q cannot force it.
- Clear restores the full list. XSS-safe: note text via `text.textContent`, no `innerHTML`.

## Findings
**No critical, high, or medium severity findings.**
- **F1 (low):** invalid percent-escapes in `q` (e.g. `q=%zz`, `q=zz%`) decode to `""` (Go `net/url`) → filter skipped → all **own** notes, not `[]`. Owner-scoped; no leak/500/panic. Hardening: reject/normalize invalid percent-escapes.
- **F2 (low):** no per-user note cap in the shared in-memory store → `ListNotes`/search are O(total notes) per call (self/cross-tenant CPU load). Long-q DoS already mitigated at ingress (`414`). Hardening: cap notes-per-user / total notes.

## Counts
| critical | high | medium | low |
|---|---|---|---|
| 0 | 0 | 0 | 2 |

**Verdict: pass.**
