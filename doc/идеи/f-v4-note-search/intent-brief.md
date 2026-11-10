# Intent brief — f-v4-note-search (E6636, s07)

- Execution **E6636** · path-10 A/B arm `notebook-path10-15` · branch
  `dev/path10-runner-13` · base `9e7fae35`
- Raw request: `feature-request.md` (45 items, immutable capture 2026-11-05)
- Machine trace: `intent-trace.json` — **45/45 items**, no `missing`/`dropped`
- Design basis: approved `prototypes/v7` on Notebook DS **1.0.1**; planned graph
  `UI-GRAPH.planned.yaml` (s04)
- Human checkpoint: this brief is approved at **s08** (intent-brief review)

## Goal

Give the signed-in user a small, owner-scoped text search over their notes, on
the existing notes screen and the existing `GET /api/notes` endpoint, without
changing auth, storage, or note lifecycle.

## «Просил → делаем»

| Raw request | What we do (E6636) | Verdict |
|---|---|---|
| R01–R11 process: new small feature, path-1, entry/default, web/full, base and work branch, skip s45/s46, no f-v3/E4312/E1320 churn, no prod/canary, gates s21/s22a/s22b/s22c/s24, no force/skip/waiver, s20 fan-out | Run E6636 on `path-1.feature@4.0.0` (current canon), entry `default`, web/full; base `9e7fae35` (descendant of the requested `406fa965`); work branch `dev/path10-runner-13` (harness-assigned); s45/s46 skipped; gates and no-waiver rules kept; fan-out checked at s20 | 9 match, 2 reinterpreted (R02 process 4.0.0, R04 run branch) |
| R12–R17 API: `GET /api/notes?q=`, no q → all, q → case-insensitive, own notes only, no bearer → 401, empty q → all | Implemented and tested exactly: `maxQueryBytes=512`, owner predicate before text predicate, `200 []` on no match | 6 match |
| R18 whitespace-only q → spec must fix all-notes or 400 | Fixed as **all notes** (trim → empty → all); invariant `INV-SEARCH-EMPTY-Q` | reinterpreted (confirmed) |
| R19–R23 tests: find, not found, isolation, 401, encoding | Go tests `TestNotesSearchFinds/NotFound/Isolation/AuthRequired/Encoding` (+ whitespace/512-cap) | 5 match |
| R24–R28 UI: search field, filter, clear restores list, "ничего не найдено", do not break create/delete/reload | Search field + clear + client-side filter; single `renderNotes()` re-applies the query after load/create/delete; `notes-search-empty` only for a non-empty query on a non-empty collection | 5 match |
| R29–R30 testids; actualize UI graph | `notes-search`, `notes-search-clear`, `notes-search-count`, `notes-search-empty`; planned graph at s04, from-code actualization at s21 | 2 match |
| R31–R37 E2E: preview on test2; login; create 2 notes; find one; find none; clear returns both; user B isolation | Playwright on `test2`; `web/e2e/notes-search.spec.js` + user-B isolation in `auth-notes.spec.js` | 7 match |
| R38–R40 Playwright 1.64.1, no package/lock rollback, pngdiff OK | `@playwright/test 1.64.1` test-only; no lock rollback; pngdiff in the preview gate | 3 match |
| R41–R45 auth/persistence unchanged; search-only scope; no f-v3 churn; E4312/E1320 untouched; test2 only | No auth/storage/lifecycle change; search-only diff; old branches/executions untouched; prod/main/stage/canary out | 5 match |

## Где домыслили / что добавили от себя

Everything below is explicit, traceable, and needs the s08 human "yes".

1. **Run coordinates (R02, R04).** Request says `path-1.feature` 3.2.2 and
   branch `dev/f-v4-note-search`; E6636 runs the current canon `@4.0.0` on the
   path-10 A/B branch `dev/path10-runner-13`. Base `9e7fae35` is a descendant of
   the requested `406fa965` (lineage preserved, `git merge-base --is-ancestor`).
2. **Whitespace-only q (R18).** Chosen "all notes" (forgiving, no second error
   path the UI must special-case); recorded in the brief and as an invariant.
3. **Client-side filter (AOD-2).** The screen filters the already loaded
   owner-scoped list; `GET /api/notes?q=` remains the server contract, tested
   independently. No per-keystroke requests.
4. **No query persistence (AOD-3).** Reload starts empty; cleared on
   login/logout/401/user switch. The earlier sessionStorage-restore idea is
   superseded.
5. **Offline (AOD-4).** Only the in-memory loaded list, labeled
   «Нет сети — показаны загруженные заметки.», plus an `offline-zero` variant;
   no cache/Service Worker, no persistence promise.
6. **Count (AOD-5).** `Найдено N` only for a non-empty query on a non-empty,
   non-blocked collection, `aria-live="polite"`.
7. **Zero notes (AOD-1).** Base `notes-empty` wins; search is disabled when
   `notes.length == 0`, so a phantom "ничего не найдено" cannot appear.
8. **Language (AOD-6).** Russian feature copy; `Notebook`/`Add`/`Logout` stay
   English as documented DS terms; Delete shows «Удалить» +
   `aria-label="Удалить заметку #N"`.
9. **Layout (AOD-7).** Composer above search, search above the list (matches the
   approved v7 export and the shipped app); the s03 search-first sketch is
   superseded.
10. **Not added:** pagination, ranking, fuzzy matching, highlighting, title
    field, cache/persistence, server search per keystroke, new dependencies or a
    second design system. s45/s46 are skipped, not waived.

## Prototypes / design links

- Approved prototype: `prototypes/v7` (`manifest.json`, `prototype-review.json`,
  exports 390/1200 incl. offline and offline-zero).
- Planned UI graph: `UI-GRAPH.planned.yaml` (19 nodes, 69 edges, 8 states +
  `normal = idle`).
- Design inputs: `design-impact.md`, `component-refs.json`,
  `component-map.yaml`, `design-gaps.json`, `ds.lock.json` (DS 1.0.1).

## Open questions for s08

1. Confirm AOD-6 (language) and AOD-7 (composer-first order), closed at s06 per
   the approved v7.
2. Confirm R02 (process 4.0.0) and R04 (A/B run branch `dev/path10-runner-13`).
3. Note (not a product question): s20 must align offline delete/clear
   affordances with v7 or record an explicit design change (architect R-4/R-5).
