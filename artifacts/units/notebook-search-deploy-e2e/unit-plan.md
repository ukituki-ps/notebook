# Unit plan — notebook-search-deploy-e2e (U03)

- **Execution:** `E6636-s20.sde_5fexecution-u03` · step `s10.unit_plan` · role `planner`
- **Process:** `path-1.feature` v4.0.0 (entry `default`, profile `full`, platform `web`)
- **Branch / base:** `orc-exec-E6636-s20.sde_5fexecution-u03` @ `1722a1e51b3734284c6a9103a4ed2e5ab5793386`
- **Unit:** `notebook-search-deploy-e2e` · domain `notebook-e2e` · SDE `sde-infra` · `change_class: plain`
- **Transport:** `git` (authoring worktree; this step is verify-only, plan artifact only)
- **Feature dir:** `doc/идеи/f-v4-note-search` · feature `f-v4-note-search`
- **Design system:** Notebook DS **1.0.1** (`ds_digest sha256:4e0ef105…c85e`), frozen until s24
- **Stand:** `test2` only, under the E6636 lease; no prod / main / test1 / canary

## 1. Inputs and scope

`context.source = orc_ctx` (step package `s10.unit_plan`, token budget 20000).

Files (4):

1. `web/e2e/notes-search.spec.js` — Playwright scenarios.
2. `deploy/path1/e2e-preview.sh` — health + API smoke + Playwright entry.
3. `doc/идеи/f-v4-note-search/scenarios.json` — scenario manifest.
4. `doc/идеи/f-v4-note-search/scenario-evidence.json` — per-scenario evidence (generated at s20c).

Scope (4 items from the unit brief):

- 20 Playwright scenarios `SEARCH-E2E-1..20` + `CR-01..CR-03`, no skips.
- API smoke incl. 512-byte `400` and exactly-512 accepted.
- `scenarios.json` 20 + `scenario-evidence.json` 20/20 screenshot/sha256/pngdiff.
- `test2` only under the E6636 lease; no prod/main/test1/canary.

## 2. Baseline at `base_sha` (verified in worktree)

- `web/e2e/notes-search.spec.js`: 945 lines, **23 `test()`** — `SEARCH-E2E-1..20`
  plus `CR-01..CR-03`; **0** `skip`/`fixme`/`only`; each scenario ends with
  `shot(page, "<id>")`, persisting `doc/идеи/f-v4-note-search/screenshots/<id>.png`.
  Helpers (`registerUser`, `loginViaUI`, `submitNote`, `setQuery`,
  `expectSearchEmpty`, `expectNoHorizontalOverflow`) already fail-close.
- `deploy/path1/e2e-preview.sh`: 243 lines, `set -euo pipefail`; health
  (`/healthz` JSON + `build_ref` + 40-hex `commit`), unauth `401` +
  `WWW-Authenticate: Bearer`, register/login A/B, authed create/list/delete,
  `q` find / no-match `[]`, 512 accepted / 513 → `400 {"error":"query too long"}`,
  A/B isolation, foreign delete `404`, invalid id `400`; node/npm/chromium
  fail-close (no skip); `E2E_API_ONLY=1` path used by s20a.
- `doc/идеи/f-v4-note-search/scenarios.json`: `orc.scenarios/v1`, exactly
  **20** scenarios with `id`/`given`/`when`/`then`/`e2e_ref`, all `status: planned`.
- `doc/идеи/f-v4-note-search/scenario-evidence.json`: **absent** — must be
  produced from a real s20c run; no fabricated/stale data.
- `doc/идеи/f-v4-note-search/screenshots/`: absent until a real run.

Conclusion: U03 is **verify-and-complete**, not greenfield. Do not rewrite
working scenarios; add/correct only what the DoD below requires.

## 3. Work items

### T-U03-1 — Playwright 20 scenarios + CR regressions (spec)

- File: `web/e2e/notes-search.spec.js`.
- Keep `SEARCH-E2E-1..20` and `CR-01..03`; every scenario independent
  (fresh user/unique text), fail-close on missing stand/browser/UI.
- Exactly 20 `SEARCH-E2E-*` ids and 3 `CR-*` ids; no `skip`/`fixme`/`only`;
  one unique per-scenario screenshot (per-scenario banner keeps frames
  `pngdiff`-distinct).
- Oracle: `npx --no-install playwright test web/e2e/notes-search.spec.js --list`
  (23 tests listed, 0 skipped); `grep -cE '^test\(' == 23`.

### T-U03-2 — API smoke + E2E entry (deploy script)

- File: `deploy/path1/e2e-preview.sh`.
- API smoke must keep: `401` before query handling; `q` owner-scoped find and
  no-match `[]`; decoded `q` of 512 bytes → `200`; 513 bytes → `400
  {"error":"query too long"}` before scan; A/B isolation; `204`/`404`/`400`
  delete contract. Playwright entry stays after API smoke and fail-close.
- Oracle: `bash -n deploy/path1/e2e-preview.sh`; on `test2` under lease
  `E2E_BASE_URL=<test2> bash deploy/path1/e2e-preview.sh` exit 0.

### T-U03-3 — Manifest + per-scenario evidence

- Files: `doc/идеи/f-v4-note-search/scenarios.json`,
  `doc/идеи/f-v4-note-search/scenario-evidence.json`.
- `scenarios.json`: 20 entries `SEARCH-E2E-1..20`, each `id`, `given/when/then`,
  `e2e_ref`; status moved to `pass` only after a real green run.
- `scenario-evidence.json` written **at s20c only**, shape accepted by
  `tools/check-scenario-coverage.py`: `scenarios[]` with `id`, `status: pass`,
  `screenshot` (repo-relative, existing non-empty PNG), `sha256` (matches file),
  `e2e_ref`. 20/20; screenshots unique and `pngdiff`-distinct
  (`tools/pngdiff.py --thresh 0.005`); no stale execution ids.
- Oracle: `python3 tools/check-scenario-coverage.py --brief
  doc/идеи/f-v4-note-search/scenarios.json --evidence
  doc/идеи/f-v4-note-search/scenario-evidence.json`; then
  `bash tools/check-evidence-authentic.sh E6636`.

### T-U03-4 — test2-only / freeze guard

- Run only against `test2` under the E6636 lease; never prod/main/stage/test1/canary.
- Platform and Notebook DS 1.0.1 frozen until s24; no `design/**`,
  `arch/**` or DS-file edits.
- Diff limited to the four unit files (plus this plan artifact).
- Oracle: stand/lease proof from execution context; `git diff --name-only
  ${base_sha}` ⊆ unit files.

## 4. Definition of Done

1. `SEARCH-E2E-1` search finds matching note.
2. `SEARCH-E2E-2` non-matching query → `notes-search-empty`, base empty hidden.
3. `SEARCH-E2E-3` case-insensitive match.
4. `SEARCH-E2E-4` clear restores the full list.
5. `SEARCH-E2E-5` create with an active query re-applies the filter.
6. `SEARCH-E2E-6` delete with an active query keeps the filter consistent.
7. `SEARCH-E2E-7` whitespace-only query keeps clear hidden.
8. `SEARCH-E2E-8` no-token path clears a leftover query.
9. `SEARCH-E2E-9` count `Найдено N` only for a non-empty query.
10. `SEARCH-E2E-10` zero notes → base `notes-empty` wins, search disabled.
11. `SEARCH-E2E-11` loading status visible, search disabled.
12. `SEARCH-E2E-12` error state offers `Повторить` that reloads notes.
13. `SEARCH-E2E-13` offline banner keeps loaded notes, no false empty.
14. `SEARCH-E2E-14` offline-zero distinct from search-empty.
15. `SEARCH-E2E-15` note markup renders literally (no XSS).
16. `SEARCH-E2E-16` keyboard focus / aria wiring incl. `aria-live`.
17. `SEARCH-E2E-17` 513-byte `q` → `400`, 512 accepted.
18. `SEARCH-E2E-18` 390/1200 viewports, no horizontal overflow.
19. `SEARCH-E2E-19` clear returns focus to the search input.
20. `SEARCH-E2E-20` owner scope: B never sees A's notes.
21. `CR-01` stale GET cannot resurrect a deleted note.
22. `CR-02` 401 lock never points `aria-describedby` at hidden `notes-empty`.
23. `CR-03` clear works offline with a non-empty query, then reconnect.

**Acceptance:** 20/20 `SEARCH-E2E` + 3/3 `CR` green on `test2`; API smoke
green incl. 512 cap; 20/20 authentic evidence (screenshots + sha256 + pngdiff)
recorded at **s20c only**; no skips/fixmes, no fabricated or stale evidence;
`test2`-only lease proof; DS 1.0.1 unchanged.

## 5. Verification commands

- Repo build (pre-flight, from worktree root): `GOWORK=off go build ./...`.
- Spec inventory: `npx --no-install playwright test web/e2e/notes-search.spec.js --list`.
- Script syntax: `bash -n deploy/path1/e2e-preview.sh`.
- Stand run (`test2` under lease): `E2E_BASE_URL=<test2> bash deploy/path1/e2e-preview.sh`.
- Coverage: `python3 tools/check-scenario-coverage.py --brief …/scenarios.json
  --evidence …/scenario-evidence.json`.
- Evidence authenticity: `bash tools/check-evidence-authentic.sh E6636`.
- Scope: `git diff --name-only 1722a1e5… -- web/e2e deploy/path1 artifacts/units doc/идеи/f-v4-note-search`.

## 6. Out of scope

`main.go`, `main_test.go`, `web/index.html`, `web/app.js`, `web/app.css`,
`web_ui_test.go`, auth/session/persistence, prod/main/stage/test1/canary,
s45/s46, DS/platform changes, `design/**`, `arch/**`, `UI-GRAPH.yaml` (s21).

## 7. Risks

- **R-U03-1 preview drift:** Playwright/Chromium version or stand image drift →
  pin on `test2` under the E6636 lease, fail-close instead of skip.
- **R-U03-2 evidence authenticity:** near-duplicate or reused screenshots fail
  `check-evidence-authentic`; keep the per-scenario banner and hashes from the
  real s20c run only.
- **R-U03-3 stale evidence:** committing `scenario-evidence.json` before s20c or
  reusing an older execution id is forbidden; s20c is the only writer.
- **R-U03-4 scope leak:** touching UI/backend/DS files breaks the unit boundary;
  diff must stay within the four files plus this plan.

## 8. Handoff

s10 produces this plan only (verify-only artifact). Implementation/verification
of T-U03-1..4 happens in this execution's downstream steps; evidence is written
once at s20c on `test2` under the E6636 lease, then consumed by s22/s24.
