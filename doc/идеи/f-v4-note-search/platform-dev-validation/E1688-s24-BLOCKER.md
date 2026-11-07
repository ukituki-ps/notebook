# E1688 — s24 BLOCKED: gate-evidence-authentic §2b (UI evidence not committable)

- Execution: E1688; step s24.team_lead_accept; branch dev/f-v4-note-search-ae079e5c.
- Human approval: `apr_a1fb457b77a085091c0ac99a0cf037be` — **approved**, waited 8s, signed `nexus.approval/v1` (report blob `sha256:ee0bf4b6…`, unchanged).
- Platform: dev `f6a5fcf1`; bundle `sha256:263c48a4…`.
- s20c: UI mode, Playwright 15/15, pngdiff OK, verdict `pass/verified`.
- s24 auto-gates: **10 / 11 pass**. Failing: `gate-evidence-authentic`.

## Full payload (s24 accept at `bc94d53`, verbatim from gate log)

```
gate-tools-untouched: OK — tools/, deploy/ и .orc-trust/ не изменены относительно base_sha:69d64e9d4e24 (base — предок HEAD)
pngdiff: OK — 6 скриншотов, near-duplicate не найдено
gate-evidence-authentic: scenario-evidence OK (6 сценариев, уникальные скриншоты)
gate-evidence-authentic: evidence-manifest OK (6 файлов)
gate-evidence-authentic: FAIL — evidence-manifest.json изменён после s20c (sha не совпадает с preview-verdict)
gate-evidence-authentic: proof OK (20 детекторов; ok/exit0 + justified na)
gate-evidence-authentic: FAIL — 1 проверок не прошло (полный список выше)
```
- gate_count=11, failed_count=1, gate_id=gate-evidence-authentic (kind=command, layer=1).
- workdir: `.orc-eval/E1688/bc94d53ada3913f941dbc76989a58de051d187eb`
- output_ref: `/app/data/evidence/gate-logs/01779daaf8c291b8-gate-gate-evidence-authentic.log`

## Root cause

1. The s20c UI run writes `scenario-evidence.json` (6 сценариев), `evidence-manifest.json`
   (**9 файлов**, sha `4a79210a…`) and 8 screenshots (~790 KB total), and anchors the
   manifest sha in `preview-verdict` (`evidence_manifest_sha256=4a79210a…`).
2. The runner persists this evidence to the **execution root**
   (`.orc-eval/E1688/doc/идеи/f-v4-note-search`) — the F-RUN-02b "survive eval-worktree
   recreation" copy.
3. At s24, ORC **recreates the eval worktree from git** at `bc94d53`; it contains the
   committed E8895 evidence (6 screenshots, 6-file manifest). `check-evidence-authentic`'s
   `cur()` reads `ROOT` (git), not the exec-root persisted copy. So:
   - §1/§2/§2b-manifest-integrity pass on the committed evidence,
   - **§2b anchor fails**: committed manifest sha ≠ `preview-verdict.evidence_manifest_sha256`
     (`4a79210a…`).

## Why the agent cannot fix it directly

The s20c evidence (790 KB of screenshots + manifest) lives only on the ORC host. This agent's
authoring worktree is a different filesystem (`/workspace` not visible to ORC); the ORC
container cannot push to origin (no credentials); and there is no binary-transfer channel over
MCP (only text windows). So the evidence cannot be committed to the branch from here.

## Suggested platform fix (one of)

- s20c accept **commits** the runner-generated evidence to the work branch; or
- `check-evidence-authentic.cur()` falls back to the exec-root persisted evidence
  (`.orc-eval/<E>/doc/идеи/<F>`) — the F-RUN-02b copy already exists; or
- the runner writes evidence into the exact commit-subdir the accept reuses (no recreate).

The human approval is genuine and remains valid for the unchanged report blob; the s24 gate
will pass once the evidence is present in the evaluated tree.

## Resolution (platform `de7727ea`, bundle `96490ad5…`)

The gate was fixed to read the canonical execution-root evidence first (git copy as fallback).
On the real E1688 s24 worktree it now passes: `pngdiff OK`, `scenario-evidence OK`,
`evidence-manifest OK (9 файлов)`, `proof OK`, `gate-evidence-authentic: OK`.

The prior approval `apr_a1fb457b…` expired by TTL (15 min, at 14:14:49Z), so a fresh s24
approval request is issued for the retry. Report blob is unchanged (`sha256:ee0bf4b6…`).

## Retry note

Stand `test2` re-leased for E1688 (`94b80367-65f7-4437-9b52-875ccbb0a4c7`) before the s24
accept retry: `gate-stand-leased-accept` requires an active lease, and the earlier lease had
been released.

