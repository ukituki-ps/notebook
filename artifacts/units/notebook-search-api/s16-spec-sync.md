# s16 spec sync — notebook-search-api

- Feature: `f-v4-note-search`
- Execution: `E8363-s20.sde_5fexecution-u01`
- Unit: `notebook-search-api`
- Branch: `orc-exec-E8363-s20.sde_5fexecution-u01`
- HEAD checked: `f6396ad42f913b4fba70882d2dbba66e03f48515`
  (branch tip at report time `94daa77`, artifacts-only s15 commit; source
  identical to evidence HEAD `9ceafdb`)
- Spec inputs: `spec/core.md` §1.1, §1.2, §4;
  `spec/contract-matrix.md` rows `C-01..C-30` (API), `U-01..U-11` (UI, not
  owned by this unit); `T0001` and `T0004` briefs.
- `drift_count: 0` for the backend surface

## API row → implementation → oracle

| Row | Contract | Code evidence | Oracle (reproduced) | Status |
|---|---|---|---|---|
| C-01 | `GET /api/notes` no `q` → all own notes, `[]` not `null` | `main.go:539`, `ListNotes` `main.go:194-205` | `TestNotesSearchEmptyQuery` (unfiltered comparison), `TestWireContract` | synced |
| C-02 | `q` substring, only matching own notes | `main.go:538,540-548` | `TestNotesSearchFinds` | synced |
| C-03 | case-insensitive same result | `main.go:538,543` (`ToLower` both sides) | `TestNotesSearchCaseInsensitive` | synced |
| C-04 | no match → `200 []`, never 404/null | `make([]Note,0,...)` `main.go:541` | `TestNotesSearchNotFound` (exact `[]`) | synced |
| C-05 | `q=` → all own notes | `main.go:540` empty-query guard | `TestNotesSearchEmptyQuery` | synced |
| C-06 | whitespace-only `q` → all own notes (OD-1) | `TrimSpace` `main.go:538` | `TestNotesSearchWhitespaceQuery` | synced |
| C-07 | owner-scoped; user B's match not returned | `ListNotes(session.UserID)` `main.go:539` | `TestNotesSearchIsolation` | synced |
| C-08 | URL-encoded `%`, space, `&`, `+` safe | `r.URL.Query().Get("q")` `main.go:538` | `TestNotesSearchEncoding` (`%25`, `%20`, `%26`, `%2B`) | synced (see note) |
| C-09 | no/bad token + `q` → 401 + bearer | `requireAuth` `main.go:449-458`, called `main.go:530` | `TestNotesSearchAuthRequired` | synced |
| C-10 | auth before method | `requireAuth` before switch `main.go:530-534` | `TestAuthMethodOrder` | synced |
| C-11 | auth before id validation | `handleNoteItem` `main.go:567-575` | `TestAuthRequired` | synced |
| C-12 | `PUT /api/notes` → 405 + `Allow: GET, POST` | `handleNotes` default `main.go:560-563` | `TestNotesMethodNotAllowed` | synced |
| C-13 | `PATCH /api/notes` → 405 | same default | `TestNotesMethodNotAllowed` | synced |
| C-14 | `DELETE /api/notes` → 405 | same default | `TestNotesMethodNotAllowed` | synced |
| C-15 | `POST /api/notes` → 201 `{id,text}` | `handleNotes` POST `main.go:549-559` | `TestAddNote` | synced |
| C-16 | POST blank/oversized → `text required` | `validText` guard | `TestAddNote` | synced |
| C-17 | POST malformed JSON → `invalid request body` | `decodeJSON` guard | `TestAddNote` | synced |
| C-18 | POST no token → 401 + bearer | `requireAuth` first | `TestAuthRequired` | synced |
| C-19 | `DELETE /api/notes/{id}` own → 204 empty | `handleNoteItem` | `TestDeleteNote` | synced |
| C-20 | invalid id → 400 `invalid id` | `handleNoteItem` | `TestDeleteInvalidID` | synced |
| C-21 | foreign/missing → 404 `not found` | store delete result | `TestDeleteForeignNote`, `TestDeleteMissing` | synced |
| C-22 | `GET /api/notes/{id}` → 405 `Allow: DELETE` | `handleNoteItem` | `TestNotesMethodNotAllowed` | synced |
| C-23 | `PUT /api/notes/{id}` → 405 `Allow: DELETE` | `handleNoteItem` | `TestNotesMethodNotAllowed` | synced |
| C-24 | unknown `/api/*` → 404 JSON | `handleAPINotFound` `main.go:459-461` | `TestUnknownAPINotFound` | synced |
| C-25 | wire keys `id`/`text`, `UserID` hidden, `[]` not null | `Note` tags `main.go:66-70` | `TestWireContract`, `TestNotesSearchIsolation` | synced |
| C-26 | `/healthz` 200 `ok` over real HTTP | server mux | `TestHTTPTransport` | synced |
| C-27 | register 201 `{id,username}`, no secret | `handleRegister` | `TestRegister` | synced |
| C-28 | duplicate register 409 `username taken` | `handleRegister` | `TestRegister` | synced |
| C-29 | login 200 `{token}` opaque base64url | `handleLogin` | `TestLogin` | synced |
| C-30 | login invalid 401 + bearer, indistinguishable | `handleLogin` | `TestLoginInvalid` | synced |

## Invariant mapping

- `INV-SEARCH-OWNER-SCOPE` → `TestNotesSearchIsolation` — pass.
- `INV-SEARCH-CASE-INSENSITIVE` → `TestNotesSearchFinds`,
  `TestNotesSearchCaseInsensitive` — pass.
- `INV-SEARCH-EMPTY-Q` → `TestNotesSearchEmptyQuery`,
  `TestNotesSearchWhitespaceQuery` — pass.
- `INV-SEARCH-NOT-FOUND` → `TestNotesSearchNotFound` — pass.
- `INV-SEARCH-AUTH-REQUIRED` → `TestNotesSearchAuthRequired` — pass.
- `INV-SEARCH-ENCODING` → `TestNotesSearchEncoding` — pass.
- `INV-WIRE-CASING` / `INV-REAL-TRANSPORT` → `TestWireContract`,
  `TestHTTPTransport` — pass.
- `INV-AUTH-REQUIRED` / `INV-USER-ISOLATION` → `TestAuthRequired`,
  `TestAuthMethodOrder`, `TestLoginInvalid`, `TestNotesIsolation` — pass.

UI invariants (`INV-SEARCH-UI-*`, `INV-UI-*`) are owned and evidenced by
`notebook-search-ui`; this unit does not claim them.

## Drift assessment

- `spec/core.md` §1.1 describes a handler-level filter over
  `ListNotes(session.UserID)`; `main.go:529-565` matches exactly.
- `[]` not `null` is guaranteed by non-nil slice construction and asserted
  literally.
- No existing status code, envelope, wire key, or auth ordering changed.
- Minor documentation nuance (not code drift): C-08 names raw `+`, while the
  oracle asserts `%20` (space) and `%2B` (literal plus). `net/http` decoding is
  the shared implementation for both; no spec edit is warranted for this
  re-validation pass.

**Verdict: IN SYNC — `drift_count = 0`, no spec or code change required.**
