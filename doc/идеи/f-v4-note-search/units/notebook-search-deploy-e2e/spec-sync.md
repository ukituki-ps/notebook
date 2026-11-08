# s16 unit spec sync — notebook-search-deploy-e2e (E0809 s20, u03)

- **Execution:** `E0809-s20.sde_5fexecution-u03`
- **Step:** `s16.unit_spec_sync` (architect)
- **Unit:** `notebook-search-deploy-e2e`
- **Branch:** `orc-exec-E0809-s20.sde_5fexecution-u03` at `5352d4e`
- **Verified by:** `architect` (independent from `sde-infra`)

## synced: **true**

The unit deliverables (E2E spec, deploy smoke, scenario manifest, evidence
skeleton) are aligned with `spec/core.md` and T0103. No API/UI contract drift is
introduced, and no spec or design file was edited. Runtime conformance is
deferred to s20c by design; this step claims static sync only.

## Scenario → spec mapping

| Scenario | Spec reference |
|---|---|
| SEARCH-E2E-1 find matching | §3.2 search field, §3.3 filtering |
| SEARCH-E2E-2 non-match empty | §3.2 search-empty copy/role/aria-live |
| SEARCH-E2E-3 case-insensitive | §3.3 filtering; §1.1 step 5 (ASCII guarantee) |
| SEARCH-E2E-4 clear restores list | §3.2 clear; §3.3 clearing |
| SEARCH-E2E-5 create under query | §3.3 one `renderNotes()` path re-applies query |
| SEARCH-E2E-6 delete under query | §3.2 base vs search empty; §3.3 re-apply |
| SEARCH-E2E-7 whitespace-only | §3.2 clear hidden for empty trimmed query; §1.1 step 4 |
| SEARCH-E2E-8 no-token clears leftover | §3.3 active query in-memory only; no sessionStorage (AOD-3) |
| SEARCH-E2E-9 count visibility | §3.2 `Найдено N`, including `Найдено 0`, `aria-live=polite` |
| SEARCH-E2E-10 zero notes | §3.2 base empty wins; search disabled (AOD-1) |
| SEARCH-E2E-11 loading | §3.2 `notes-loading` `role=status`; search disabled |
| SEARCH-E2E-12 error + retry | §3.2 `notes-error` `role=alert`; `notes-retry` re-runs `loadNotes` |
| SEARCH-E2E-13 offline loaded | §3.2 offline banner; loaded notes retained; no false empty |
| SEARCH-E2E-14 offline zero | §3.2 offline-zero variant distinct from search empty |
| SEARCH-E2E-15 XSS literal | §3.3 `textContent`, never `innerHTML` (INV-XSS-ESCAPE) |
| SEARCH-E2E-16 keyboard/aria | §3.2 labels/aria; §3.4 focus ring and live regions |
| SEARCH-E2E-17 512-byte cap | §1.1 step 3: 513 → `400 query too long`; 512 accepted |
| SEARCH-E2E-18 390/1200 | §3.4 stacked 44px/no overflow at 390; inline row at 1200 |
| SEARCH-E2E-19 clear focus | §3.2/§3.3 clear returns focus and full list |
| SEARCH-E2E-20 owner scope B | §1.1 step 6 owner predicate first (INV-USER-ISOLATION) |

API smoke in `deploy/path1/e2e-preview.sh` maps to §1.1 steps 1–3 and 6–7:
auth-before-query `401` + `WWW-Authenticate`, owner-scope find, not-found `[]`,
513-byte `400 query too long`, exactly-512-byte `200` array. `main.go` confirms
`maxQueryBytes = 512`, auth before query handling, cap before `ListNotes`.

## Acceptance mapping (T0103 / unit plan)

| Acceptance item | Unit state | Where |
|---|---|---|
| 20 Playwright scenarios implemented | met | `web/e2e/notes-search.spec.js`, `--list` = 20 |
| No skips/fixmes/only | met | grep = no matches |
| API smoke incl. 512 cap | met (static) | `e2e-preview.sh` §2.5b + `main.go` |
| Manifest = 20 | met | `scenarios.json` 20 planned entries |
| Evidence 20/20 real | **deferred to s20c** | `scenario-evidence.json` pending skeleton |
| `test2`-only confinement | met (guard) | allowlist + denied prod/stage/test1/canary |
| No out-of-scope edits | met | diff limited to 4 feature files + 2 docs |

Runtime acceptance (`20 passed`, real screenshots/sha256/`pngdiff`, stand proof)
is explicitly **deferred to s20c** and is not claimed here; the pending evidence
skeleton is the correct honest state for this step.

## Contract/DS freeze

- DS §3.5: no `design/**`, no DS file, no `web/app.css`/`web/index.html` change;
  the pinned notebook DS 1.0.0 digest is untouched.
- No API contract change beyond the already-specced `q` filter/cap implemented in
  `main.go`; this unit only tests it.
- §3.6 R-1 is a base oracle issue (`web_ui_test.go:264` vs
  `min-height: var(--control-height)`). It is unchanged by u03 and fixed by U02's
  oracle alignment; it is not a spec-sync drift in this unit.
- No `UI-GRAPH.yaml` edit in u03 (reserved for s21).

**Verdict: synced — spec §1/§3/§4 and T0103 acceptance are covered statically;
runtime proof and evidence remain a deliberate s20c obligation.**

- accepted: s16.unit_spec_sync (E0809-u03)
