# UI/UX audit — f-v4-note-search (E8363)

- Platform: web
- Stand: https://test2.nexus.ukituki.tech, build **c267619** (commit `c2676199e5876abbb61a0030c01049bd782248ac`, image `sha256:b8d61aec…`, build_args `sha256:2c2f2727…`)
- Execution: E8363, step s22a.ui_audit
- Scope: notes screen search controls (web blocks A–L), deployed via s20b and verified by s20c.
- Result: **accept** — 0 blockers, 0 open critical/high, 0 majors, 0 minors,
  1 cosmetic (unused `.notes-search-empty` CSS rule, no behavioural effect).

## Checklist A–L

| Block | Check | Verdict | Oracle / evidence |
|---|---|---|---|
| A | Search states coherent (idle, filtering, results, empty, cleared, after-mutation) | ok | `sh: grep -q 'notesSearchEmpty.hidden' web/app.js && grep -q 'SEARCH-E2E-6' web/e2e/notes-search.spec.js` — E2E-1..6 pass |
| B | Empty state informative; `notes-search-empty` only for non-empty query with 0 matches | ok | `dom: [data-testid=notes-search-empty][role=status][aria-live=polite]`; SEARCH-E2E-2/6 screenshots |
| C | Visible label/placeholder; clear control obvious | ok | `dom: label[for=notes-search] + input#notes-search[type=search] + button#notes-search-clear[aria-label]`; SEARCH-E2E-3 |
| D | Fits the existing visual system | ok | `sh: grep -q 'notes-search' web/app.css` — reuses `--border`, `--bg`, accent tokens |
| E | Search above list; controls do not overlap | ok | `file:web_ui_test.go::TestUISemantics` (search above notes-list); SEARCH-E2E-1 |
| F | Create/delete re-apply the active query; clear restores list | ok | `file:web_ui_test.go::TestUISemantics`; SEARCH-E2E-4/5/6 |
| G | A11y: label, `aria-controls`, `role=status`, `aria-live`, clear accessible name | ok | `file:web_ui_test.go::TestUISemantics`; `:focus-visible` in `web/app.css` |
| H | Responsive stacking on narrow screens | ok | `sh: grep -q '@media (max-width: 640px)' web/app.css` — search row stacks, clear full width |
| I | Owner-scoped API, `[]` on empty, `UserID` hidden | ok | `cmd:GOWORK=off go test -count=1 -run TestNotesSearch ./...` — 8/8 pass |
| J | Filter is local, one render path, no extra requests | ok | `file:web_ui_test.go::TestUISemantics` — single `filterNotes()`/`renderNotes()`, one `appendChild(makeNote(` |
| K | Complete search scenarios green on the stand | ok | `file:web/e2e/notes-search.spec.js::SEARCH-E2E-6`; `scenario-evidence.json` 6/6 pass on c267619 |
| L | Evidence tied to stand SHA, element/state screenshots | ok | `sh: test -s …/SEARCH-E2E-6.png && test -s …/SEARCH-E2E-1.png` — 6 distinct shots ≥5 KB |

## Screenshot review (element/state, not full-page)

| File | Size (px) | Bytes | State |
|---|---|---|---|
| SEARCH-E2E-1.png | 566×68 | 7028 | list/results — matching note only |
| SEARCH-E2E-2.png | 608×430 | 22882 | search-empty — non-matching query |
| SEARCH-E2E-3.png | 566×75 | 8192 | case-insensitive match (query lower-case, note upper-case) |
| SEARCH-E2E-4.png | 566×145 | 11988 | clear — full list restored |
| SEARCH-E2E-5.png | 566×145 | 13692 | create while query active — filter re-applied |
| SEARCH-E2E-6.png | 608×430 | 21156 | delete while query active — search-empty after last match removed |

All six are element/state clips cropped from `notes-list`, `.notes-search`, or `.card.notes`
(never the full 1000×800/1100×900 page), are ≥5 KB, and have distinct SHA-256 values
(`evidence-manifest.json`). `preview-verdict.json` reports `result=pass`, `status=verified`,
`evaluated_sha=c2676199…`, `ref=c267619`.

## Notes

- Stand SHA in this audit is the deployed build ref `c267619` (not local HEAD, not the
  graph actualization SHA `eeacf65`).
- Backend contract supports `GET /api/notes?q=` (owner-scoped, case-insensitive, `[]` on miss).
- Cosmetic: `.notes-search-empty` CSS selector is unused (the status element uses the shared
  `muted` class). No layout or behaviour impact.
- No violations found; no new findings beyond the carried cosmetic item.
