# Execution report — s11.unit_execution (E0809 s20, u03)

- **Execution:** `E0809-s20.sde_5fexecution-u03`
- **Step:** `s11.unit_execution`
- **Unit:** `notebook-search-deploy-e2e` (sde-infra, plain)
- **Branch:** `orc-exec-E0809-s20.sde_5fexecution-u03`
- **Base:** `f5943f5ed87e8bbcaadf48ec23dd005ac2c38f95`
- **Change class:** plain · `feature_profile=full` · platform `web`
- **Stand policy:** test2 only under the E0809 lease; no prod/main/stage/test1/canary.
  The suite was **not** run against test2 in this step (s20c does that).

## Files changed (4 feature files)

| File | Change |
|---|---|
| `web/e2e/notes-search.spec.js` | 8 → 20 scenarios, helpers hardened, exactly 20 `test()` calls |
| `deploy/path1/e2e-preview.sh` | test2-only guard, search API smoke (owner-scope, auth-before-q, 512-byte cap), Playwright entry runs the 20-scenario spec |
| `doc/идеи/f-v4-note-search/scenarios.json` | 20 planned entries `SEARCH-E2E-1..20` |
| `doc/идеи/f-v4-note-search/scenario-evidence.json` | truthful skeleton for s20c (`run_at=null`, 20 × `pending`, no fabricated data) |

Untouched: `main.go`, `main_test.go`, `web/index.html`, `web/app.js`, `web/app.css`,
`web_ui_test.go`, `design/**`, `UI-GRAPH.yaml`.

## Scenario implementation

- Reused the existing helpers (unique user + register/login, `addNote`/`submitNote`,
  `setQuery`, clear, search-empty) and added deterministic helpers:
  `waitForNotesReady` (waits for a real render, not the static HTML),
  `expectNoHorizontalOverflow`, and API helpers via the Playwright `request` fixture.
- Every test registers a fresh user and uses per-run unique text, so tests are
  independent of note ids and of each other.
- Covered: find, no-match empty, case-insensitive, clear, create/delete under an
  active query, whitespace, no-token cleanup, count visibility, zero-notes disable,
  loading, error + retry, offline with loaded notes, offline-zero, XSS/escaping,
  keyboard/focus/aria, 512-byte API cap (513 → 400, 512 → 200, >512 whitespace → 400),
  390/1200 layout + overflow, clear focus, owner-scope B.
- No skip/fixme/only directives. A compact per-scenario banner strip is added before
  the screenshot so s20c's `pngdiff` near-duplicate gate can distinguish frames
  without covering the searched UI.

### Exact 20 test titles (`--list`)

1. `SEARCH-E2E-1 search finds matching note`
2. `SEARCH-E2E-2 non-matching query shows the search empty state`
3. `SEARCH-E2E-3 match is case-insensitive`
4. `SEARCH-E2E-4 clear restores the full list`
5. `SEARCH-E2E-5 create while query active re-applies the filter`
6. `SEARCH-E2E-6 delete while query active keeps the filter consistent`
7. `SEARCH-E2E-7 whitespace-only query keeps the clear control hidden`
8. `SEARCH-E2E-8 no-token path clears a leftover query`
9. `SEARCH-E2E-9 count is shown only for a non-empty query`
10. `SEARCH-E2E-10 zero notes shows the base empty state and disables search`
11. `SEARCH-E2E-11 loading shows the status and disables search`
12. `SEARCH-E2E-12 error state offers retry that reloads notes`
13. `SEARCH-E2E-13 offline banner keeps loaded notes and hides false empty`
14. `SEARCH-E2E-14 offline with zero notes is distinct from search empty`
15. `SEARCH-E2E-15 note markup renders literally (no XSS)`
16. `SEARCH-E2E-16 keyboard focus and aria wiring`
17. `SEARCH-E2E-17 query length cap: 513 bytes rejected, 512 accepted`
18. `SEARCH-E2E-18 390 and 1200 viewports avoid horizontal overflow`
19. `SEARCH-E2E-19 clear returns focus to the search input`
20. `SEARCH-E2E-20 owner scope B never sees user A notes`

## Static validation

```text
$ node --check web/e2e/notes-search.spec.js
OK

$ bash -n deploy/path1/e2e-preview.sh
OK

$ grep -nE 'test\.(skip|fixme|only)' web/e2e/notes-search.spec.js
none

$ grep -cE '^test\("SEARCH-E2E-' web/e2e/notes-search.spec.js
20

$ npx --no-install playwright test web/e2e/notes-search.spec.js --list
...
Total: 20 tests in 1 file
```

Manifest validation (`python3`): scenarios = 20, evidence = 20, ids unique and
aligned, all `status="planned"` / `e2e_ref=id`, evidence `execution=E0809`,
`run_at=null`, `status="pending-s20c"`, all 20 rows pending with null
screenshot/sha256/pngdiff.

test2-only guard:

```text
$ env -u E2E_BASE_URL -u PREVIEW_BASE_URL bash deploy/path1/e2e-preview.sh
rc=2  e2e-preview: E2E_BASE_URL не задан

$ E2E_BASE_URL=https://prod.example.com bash deploy/path1/e2e-preview.sh
rc=2  e2e-preview: test2-only guard: host 'prod.example.com' не разрешён

$ E2E_BASE_URL=https://test1.nexus.ukituki.tech bash deploy/path1/e2e-preview.sh
rc=2  e2e-preview: test2-only guard: host 'test1.nexus.ukituki.tech' не разрешён
```

## Local runtime validation (not test2)

No stand was used. To de-risk the spec before s20c, the U02 UI build (branch
`orc-exec-E0809-s20.sde_5fexecution-u02`, commit `97cf108`, embedded final
`web/index.html` + `web/app.js`) was built into a temporary binary and served on
`127.0.0.1:18080`. The spec was copied into an isolated runner directory so
screenshots never touched the repository.

```text
$ E2E_BASE_URL=http://127.0.0.1:18080 \
    npx --no-install playwright test web/e2e/notes-search.spec.js \
    --workers=1 --reporter=line
Running 20 tests using 1 worker
...
  20 passed (7.5s)

$ python3 tools/pngdiff.py --thresh 0.005 <20 temp screenshots>
pngdiff: OK — 20 скриншотов, near-duplicate не найдено
```

The added search API smoke logic was exercised against the same local server:

```text
ok — find A
ok — not-found []
ok — owner-scope B []
ok — unauth 401 + Bearer
ok — 513 -> 400 query too long
ok — 512 -> 200 accepted
SEARCH SMOKE GREEN
```

These local screenshots/artifacts were deleted; `scenario-evidence.json` remains a
pending skeleton and contains **no** fabricated evidence. s20c must produce the
real 20/20 evidence on test2.

## Residual risks

1. **No commit in this step (per instruction).** ORC s11 uses `transport=git` and
   its acceptance criteria require `result.commit`/`evaluated_sha` pushed to
   `orc-exec-E0809-s20.sde_5fexecution-u03`. The coordinator must commit/push the
   four files + this report before s11 acceptance; otherwise the ORC gate will
   reject with a missing commit.
2. **s20c still required.** Runtime proof here used the U02 UI branch locally, not
   the merged parent branch on test2. s20c must run with `E2E_BASE_URL=<test2>` and
   no `E2E_API_ONLY=1`.
3. **Offline emulation.** Tests rely on Playwright `context.setOffline()` driving
   `navigator.onLine` and the `offline` event (verified locally in Chromium). A
   different browser build on the stand could behave differently.
4. **Loading test interception.** SEARCH-E2E-11 holds the GET `/api/notes` response
   with `page.route`; a different runner/proxy that retries or preloads could
   change timing. Local run passed deterministically.
5. **Screenshot banner.** The compact 96px scenario strip is a test annotation used
   only for `pngdiff` distinctness. It does not change product state, but an auditor
   may prefer unannotated frames; s20c should confirm it is acceptable evidence.
6. **test2-only allowlist.** The script allows `test2.*`, localhost/127.0.0.1,
   `host.docker.internal`, and `notebook-stand-test2-*`. If the platform passes a
   different test2 alias (private IP or per-run DNS), the script fails closed at
   rc=2; the alias must be added explicitly rather than weakening the guard.
7. **Preview Playwright scope.** `e2e-preview.sh` now runs only
   `web/e2e/notes-search.spec.js` (the 20 unit scenarios). Auth UI regression is
   covered by the API auth smoke and the Go suite; the f-v3 UI spec is no longer
   part of this preview run.
