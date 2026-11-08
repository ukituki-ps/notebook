# UI audit review — note-search (E0809, s22a acceptance)

- Feature: `f-v4-note-search`
- Execution: `E0809`, step `s22a.ui_audit`
- Branch: `dev/f-v4-note-search-e2e`
- Platform: `web`
- Reviewer role: `designer` (independent gate)
- Reviewer session: `ses_e440dc342ffe0cyPYnyr57Rk2D`
- Author session (sde-frontend): `ses_e4433e6faffeDGXVi4lKO4t3W8`
- Independence: distinct (`ses_e440dc342ffe0cyPYnyr57Rk2D` != `ses_e4433e6faffeDGXVi4lKO4t3W8`)
- Subject artifacts: `ui-audit.json`, `ui-audit.md`, `component-refs.json`, `design-gaps.json`, `ds-pin.json`,
  `ds.lock.json`, `scenario-evidence.json`, screenshots `SEARCH-E2E-1..20`, `web/index.html`, `web/app.js`, `web/app.css`
- Build under audit: `5785dc0` (`5785dc0aefbb2ba3e46f42095e5c8d34d6e052f6`), stand `test2`,
  image `sha256:1990befb2cbfe44935c4f3a682671be8ea637da8f0d9ec6d9a02227b4edce86e`

## Verdict: ACCEPT

The audit is accepted. No DS-conformance, state-coverage, accessibility, or responsive defect was found
that requires code changes. Two non-blocking evidence-quality notes and several informational notes are
recorded below; none changes the UI acceptance outcome and none is a blocker / critical / high finding.

## Gate evidence (replayed by reviewer)

```
$ ORC_FEATURE_DIR="doc/идеи/f-v4-note-search" python3 tools/ui-audit-check.py \
    --root . --platform web --expect-sha 5785dc0
gate-ui-audit: PASS (platform=web) (/workspace/projects/notebook/doc/идеи/f-v4-note-search/ui-audit.json)
EXIT=0

$ python3 tools/check-design-gates.py ds-usage --root . --feature-dir "doc/идеи/f-v4-note-search"
ds-usage: PASS — /workspace/projects/notebook/doc/идеи/f-v4-note-search
EXIT=0
```

Additional gates replayed for completeness:

```
$ python3 tools/check-design-gates.py design-integrate --root .
design-integrate: PASS — /workspace/projects/notebook/doc/идеи/f-v4-note-search   EXIT=0

$ python3 tools/check-design-gates.py ds-drift --root .
ds-drift: PASS — /workspace/projects/notebook/doc/идеи/f-v4-note-search            EXIT=0

$ python3 tools/pngdiff.py --thresh 0.005 doc/идеи/f-v4-note-search/screenshots/SEARCH-E2E-*.png
pngdiff: OK — 20 скриншотов, near-duplicate не найдено                             EXIT=0
```

## Verified counts

| Criterion | Result | How verified |
|---|---|---|
| Checklist items | **24/24 verdict=ok** (severity: 12 cosmetic, 10 minor, 2 major-criteria; 0 violation, 0 na) | parsed `ui-audit.json` |
| Blocks A–L | **12/12 covered** | parsed `ui-audit.json` (A2 B2 C2 D4 E2 F2 G2 H1 I2 J1 K2 L2) |
| Notebook DS components | **14/14 used** | all 14 registry selectors resolved in `web/index.html` (`.card`, `.logout`, `button`, `input`, `textarea`, `.error`, `.notes-header`, `.notes-list`, `.note-item`, `.notes-search`, `.notes-search-clear`, `notes-loading`, `notes-empty`, `notes-search-empty`) |
| Kubiki imports | **0** | no `kubiki` import/dep in `web/` or `package.json`; Go embeds only `web/index.html|app.js|app.css` (`main.go:24`) |
| Local DS instances | **0** | `component-refs.local_instances=[]`, `ds.lock.local_instances=[]`; no local fork of a registry selector in `web/app.css` |
| DS tokens only | **yes** (with documented DS-1.0.1 drift) | `var(--…)` throughout; only literals are `border-radius: 8px` (= token `radius.sm`) and `color:#fff` (= token `card`), both already logged as accepted residual drift in `coverage-audit.json` / `design-impact.md` |
| Design gaps | **3 accepted / 0 blocking / 0 open** | `design-gaps.json` — GAP-1 missing-pattern (`n-count`), GAP-2 missing-state (input disabled, non-path6), GAP-3 registry-omission (`n-delete`); path6_required = `n-count`, `n-delete` |
| Blockers / critical-high | **0 / 0** | `ui-audit.summary` + gate DoD |
| Stand sha | **`5785dc0` == expect-sha** | `ui-audit-check --expect-sha 5785dc0`; `preview-verdict.evaluated_sha=5785dc0aef…`; `scenario-evidence` commit `5785dc0aef…`, 20/20 passed |
| Pins | manifest `72e26a2d…`, tokens `9cca3164…`, registry `c2d4c3ae…`, component-refs `3c0cfed5…` | recomputed sha256 of each file — all match `ui-audit.design_system`, `ds.lock.json`, `ds-pin.json` (release 1.0.0, digest `02f027a8…`) |

## Reviewer inspection (independent of the author's claims)

- **Source audit** — `web/app.js`: no `import`/`require`, no `innerHTML`/`insertAdjacentHTML`/`style=`; all
  note text rendered via `textContent` (XSS-safe). Delete button gets `aria-label="Удалить заметку #<id>"`.
  Clear handler calls `renderNotes("")` then `search.focus()`.
- **States** — `renderNotes`/`syncNotesState` keep idle / results / no-results / loading / error / offline
  mutually consistent: count visible only for a non-empty trimmed query, search disabled while
  loading/error/offline with `aria-disabled` + `aria-describedby`.
- **A11y** — label on search input, wrapper `role="search"`, `aria-controls="notes-list"`, `role="status"`
  on loading/offline/search-empty, `role="alert"` on error, `:focus-visible` 3px ring. Contrast (WCAG AA)
  recomputed from `design/tokens.json`: muted/card **6.00:1**, text/card **15.80:1**, danger/card **6.57:1**,
  danger/danger-bg **6.05:1**, white/accent **4.63:1**, border/card **3.74:1** (non-text ≥3:1), focus/card
  **4.63:1**. 44px targets via `--control-height`; E2E-18 asserts ≥44px at 390.
- **Responsive** — `@media (max-width:640px)` stacks search row, full-width controls, flex-column note items;
  `.app` capped at 640px. E2E-18 asserts no horizontal overflow and column→row switch at 390/1200.
- **Screenshots reviewed** — 1, 2, 9, 11, 12, 13, 14, 16, 18, 20. `sha256` of all inspected files matches
  `scenario-evidence.json`; E2E-14 visibly shows offline banner + disabled search + base empty; E2E-16 shows
  the focus ring on Clear and visible count; E2E-18 shows the 390 stacked layout with no overflow; E2E-20
  shows owner-scoped rendering for user B.

## Findings

### Minor (non-blocking, evidence only)

1. **SEARCH-E2E-11 / SEARCH-E2E-12 screenshots do not depict the state they evidence.**
   In `web/e2e/notes-search.spec.js` the `shot()` call runs *after* the state is released/recovered:
   E2E-11 calls `release()` then captures (post-loading), E2E-12 sets `failGet=false`, retries, then captures
   (recovered, no alert). The screenshots therefore show the normal list, not `role=status` loading or
   `role=alert` error. The states themselves are genuinely proven by the executable oracles
   (`toBeVisible` + `role`/`aria-live` + `toBeDisabled`), and the UI code implements them correctly, so this
   is an evidence artifact defect, not a UI defect. **Recommendation (non-blocking):** recapture 11 while the
   GET is held and 12 before the retry click, or rename the artifacts to match what they show.

### Informational

2. **Declared viewport vs stored artifact.** `ui-audit.scope.viewports` declares `1200x900`, but stored PNGs are
   1280×720 (default) and 390×844 (E2E-18, full page 936px). The 1200/900 overflow and row-layout assertions
   do execute in E2E-18, and `.app{max-width:640px}` makes 1200 and 1280 render identically, so there is no
   visual coverage loss — only a documentation/precision mismatch in `scope.viewports` and in L1's "both widths".
3. **`design_system.path6_accepted` lists 4 node ids** (`n-count`, `n-delete`, `n-offline`, `n-retry`) while
   `design-gaps.path6_required` and `component-refs.path6_required` correctly list 2 (`n-count`, `n-delete`).
   `n-offline` is a `patterns/note-item` composition and `n-retry` is a `primitives/button` reuse — neither is
   a path6 gap. Cosmetic inconsistency carried over from the preliminary audit; the gate does not depend on it.
4. **Oracle strength for A1/C1.** Both point at `check-design-gates.py ds-usage`, which validates audit metadata
   (release==pin, self-reported `ds_usage_violations==0`, digest formats) — it does not scan `web/` for token or
   import violations. The criterion is nonetheless true under manual inspection (no Kubiki imports, no JS
   color literals, CSS only uses tokens + documented drift). Suggest a real import/color-literal lint as the
   oracle in a future revision.
5. **Scenario banner in screenshots.** `shot()` prepends a 96px striped banner with inline styles. It is an
   evidence marker, not product UI, and it mechanically guarantees part of the L2 pngdiff uniqueness. It does
   not affect appraisal of the app area below it.
6. **Dead CSS.** `.notes-search-empty` (`web/app.css:214`) never applies — the element uses `class="muted"`
   (`web/index.html:104`). No visual impact; the state is styled by `.muted` with its own `margin-top`.
7. **Disabled search visual relies on UA style.** No `input:disabled` rule exists; the state is conveyed by the
   placeholder change ("Поиск недоступен без сети") + `aria-disabled` + `aria-describedby`. This is exactly the
   accepted GAP-2 workaround, not a new violation.
8. **Legacy Kubiki kit remains in the repo but is not shipped.** `frontend/src/ui/kit/**` still contains
   `@kubiki/ui` comments/names, but nothing under `web/` imports it, `package.json` has no such dependency, and
   the Go binary embeds only `web/*` — so "0 Kubiki imports" is accurate for the delivered UI.
9. **`s20b-deploy.md` names source commit `20e0fe9`** while build/verification bind `5785dc0`. Verified
   `git diff --name-only 20e0fe9 5785dc0` = only `s20b-deploy.md` (`web/` diff is empty), so the deployed
   code is byte-identical and the sha binding to `5785dc0` holds.

## Review decision details

- ACCEPT criteria: gates PASS; 0 blockers; 0 open critical/high; 14/14 DS components; 0 Kubiki imports;
  0 local instances; all required states/a11y/responsive checks have executable oracles that pass; path6 gaps
  formally accepted with rationale (`design-gaps.json`, `blocking=false`, `status=accepted`).
- No modifications were made to `ui-audit.json` or to code; no commit was created. Only this review file was added.
- Finding 1 is a screenshot-recapture recommendation for the next audit revision; it does not alter the
  verdict because the corresponding criteria are independently proven by passing assertions and source inspection.

## Re-audit (after s23, build 7026b7e)
- E2E re-run 20/20 on test2 build 7026b7e (image sha256:830207…); UI product unchanged vs 5785dc0.
- ui-audit-check --expect-sha 7026b7e PASS; 0 DS-usage violations; designer verdict remains ACCEPT.
