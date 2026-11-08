# Unit spec-sync — notebook-search-api (U01)

- **Execution:** E0809-s20.sde_5fexecution-u01
- **Step:** s16.unit_spec_sync
- **Branch:** `orc-exec-E0809-s20.sde_5fexecution-u01` · **Base:** `f5943f5` · **HEAD:** `a799630`
- **verified_by:** architect session (independent reviewer; executor was `sde-backend`)
- **Date:** 2026-11-08
- **synced:** **true**
- **Drift:** **none**

## Mapping — `spec/core.md` §1 → code/tests

| Spec clause (`§1.1 GET /api/notes?q=`) | Implementation | Test oracle | Status |
|---|---|---|---|
| Auth before method/query; 401 + `WWW-Authenticate: Bearer` + `{"error":"unauthorized"}` | `main.go:450-459` (`requireAuth`), `main.go:531-534` | `TestNotesSearchAuthRequired`, `TestAuthRequired` | synced |
| `q` decoded by `net/http` from the query string | `main.go:541` (`r.URL.Query().Get("q")`) | `TestNotesSearchEncoding` | synced |
| 512-byte cap on decoded `q`, before `ListNotes`; `>512` → `400 {"error":"query too long"}` | `main.go:542-545`; `ListNotes` at `main.go:547` | `TestNotesSearchQueryTooLong` | synced |
| Exactly 512 bytes accepted; cap is bytes, not runes | `main.go:542` (`>` not `>=`) | `TestNotesSearchQueryTooLong` (exactly-512 and multibyte 512/514 cases) | synced |
| Cap evaluated before trim; >512 whitespace-only `q` → 400 | cap `main.go:541-545` precedes `TrimSpace` `main.go:546` | `TestNotesSearchQueryTooLong` (whitespace-only case) | synced |
| `TrimSpace`; absent/`q=`/whitespace-only → all own notes | `main.go:546` | `TestNotesSearchEmptyQuery`, `TestNotesSearchWhitespaceQuery` | synced |
| Non-empty trimmed `q` → case-insensitive substring with `strings.ToLower` both sides | `main.go:546,551` | `TestNotesSearchFinds`, `TestNotesSearchCaseInsensitive` | synced |
| Owner predicate first: `ListNotes(session.UserID)`, then text filter; `q` narrows, never widens | `main.go:547`; `main.go:193-206`; filter `main.go:548-556` | `TestNotesSearchIsolation`, `TestNotesIsolation` | synced |
| No matches → `200` with `[]` (never `null`) | non-nil slice `main.go:198` (`make([]Note, 0)`) | `TestNotesSearchNotFound`, `TestNotesSearchEmptyQuery`, `TestWireContract` | synced |
| `200` array of `{"id":N,"text":"..."}`; keys lower-case; `UserID` `json:"-"` | `Note` `main.go:67-71` | `TestWireContract`, `TestNotesSearchIsolation` | synced |
| Encoding-safe decoding (`%20`, `+`, `%2B`, `&`, emoji, Cyrillic), no panic/500 | `net/http` query decoding + `main.go:541` | `TestNotesSearchEncoding`, multibyte case in `TestNotesSearchQueryTooLong` | synced |
| `PUT`/`DELETE`/unknown method on `/api/notes` → `405` + `Allow: GET, POST` | `main.go:569-572` | `TestAuthMethodOrder` / method tests | synced (unchanged) |

## Out-of-scope spec sections

- `§1.2` unchanged operations (`POST /api/register`, `POST /api/login`,
  `POST /api/notes`, `DELETE /api/notes/{id}`) — untouched by this unit.
- `§2` data model — unchanged; `Store` is still in-memory, `Note` shape intact.
- `§3` UI contract — not part of U01; `web/`, `design/`, `frontend/` have a zero
  diff against the base.

## Conclusion

The shipped behaviour matches `spec/core.md` §1 exactly, and every normative
clause has an executable Go oracle. No spec text was changed at this step and no
implementation/spec drift was found.
