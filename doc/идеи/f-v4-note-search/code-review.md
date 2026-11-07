# f-v4-note-search — s22c adversarial code review (E1546)

- **Execution:** E1546, step `s22c.adversarial_code_review`
- **Reviewer:** qwen3.8-fast / llama-proxy (session `ses_e4907f767ffe2ggtCgNm2loouU`), independent of the author
- **Author:** deepseek/deepseek-flash / deepseek, session `ses_e492b197fffeN08PUKpdAXLjP8`
- **Verdict: PASS — 0 confirmed critical/high**
- **checked_at:** 2026-11-07T17:09:16Z

## Scope

Worktree `/tmp/kilo/E1546`, execution branch `orc-exec-E1546` at tip `8c0f5f1`
(base `9723acd`). The `9723acd..8c0f5f1` range is **docs/artifacts only**:
`main.go`, `main_test.go`, `web/*`, `web_ui_test.go` are byte-identical between
`a95876d` (the commit the s22b red team live-verified on stand test2) and the
reviewed tip, so this review covers the full feature code at the tip. The
`dev/f-v4-note-search-ae079e5c` branch pointer sits at `738edbb`; the review
target is the execution-branch tip `8c0f5f1`.

Files inspected in full: `main.go`, `main_test.go`, `web/index.html`,
`web/app.js`, `web/app.css`, `web_ui_test.go`, `web/e2e/notes-search.spec.js`,
`spec/core.md`, `spec/contract-matrix.md`, `invariants.json`,
`fault-verdicts.json`, plus the red-team `red-team-review.json` /
`red-team-attack-log.md` for cross-check.

## Build / vet / test

| check | command | result |
|---|---|---|
| build | `cd /tmp/kilo/E1546 && go build ./...` | **pass** |
| vet | `go vet ./...` | **pass** |
| full suite | `go test -count=1 ./...` | **pass** — `ok github.com/ukituki-ps/notebook 2.833s` |
| targeted | `go test -count=1 -v -run 'TestNotesSearch\|TestUISemantics\|TestAuthRequired\|TestNotesIsolation\|TestAuthMethodOrder' .` | **pass** — 13/13 |
| race | `CGO_ENABLED=1 go test -count=1 -race ./...` | not run — no gcc/cgo toolchain on the reviewer host; lock discipline verified by inspection |

Concurrency by inspection: every `Store` map is guarded by `s.mu`; PBKDF2 runs
outside the lock; `regMu` serializes the registration check-hash-insert
sequence; tests swap `store.now` under the lock. No data races identified.

## Spec-vs-behaviour verification (core.md §1.1/§3 vs code)

| spec requirement | actual behaviour | verdict |
|---|---|---|
| `q` trimmed | `strings.ToLower(strings.TrimSpace(rawQuery))` (main.go:546) | ok |
| case-insensitive substring, both sides | `strings.Contains(ToLower(note.Text), ToLower(q))` (main.go:551) | ok |
| owner-first: `q` can only narrow | `ListNotes(session.UserID)` first; filter is a subset (main.go:547-556); `TestNotesSearchIsolation` | ok |
| no match / empty list → `[]`, never `null` | `ListNotes` returns `make([]Note, 0)`; filtered slice non-nil; `TestNotesSearchNotFound` asserts body `[]` | ok |
| 401 before query handling | `requireAuth` before method/query switch; `WWW-Authenticate: Bearer`; `TestNotesSearchAuthRequired` (unauth + unknown-token) | ok |
| URL-encoded/special chars safe, no panic/500 | `r.URL.Query().Get("q")`; `TestNotesSearchEncoding` (%25/%20/%26/%2B); red team live-verified Cyrillic/emoji/HTML/NUL/control classes → 200 | ok |
| UI: `notes-search` input, labelled, `type=search`, `aria-controls=notes-list` | index.html:77-87; enforced by `TestUISemantics` | ok |
| clear control (accessible name) restores full list | `notes-search-clear` (aria-label «Очистить поиск»); resets query, clears storage key, re-renders; SEARCH-E2E-4 | ok |
| live client-side filtering, no request per keystroke | input listener → `filterNotes()` + `renderNotes()` only; grep confirms no `q=` in client requests | ok |
| empty state `notes-search-empty` only for active query with no matches; `notes-empty` kept for empty server list | `notesSearchEmpty.hidden = !(hasQuery && !noNotes && visible.length===0)` (app.js:387); SEARCH-E2E-2/6 | ok |
| create/delete/reload re-apply active query | single `renderNotes()` funnel; SEARCH-E2E-5/6 | ok |
| UI testids | `TestUISemantics` asserts the full set incl. `notes-search`/`notes-search-clear`/`notes-search-empty`; legacy ids absent | ok |

XSS: `makeNote` uses `textContent` (app.js:341); delete button label via
`setAttribute` with a numeric id; template rows inert; zero matches for
`innerHTML/outerHTML/document.write/eval/new Function` in `app.js`. Static
error envelopes, no secret/stack leakage; `UserID` is `json:"-"` on the wire.

## Findings

| id | severity | status | title |
|---|---|---|---|
| CR-E1546-01 | low | confirmed | 512-byte `q` cap (400 «query too long») undocumented in spec/matrix |
| CR-E1546-02 | low | confirmed | Per-tab search query survives account switch without Logout (RT-E1546-1, open) |
| CR-E1546-03 | low | confirmed | DELETE id accepts non-canonical Atoi forms (RT-08) |
| CR-E1546-04 | info | refuted | Suspected stored XSS — refuted (textContent only) |
| CR-E1546-05 | info | confirmed | Dead `note.title` branch in `noteSearchText` (intentional) |
| CR-E1546-06 | info | confirmed | `invariants.json` branch provenance mismatch |
| CR-E1546-07 | info | confirmed | nginx edge: HTML 400 on NUL-in-URI, 301 on `GET /api` |
| CR-E1546-08 | info | accepted | Unbounded notes / per-request ToLower (self-DoS nuance) |

### CR-E1546-01 (low) — undocumented `q` length cap
`handleNotes` (main.go:542) caps the raw query at `maxQueryBytes=512` and
answers `400 {"error":"query too long"}` — an RT-NEW-2 hardening. The spec
`core.md` §1.1 error table and `contract-matrix.md` do **not** list this 400;
it is recorded only in the red-team attack log and `TestNotesSearchQueryTooLong`.
Consequences: (a) the cap is checked *before* the trim/empty check, so a
whitespace-only `q` of 513+ bytes returns 400 instead of the OD-1 "all notes"
behaviour; (b) the cap is byte-based, so a legitimate ~512-byte Cyrillic query
(≈170 runes) is rejected. No security or data impact. Action: document the cap
and boundary semantics in spec/matrix (or explicitly mark as accepted
hardening).

### CR-E1546-02 (low) — search query leaks to next account in the same tab
Successful login (app.js:173-178) overwrites `TOKEN_KEY`/`USER_KEY` and
redirects to `/notes` without clearing `notebook.search`; `initNotes()` then
restores the stale query for the new account. `SEARCH_KEY` is cleared on
no-token init, 401, clear-click, and logout — but not on login overwrite.
Repro: A searches → navigates to `/login` without Logout → B logs in → B's box
is pre-filled with A's query. Only the query string is exposed (filtering stays
owner-scoped; no note data). This is the red team's **RT-E1546-1 (status
open)** — confirmed still open at tip; `SEARCH-E2E-8` covers only the
no-token path. Mitigation: clear `SEARCH_KEY` on successful login or key it
per user.

### CR-E1546-03 (low) — non-canonical DELETE ids
`strconv.Atoi` (main.go:590) accepts `+5`, `007`, `0021` as valid ids.
`DeleteNote` re-scopes to the session owner, so there is no cross-tenant
impact; red team reconfirmed live (RT-08: 0021/+21/-21 → owner-scoped 404,
no extra oracle vs the canonical form). Inherited from f-v3; consistent with
E1688 CR-F4-01. Optional: restrict to unsigned decimal.

### CR-E1546-04..08 (info)
- **04 refuted:** stored-XSS suspicion — `note.text` rendered via `textContent`,
  inert `<template>` rows, no DOM-injection sinks anywhere in `app.js`.
- **05:** `noteSearchText()` (app.js:355) matches `note.title`, a field the API
  never exposes (`{id,text}` only per `TestWireContract`); deliberate
  future-proofing, zero behaviour impact.
- **06:** `invariants.json` execution_id was fixed E9294→E1546 in this range
  (resolving E1688 CR-F4-02), but `branch` still reads
  `dev/f-v4-note-search` vs the actual execution branch
  `dev/f-v4-note-search-ae079e5c`. Cosmetic provenance note.
- **07:** nginx edge returns an HTML 400 for NUL-in-URI and 301-redirects
  `GET /api` (then 404 JSON). App code is correct; edge-layer cosmetic
  deviation on RFC-invalid input; traversal probes yield 404 JSON. No action
  in app code.
- **08 (accepted):** no per-user note cap + per-request O(n) `ToLower` —
  self-DoS/perf nuance, in-memory app, no external victim (RT-09/RT-10).

## Red-team cross-check

All s22b findings hold up against the code: RT-E1546-1 (low, open) confirmed
in the login path; RT-E1546-2/3 (info) are edge-layer, consistent with
`handleAPINotFound`; RT-08 confirmed at main.go:590; RT-09/10/11 accepted as
documented design notes. No red-team finding was overstated; one new
documentation gap (CR-E1546-01) found by the independent code read.

## Residuals (non-blocking)

- No new dead-end states introduced by the feature: 401 → redirect to
  `/login`; load error shows a message (no retry button — pre-existing f-v3
  nuance, reload recovers); logout → `/login`.
- Open: clear `notebook.search` on successful login (or key it per user) —
  RT-E1546-1 / CR-E1546-02.
- Docs: add the 512-byte `q` cap + boundary semantics to spec/matrix —
  CR-E1546-01.

## Result

**Verdict: PASS.** Confirmed critical: 0. Confirmed high: 0. Low: 3
(CR-E1546-01 new documentation gap; CR-E1546-02 red-team open low
reconfirmed; CR-E1546-03 inherited). Info: 5. Build/vet/full-test green.
No code changes made by this review (read-only).
