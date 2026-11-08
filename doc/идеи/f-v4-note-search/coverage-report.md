# Coverage audit report — f-v4-note-search (E0809, s17)

- Execution: **E0809** · step **s17.coverage_audit** · role **architect**
- Branch: `dev/f-v4-note-search-e2e` · base `e6aeb44e` · process `path-1.feature` **4.0.0**
- Verdict: **pass_with_gaps** · blocking gaps: **none**
- Mirrors: `coverage-audit.json`, `fault-verdicts.json`, `audit/fault-catalog/notebook.yaml`
- Scope: audit artifacts only; no `web/`/`design/`/code change; no commit.

## 1. Spec coverage

| Area | Normative source | Coverage |
|---|---|---|
| API `GET /api/notes?q=` | `spec/core.md` §1 (order 1–7) | auth → decode → 512-byte cap → trim → owner scope → case-insensitive substring → `[]` |
| Errors/status | `spec/core.md` §1.1, `contract-matrix.md` | 201/204/400/401/404/405 rows each have a named Go test |
| Data model | `spec/core.md` §2 | unchanged `Note{ID,UserID,Text}`, no migration/persistence |
| UI controls/copy | `spec/core.md` §3.2 | search/clear/count/empty/base-empty/loading/error/retry/offline/delete with testids and copy |
| UI state rules | `spec/core.md` §3.3–§3.4 | single `renderNotes()`, in-memory query, textContent, 390/1200, focus, aria-live |
| DS contract | `spec/core.md` §3.5 | Notebook DS 1.0.0 pinned; GAP-1/2/3 accepted, 0 local instances |
| Invariants | `invariants.json` | 18 active + 2 proposed (`INV-UI-ORACLE`→s22a, `INV-UI-E2E-PREVIEW`→s20c) |

No unmapped requirement: every §1/§3 clause has a test or planned test ref.

## 2. Unit mapping (s20 fan-out)

| Unit | Task(s) | Surfaces | Oracles |
|---|---|---|---|
| U01 `notebook-search-api` | T0101 (T0001–T0004) | `main.go`, `main_test.go` | `TestNotesSearch*`, `TestWireContract`, `TestHTTPTransport` |
| U02 `notebook-search-ui` | T0102 (T0005–T0008) | `web/index.html`, `web/app.js`, `web/app.css`, `web_ui_test.go` | `TestUISemantics`, UI invariants, s22a |
| U03 `notebook-search-deploy-e2e` | T0103 (T0009–T0012) | `web/e2e/notes-search.spec.js`, `deploy/path1/e2e-preview.sh`, `scenarios.json`, `scenario-evidence.json` | 20-scenario Playwright on `test2`, pngdiff |

Every spec area maps to exactly one unit; no orphan task, no unit without an
oracle. T0003 adds the missing exactly-512-byte accept case; T0008 owns R-1.

## 3. Fault verdicts (16 catalog classes)

Catalog: `audit/fault-catalog/notebook.yaml` (16 unique ids, app mode).
Verdicts: **10 covered · 6 na-with-justification · 0 gap**.

| Class | Verdict | Real check (exit) |
|---|---|---|
| SEC-AUTH-REQUIRED | covered | `TestAuthRequired|TestLoginInvalid` (0) |
| SEC-USER-ISOLATION | covered | `TestNotesIsolation|TestDeleteForeignNote` (0) |
| SEC-RLS-SCOPE-PREDICATE | covered | `TestNotesIsolation|TestDeleteForeignNote` (0) |
| SEC-ERROR-LEAK | covered | `TestNoSecretLeak|TestDeleteErrorEnvelope` (0) |
| SEC-SKIP-TAGGED-INVARIANT | covered | build-tag grep (0) |
| CONTRACT-WIRE-CASING | covered | `TestWireContract` (0) |
| CONTRACT-NULL-OMITEMPTY | covered | `TestNotesLifecycle|TestWireContract` (0) |
| CONTRACT-STATUS-CODE | covered | delete/error/405/register/login matrix (0) |
| DATA-SCOPE-VALIDATION | covered | `TestNotesIsolation|TestDeleteForeignNote` (0) |
| DATA-ADAPTER-REAL-TRANSPORT | covered | `TestHTTPTransport` (0) |
| UI-EMPTY-STATE-CONTROLS | na | `TestUISemantics` red on R-1 only |
| UI-FILTER-SERIALIZATION | na | `TestUISemantics` red on R-1 only |
| UI-LOADING-ERROR-STATES | na | `TestUISemantics` red on R-1; s20 pending |
| UI-E2E-PREVIEW | na | health+401 oracle (0); search E2E pending s20c |
| UI-A11Y-LABEL | na | Playwright pending s20c; static oracle red on R-1 |
| UI-XSS-ESCAPE | na | invariant oracle red on R-1; direct static check passes |

`na` = "accepted with justification / not certifiable at s17", not out of scope.

## 4. Gaps (all minor/info, 0 blocking)

| Id | Severity | Owner | Summary |
|---|---|---|---|
| R-1 | minor | sde-frontend/T0102 | `TestUISemantics` red: literal `44px` vs DS token `var(--control-height)` |
| DS-TOKEN-DRIFT | minor | design-system/DS 1.0.1 | accepted residual token drift; pinned digest unchanged |
| SEARCH-UI-PENDING-S20 | minor | sde-frontend/T0102 | count/retry/offline/zero-disable/in-memory query land at s20 |
| E2E-PREVIEW-PENDING-S20C | minor | sde-infra/T0103 | 8/20 scenarios; preview run/evidence pending s20c |

## 5. Gate outputs (s17)

```
fault-catalog[validate] PASS  catalog=audit/fault-catalog entries=16 unique_ids=16
fault-catalog[verdicts] PASS  items=16 covered=10 gaps=0
gate-catalog-invariants: OK   (high/critical=11; active invariants or na+justification)
gate-coverage-verdict: PASS   verdict=pass_with_gaps gaps=4 (major/critical: 0)
gate-spec-coverage: PASS
```

Backend classes are machine-verified; six UI classes carry owned minor gaps
(R-1 + pending s20/s20c). `gaps_has_blocking=false`, so s19/s20 may open.
