# s16 unit spec sync — notebook-search-deploy-e2e (U03)

- **Execution:** `E6636-s20.sde_5fexecution-u03`
- **Step:** `s16.unit_spec_sync` · role `architect` (independent of `sde-infra`)
- **Unit:** `notebook-search-deploy-e2e` · domain `notebook-e2e` · `change_class: plain`
- **Branch:** `orc-exec-E6636-s20.sde_5fexecution-u03`
- **Base:** `1722a1e51b3734284c6a9103a4ed2e5ab5793386`
- **HEAD at sync:** `35fd6e11acb3c65d17a5497ac422f3475ecbf35b` (s15)
- **Spec sources:** `doc/идеи/f-v4-note-search/spec/core.md`, `spec/contract-matrix.md`, `T0103/brief.md`
- **Platform/DS:** web · Notebook DS `1.0.1` (pinned, frozen until s24)

## synced: **true**

The unit deliverables (Playwright spec, `test2` API-smoke entry, scenario
manifest) are statically aligned with `spec/core.md` §1.1, §3.2–§3.4, §4 and the
T0103 acceptance list. The unit edited no spec, design, UI, or API file; the
only changes in the execution diff are `artifacts/**` reports. Runtime
conformance and real evidence remain a deliberate s20c obligation and are not
claimed here.

## 1. Spec files unchanged by the unit — PASS

```text
$ git diff --name-status 1722a1e5..HEAD
(only artifacts/units/.../*.md: s12-check, s13-verify, s14-quality, s15-regression,
 steps/s11, unit-plan; no spec/design/UI/API path)
```

`doc/идеи/f-v4-note-search/spec/core.md`, `spec/contract-matrix.md`,
`UI-GRAPH.yaml`, `design/**`, `web/**`, `main.go`, `main_test.go` are unchanged
from base. No spec drift can be introduced by a tree that does not touch them.

## 2. Scenario manifest ↔ spec ↔ Playwright — PASS

- `scenarios.json`: exactly **20** `SEARCH-E2E-1..20` entries, each with
  `id`, `title`, `given/when/then`, `e2e_ref`, `status: planned`.
- Every scenario id has a matching `test("SEARCH-E2E-N …")` title in
  `web/e2e/notes-search.spec.js` (missing = 0), plus `CR-01..CR-03`
  regressions — 23 `test()` bodies total.
- No `test.skip` / `fixme` / `only` anywhere; `playwright.config.js` sets
  `forbidOnly` under CI.
- `scenario-evidence.json` is **absent** by design; the manifest stays
  `planned` until a real green s20c run. No fabricated result is present.

### Scenario → spec section

| Scenario | Spec reference |
|---|---|
| SEARCH-E2E-1 find matching | §3.2 search field, §3.3 filtering |
| SEARCH-E2E-2 non-match empty | §3.2 search-empty copy/role/aria-live |
| SEARCH-E2E-3 case-insensitive | §1.1 step 5; §3.3 filtering |
| SEARCH-E2E-4 clear restores list | §3.2 clear; §3.3 clearing |
| SEARCH-E2E-5 create under query | §3.3 single `renderNotes()` re-applies query |
| SEARCH-E2E-6 delete under query | §3.2 base vs search empty; §3.3 re-apply |
| SEARCH-E2E-7 whitespace-only | §3.2 clear hidden for empty trimmed query; §1.1 step 4 |
| SEARCH-E2E-8 no-token clears leftover | §3.3 query in-memory only, no `sessionStorage` |
| SEARCH-E2E-9 count visibility | §3.2 `Найдено N` incl. `Найдено 0`, `aria-live=polite` |
| SEARCH-E2E-10 zero notes | §3.2 base empty wins; search disabled |
| SEARCH-E2E-11 loading | §3.2 `notes-loading` `role=status`; search disabled |
| SEARCH-E2E-12 error + retry | §3.2 `notes-error` `role=alert`; retry re-runs `loadNotes` |
| SEARCH-E2E-13 offline loaded | §3.2 offline banner; loaded notes kept; no false empty |
| SEARCH-E2E-14 offline zero | §3.2 offline-zero distinct from search empty |
| SEARCH-E2E-15 XSS literal | §3.3 `textContent`, never `innerHTML` (INV-XSS-ESCAPE) |
| SEARCH-E2E-16 keyboard/aria | §3.2 labels/aria; §3.4 focus ring and live regions |
| SEARCH-E2E-17 512-byte cap | §1.1 step 3: 513 → `400 query too long`, 512 accepted |
| SEARCH-E2E-18 390/1200 | §3.4 stacked 44px/no overflow at 390; inline at 1200 |
| SEARCH-E2E-19 clear focus | §3.2/§3.3 clear returns focus and full list |
| SEARCH-E2E-20 owner scope B | §1.1 step 6 owner predicate first (INV-USER-ISOLATION) |

## 3. API contract ↔ implementation ↔ smoke — PASS

- `main.go:33` `maxQueryBytes = 512`; handler checks `len(rawQuery) > 512`
  → `400 {"error":"query too long"}` before `ListNotes`
  (`main.go:542-543`), so the cap precedes any note scan.
- `requireAuth` runs before the method switch (`main.go:532-535`): auth 401 is
  not bypassable by `q`.
- `ListNotes` applies the owner predicate first (`main.go:538` comment; §1.1
  step 6), so a query can never widen scope.
- `contract-matrix.md` rows 6–9 and 22 pin the same contract, including
  exactly-512-accept and 513→400.
- `deploy/path1/e2e-preview.sh` mirrors it: 401 + `WWW-Authenticate` before
  query (L83–88), `q512` → 200 (L135–136), `q513` → 400 `query too long`
  (L140–144), fail-close entry when `E2E_BASE_URL`/node/browser missing.

## 4. T0103 acceptance mapping

| Acceptance item | State | Where |
|---|---|---|
| 20 Playwright scenarios `SEARCH-E2E-1..20` | met | spec, 23 `test()` |
| `CR-01..03` regressions | met | spec |
| No skips/fixmes/only | met | grep = 0 |
| API smoke incl. 512 `400` / 512 accept | met (static) | script + `main.go` |
| Manifest = 20 entries | met | `scenarios.json` |
| Evidence 20/20 screenshots/sha256/pngdiff | **deferred to s20c** | absent by design |
| `test2` only under E6636 lease; no prod/main/test1/canary | met (guard) | script allowlist |
| No out-of-scope edits (DS frozen 1.0.1) | met | diff = artifacts only |

## 5. Residual

Runtime acceptance (`20 passed` + CR, real screenshots/`pngdiff` on `test2`) is
explicitly an s20c obligation; a red s20c run reopens the unit. This step claims
static sync only.

**Verdict: synced — the E2E deliverables match the spec contract and T0103; no
spec/design/API drift, no fabricated evidence.**
