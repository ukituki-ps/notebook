# Spec generation — f-v4-note-search (s14.spec_generation)

- **Step:** `s14.spec_generation`
- **Execution:** `E8363`
- **Feature:** `f-v4-note-search`
- **Platform:** `web` (`path1.ui.json.platform = "web"`, `feature_profile = full`)
- **Branch (this pass):** `dev/f-v4-note-search-validation-zero`
- **Base:** `5935e148` (`5935e148584b5fef28bd77ac4e45b800f10da03b`)
- **Pass type:** fresh E8363 re-validation of the existing spec against the code
  at this head. Only `spec/core.md`, `spec/contract-matrix.md`, and this review
  were written; no code, deploy, graph, path-1, auth, or persistence file was
  modified.
- **Verdict:** **PASS**
- **Contract rows checked:** **41** (30 API `C-01..C-30` + 11 UI `U-01..U-11`)
- **drift_count:** **0**

## Inputs reviewed

All paths relative to `/workspace/projects/notebook-valzero/`.

| Input | Observed state |
|---|---|
| `doc/идеи/f-v4-note-search/feature-brief.md` | FINAL/s06 E8363; API table, substring semantics, 10-state wireframes, AC 1–6; OD-6 non-contractual |
| `doc/идеи/f-v4-note-search/change-definition.md` | E8363 header; five domains; C1–C4 with files + acceptance; s10 corrections applied |
| `doc/идеи/f-v4-note-search/plan.md` | E8363; U01/U02/U03; T0001 handler-level filter; T0009 auth/notes-only integration smoke; 6 search E2E |
| `doc/идеи/f-v4-note-search/intent-brief.md` | E8363; R01–R45; OD-1/OD-2 closed; OD-6 proposed "do not persist" |
| `doc/идеи/f-v4-note-search/invariants.json` | 16 active + 2 proposed; all active have `test_ref`; search/UI sets present |
| `doc/идеи/f-v4-note-search/scope-report.md` | 4 domains; constraints 1–7; owner predicate first; auth → method → query |
| `doc/идеи/f-v4-note-search/expertise-report.md` | B-1…B-9; OD-1/OD-2 closed; interface freeze |
| `doc/идеи/f-v4-note-search/platform-dev-validation-zero/s10-change-definition.md` | D-1 no search API smoke; D-2 six E2E scenarios; D-3 full empty-state guard; D-4 OD-6 non-contract; D-5 handler-level filter; D-6 branch-label cleanup |
| `doc/идеи/f-v4-note-search/platform-dev-validation-zero/s11-plan.md` | Plan re-validation, E8363 metadata and corrected T0001/T0008/T0009 |
| `main.go` | `handleNotes`: auth first; `ListNotes(session.UserID)` snapshot; handler-level trim/lower substring filter; `[]` not `null`; unchanged envelopes |
| `main_test.go` | 8 `TestNotesSearch*` tests + existing auth/wire/status/transport tests (`TestAuthRequired`, `TestAuthMethodOrder`, `TestDelete*`, `TestNotesMethodNotAllowed`, `TestWireContract`, `TestHTTPTransport`, `TestUnknownAPINotFound`, `TestRegister`, `TestLogin`, `TestLoginInvalid`) |
| `web/index.html` | `notes-search`, `notes-search-clear`, `notes-search-empty`; labelled, `type=search`, `aria-controls`, `role=status`, `aria-live` |
| `web/app.js` | `filterNotes`; single `renderNotes`; guard `hasQuery && !noNotes && visible.length === 0`; create/delete/load re-render; `sessionStorage` restore is convenience only |
| `web/app.css` | Search styles present; `.notes-search-empty` rule is unused but harmless (s10 D-7) |
| `web_ui_test.go` | `TestUISemantics`: testids, label/a11y, filter, empty-state separation |
| `web/e2e/notes-search.spec.js` | `SEARCH-E2E-1..6`: find, not-found/empty, case, clear, create-active, delete-active |
| `web/e2e/auth-notes.spec.js` | `E2E-1..7`; E2E-6 user-B isolation; E2E-7 unauth 401 |
| `playwright.config.js` | `testDir: "web/e2e"`; Playwright 1.64.1; discovers the search spec |
| `path1.project.json` | Integration `E2E_API_ONLY=1 bash deploy/path1/e2e-preview.sh`; `UI-E2E-PREVIEW` oracle; no search-specific config |
| `deploy/path1/e2e-preview.sh` | Health/auth/notes API smoke only; `E2E_API_ONLY=1` exits before Playwright; no `q=` search assertion |
| `openapi/` search | **Absent** — no `openapi/*.yaml`, no generated API code, no contract-first pipeline |

## s10 corrections applied to the spec

1. **Handler-level filter.** `core.md` §1.1 now states explicitly that
   `ListNotes(session.UserID)` produces the owner-scoped snapshot and the
   handler filters that snapshot; there is no Store search helper. This matches
   `main.go` and s11 T0001.
2. **Integration smoke scope.** `core.md` §3 and the matrix state the smoke is
   auth/notes API only and has **no** search `q=` assertion; search is covered by
   the 6 Playwright scenarios at s20c.
3. **Six Playwright scenarios.** `SEARCH-E2E-1..6` (find, not-found/search-empty,
   case-insensitive, clear, create-active, delete-active). Login is a
   precondition; user-B isolation stays with auth E2E-6 and
   `TestNotesSearchIsolation`.
4. **Search-empty guard.** `core.md` §3 and matrix U-05 require all three:
   trimmed query non-empty, loaded collection non-empty, zero matches. Empty
   server list remains `notes-empty` (U-06).
5. **OD-6 non-contract.** `core.md` §3 and matrix "Non-contract note" label
   `sessionStorage` `notebook.search` reload-restore as implementation
   convenience only; reload must work, query persistence is not promised.
6. **Metadata settled.** This spec record uses E8363 /
   `dev/f-v4-note-search-validation-zero` / `5935e148` consistently. Historical
   E9294/`406fa965` and `validation/platform-dev-20261106-zero` labels remain
   only in prior artifacts and are not re-stamped here.

## Contract parity statement

This is an app repo, not an OpenAPI/generated-contract repo: there is no
`openapi/common.yaml`, no `openapi/modules/*`, no generated server/client code
and no contract-first pipeline (`specs[].openapi_path = ""`). Contract parity is
therefore measured against the checked rows in
`doc/идеи/f-v4-note-search/spec/contract-matrix.md`, each of which has an
executable oracle at this head.

- Contract rows checked: **41** (30 API + 11 UI).
- Rows with an executable oracle: **41/41**.
- Rows with a missing/ambiguous oracle: **0**.
- **`contract_parity.drift_count = 0`** — no un-oracled contract item and no
  divergence between `core.md`, `contract-matrix.md`, and the code/tests.

### items[] — contract rows checked

API rows:

| id | checked contract item | oracle |
|---|---|---|
| C-01 | `GET /api/notes` no `q` → 200 all own, `[]` not `null` | `TestNotesSearchEmptyQuery` |
| C-02 | `GET /api/notes?q=milk` → 200 case-insensitive substring matches only | `TestNotesSearchFinds` |
| C-03 | `GET /api/notes?q=HeLLo` → case-insensitive | `TestNotesSearchCaseInsensitive` |
| C-04 | `GET /api/notes?q=absent` → 200 `[]`, not null/404 | `TestNotesSearchNotFound` |
| C-05 | `GET /api/notes?q=` → 200 all own | `TestNotesSearchEmptyQuery` |
| C-06 | `GET /api/notes?q=whitespace` → 200 all own (OD-1) | `TestNotesSearchWhitespaceQuery` |
| C-07 | `GET /api/notes?q=shared` → owner-scoped only | `TestNotesSearchIsolation` |
| C-08 | `GET /api/notes?q=<encoded>` → URL-decode safe, no 500 | `TestNotesSearchEncoding` |
| C-09 | `GET /api/notes?q=x` no/bad bearer → 401 + `WWW-Authenticate` | `TestNotesSearchAuthRequired` |
| C-10 | `PUT /api/notes` no bearer → 401 before 405 (auth order) | `TestAuthMethodOrder` |
| C-11 | `DELETE /api/notes/{id}` no bearer → 401 before id validation | `TestAuthRequired` |
| C-12 | `PUT /api/notes` authed → 405 + `Allow: GET, POST` | `TestNotesMethodNotAllowed` |
| C-13 | `PATCH /api/notes` authed → 405 + `Allow: GET, POST` | `TestNotesMethodNotAllowed` |
| C-14 | `DELETE /api/notes` authed → 405 + `Allow: GET, POST` | `TestNotesMethodNotAllowed` |
| C-15 | `POST /api/notes` → 201 `{id,text}` | `TestAddNote` |
| C-16 | `POST /api/notes` blank text → 400 `text required` | `TestAddNote` |
| C-17 | `POST /api/notes` malformed body → 400 `invalid request body` | `TestAddNote` |
| C-18 | `POST /api/notes` no bearer → 401 + bearer | `TestAuthRequired` |
| C-19 | `DELETE /api/notes/{id}` own → 204 empty body | `TestDeleteNote` |
| C-20 | `DELETE /api/notes/{id}` invalid id → 400 `invalid id` | `TestDeleteInvalidID` |
| C-21 | `DELETE /api/notes/{id}` foreign/missing → 404 `not found` | `TestDeleteForeignNote` / `TestDeleteMissing` |
| C-22 | `GET /api/notes/{id}` → 405 + `Allow: DELETE` | `TestNotesMethodNotAllowed` |
| C-23 | `PUT /api/notes/{id}` → 405 + `Allow: DELETE` | `TestNotesMethodNotAllowed` |
| C-24 | unknown `/api/*` → 404 `not found` | `TestUnknownAPINotFound` |
| C-25 | wire keys `id`/`text` only, `UserID` hidden, `[]` not null | `TestWireContract` |
| C-26 | `/healthz` → 200 `ok` over real HTTP | `TestHTTPTransport` |
| C-27 | `POST /api/register` → 201 `{id,username}` | `TestRegister` |
| C-28 | `POST /api/register` duplicate → 409 `username taken` | `TestRegister` |
| C-29 | `POST /api/login` → 200 `{token}` | `TestLogin` |
| C-30 | `POST /api/login` bad credentials → 401 + bearer, indistinguishable | `TestLoginInvalid` |

UI rows:

| id | checked contract item | oracle |
|---|---|---|
| U-01 | Labelled `notes-search` input, `type=search`, `aria-controls`, above list | `TestUISemantics` |
| U-02 | `notes-search-clear` button, accessible name, hidden while empty | `TestUISemantics` |
| U-03 | Client-side live filter of loaded owner-scoped list, no per-keystroke request | `TestUISemantics` + `SEARCH-E2E-1` |
| U-04 | UI match is case-insensitive | `SEARCH-E2E-3` |
| U-05 | `notes-search-empty` only when trimmed query non-empty AND loaded collection non-empty AND zero matches | `TestUISemantics` + `SEARCH-E2E-2` / `SEARCH-E2E-6` |
| U-06 | Genuine empty server list → `notes-empty`, not `notes-search-empty` | `TestUISemantics` + auth `E2E-5` |
| U-07 | Clear restores full list | `SEARCH-E2E-4` |
| U-08 | Create while query active re-applies filter | `SEARCH-E2E-5` |
| U-09 | Delete while query active re-applies filter and transitions to search-empty correctly | `SEARCH-E2E-6` |
| U-10 | Login precondition; user-B isolation via auth E2E-6, not search spec | auth `E2E-6` + `TestNotesSearchIsolation` |
| U-11 | Loading/error/401 unchanged; search controls disabled while loading, usable when loaded | `TestUISemantics` + auth `E2E-7` |

Non-contract (not counted in 41): `sessionStorage` `notebook.search` reload
restore — OD-6 convenience, not part of the search contract.

## Gaps and residual notes

- **No blocking contract gap.** Every `core.md` §1/§3 item that is in scope has
  a matching matrix row and an executable oracle.
- **OD-6 (low, non-blocking).** `sessionStorage` query persistence remains
  needs-human from s07. The spec deliberately does not make it contract; if the
  owner later wants reload-persistent queries, that is an added behavior, not a
  correction to these rows.
- **s10 D-7 (cosmetic).** `web/app.css` defines `.notes-search-empty` while the
  DOM element uses `class="muted"`; unused rule, no functional impact, no
  contract row.
- **Historical metadata (cosmetic).** Some prior artifacts still carry
  E9294/`dev/f-v4-note-search`/`406fa965` or
  `validation/platform-dev-20261106-zero`. This spec record settles on
  E8363/`dev/f-v4-note-search-validation-zero`/`5935e148`; prior files were not
  re-stamped per the s14 scope.
- **Proposed invariants.** `INV-UI-ORACLE` and `INV-UI-E2E-PREVIEW` stay
  proposed until s22a/s20c evidence exists; they are not counted as active
  contract rows.

## Files written

1. `doc/идеи/f-v4-note-search/spec/core.md` — E8363 metadata, handler-level
   filter, corrected integration/E2E/empty-state/OD-6 wording, parity statement.
2. `doc/идеи/f-v4-note-search/spec/contract-matrix.md` — 41 rows with oracles,
   auth/status/envelope/auth-order/search-UI coverage, non-contract OD-6 note.
3. `doc/идеи/f-v4-note-search/platform-dev-validation-zero/s14-spec.md` — this
   review.

Absolute paths:

- `/workspace/projects/notebook-valzero/doc/идеи/f-v4-note-search/spec/core.md`
- `/workspace/projects/notebook-valzero/doc/идеи/f-v4-note-search/spec/contract-matrix.md`
- `/workspace/projects/notebook-valzero/doc/идеи/f-v4-note-search/platform-dev-validation-zero/s14-spec.md`

## Limitations

- Per instruction, **no git commands were run**; verification is against the
  working tree at this head, not a base diff.
- No code, deploy script, graph, path-1, auth, or persistence file was changed.
- The row count is the count of the matrix rows above (30 API + 11 UI); the
  non-contract OD-6 note is intentionally excluded.
