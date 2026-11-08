# s24 — Final report, f-v4-note-search (E0809, path-1.feature@4.0.0)

- Verdict: **pass** (4.0.0 process completed; residuals below are non-blocking and explicit).
- Execution: **E0809** · entry **default** · process **path-1.feature@4.0.0** · dev-ORC 8390.
- Work branch: **dev/f-v4-note-search-e2e** (base e6aeb44e, Notebook DS 1.0.0).
- Deployed preview: **test2** · ref **7026b7e** · commit `7026b7ecc40a12660afe1dfc155b7e3982ef2f22`
  · image `sha256:8302078ed3ea4d9273b4c7675c1ab4ededc62e0eeedd153e7bea5bb01f31fdee`
  · build_args `sha256:d16f8c44…` · gate bundle `sha256:42f4ba6f…` · https://test2.nexus.ukituki.tech.

## Notebook DS 1.0.0 usage (real, no Kubiki)

- s02a pin: `ds/v1.0.0`, release 1.0.0, manifest digest `sha256:02f027a8…4dda3d`; manifest/tokens/registry hashes verified.
- s04a/s03a: `ds.lock.json`, `component-map.yaml`, `component-refs.json` — 18 nodes, **14/14 registry components**, 0 local instances; path6 gaps accepted: count label, delete-note registry omission, disabled-input state.
- s03b prototype v6 (NEW Notebook DS content, not the Kubiki v6): 7 states, 390/1200, 14 Playwright exports,
  `.fig` `sha256:88e91fae…62f3a`; independent designer UI + product UX reviews accept 0 blockers/0 majors;
  signed owner approval `apr_52c5d83c4d5e1828eeb7c0641e62f2be` (policy notebook/prototype blob).
- s22a UI audit: 24/24 items, blocks A-L, **0 DS-usage violations**, designer ACCEPT.
- s24 ds-drift: release manifest/refs unchanged; pinned digest unchanged.

## E2E (test2, build 7026b7e)

- 20/20 Playwright scenarios SEARCH-E2E-1..20; evidence `scenario-evidence.json` (20 screenshots sha256, pngdiff OK).
- Covers title/body text search, owner scope A/B, clear, count, empty vs no-results, loading, error+retry,
  offline + offline-zero, XSS/escaping, keyboard/focus/aria, 512-byte q cap, 390/1200, delete, reload.
- API smoke (`e2e-api-smoke.log`): q512 → 200, q513 → 400 `query too long`, no token → 401, owner scope intact.
- preview-verdict: pass/verified, artifact digest bound to scenario-evidence, deploy/image match /healthz.

## Independent audits

- UI (designer, 24 items, 0 blockers/0 critical-high, ACCEPT) + UX (product, 22 items, 0 blockers, 2 minors).
- Red-team (qwen3.8-fast/llama-proxy): live attacks blocked (401 order, owner scope, XSS textContent, 512 cap,
  method/id envelopes); 3/3 canaries genuinely detected after fixing detector substitution/portability.
- Adversarial code review (qwen cross-pair, 9 findings): 0 critical/high; CR-01 medium (transient stale-load/delete),
  CR-02/03 low (a11y/offline clear), rest refuted/accepted.

## What was NOT done / residual risks

1. CR-01/02/03 were **not code-fixed** (s23 decision): product is frozen at the E2E-verified build 7026b7e;
   edits would invalidate the preview binding and require another deploy/E2E. Backlog for DS/UI follow-up.
2. Six fault-verdict entries were `na` at s17; UI-A11Y-LABEL was upgraded to covered, the rest remain
   bookkeeping-only and are now evidenced by s20c.
3. Screenshots SEARCH-E2E-11/12 were captured after state recovery; states are proven by assertions.
4. `frontend/src/ui/kit/**` legacy Kubiki sources remain in the tree but are **not shipped/imported**
   (Go embeds web/* only); 0 Kubiki imports in delivered UI.
5. Eight UI runtime invariants remain `proposed` (evidenced by s20c, activation bookkeeping pending).
6. Accepted DS token drift (h1 22px vs 1.4rem, body token 15 vs CSS 16) — DS 1.0.1 backlog; digest 1.0.0 unchanged.
7. s45.push_primary / s46.post_deploy_verify are not executed (entry default skip); no prod/main/test1/canary.

## Platform incidents (worked around without gate bypass)

- s03b/s08 approval payload was read from the stale ORC repo root; the **signed bytes are identical** to the
  evaluated commit and were resolved via an absolute feature_dir pointing at the evaluation worktree.
- Post-deploy steps accept only docs-only descendants of the deployed ref; audit artifacts were kept docs-only
  (an `arch/frontend/pages` edit was reverted to the deployed plan; UI-GRAPH stays actualized in doc/).
- `tools/canary-run.sh` substituted `{worktree}` only in `seed`; project `detect` strings carried `cd {worktree}`,
  producing false-positive detections. Fixed in `path1.project.json` (no tools edit) and re-proven 3/3;
  skip-tag detector made BusyBox-portable.
- Host deploy runner requires an absolute `gitdir` in eval worktrees; provided during deploy.

## Evidence index

- DS: `ds-pin.json`, `ds-pin-evidence.md`, `ds.lock.json`, `component-refs.json`, `component-map.yaml`, `design-gaps.json`, `ui-audit.json`.
- Prototype: `prototypes/v6/manifest.json`, `prototype-review.json`, `.fig-cache/*.fig`, `exports/*.png`, `design-review.fragment.json`.
- E2E: `scenario-evidence.json`, `screenshots/SEARCH-E2E-1..20.png`, `e2e-api-smoke.log`, `preview-verdict.json`.
- Audits: `ui-audit.md`, `ui-audit-review.md`, `ux-audit.json`, `attack-log.md`, `red-team-review.json`, `code-review.json`, `result-audit.md`, `refinement.md`.
- Graph: `UI-GRAPH.yaml` (actualized, 19 nodes/66 edges).
