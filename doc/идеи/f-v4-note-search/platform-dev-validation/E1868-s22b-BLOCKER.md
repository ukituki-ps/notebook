# E1868 — BLOCKER at s22b: reviewer runtime cannot prove author cross-pair

- Date: 2026-11-09T08:5xZ
- Execution E1868, entry `integrate`, branch `dev/f-v4-note-search-fix`
- Accepted: s20a (12/12), s20b (test2 GREEN), s20c (30/30 E2E), s21, s22a, s22e, s22 (faults 16/16 covered, 8 UI invariants active)
- Blocked: s22b.red_team_audit

## Error sequence (fail-close, no bypass)

1. `red-team-review.json path is not declared for review step` — the review artifact
   was not among the step's declared outputs. Folded metadata into `attack-log.json`
   and re-declared `red-team-review.json` in the result.
2. `reviewer_hook_disabled` — no official reviewer registration. Registered a real
   independent reviewer via `orc_register_reviewer`:
   - reviewer `ses_e407d9859ffe9jWpROLEJT2eYU`, model `qwen3.8-fast`, provider `llama-proxy`
   - author `ses_e42f307b6ffehnpMwLqYi5DJ6Q` (execution session), author model `deepseek-flash`/`deepseek`
   - `applied=true`, audit `reviewer_session_registered`.
3. `reviewer_model_mismatch: author model/provider required to prove a cross pair`
   persists even with top-level and nested `author_model`/`author_provider`,
   `author{...}` and `reviewer{...}` in the result.

Root cause: the execution/author session `ses_e42f…` is present in `step_runs`
but has **no `agent_sessions` model/provider row**, and the actual code-author
unit sessions are from **E6177** (entry `integrate` skips s20), so they are not
in E1868 `step_runs`. `orc_register_reviewer` accepted `author_model/provider`
but the runtime still cannot resolve the author side of the pair.

Registration with the real unit author (`ses_e438fe…`) is rejected:
`reviewer_author_unknown: author session ... is not present in step_runs for execution E1868`.

## Required platform fix

- Persist `author_model`/`author_provider` from `orc_register_reviewer` into
  `agent_sessions` for the author session, so the cross-pair check has both sides, **or**
- allow an `entry=integrate` execution to resolve author sessions from its parent
  execution (E6177) / seed `step_runs` for the skipped s20 units, **or**
- record model/provider for the execution session at `orc_start`.

Then resume E1868 (paused at s22b) and accept s22b; s22c/s23/s24 follow.

## Evidence already produced

- `attack-log.json`: 10/10 adversarial probes on test2 build `9c1763c`
  (no-token 401, owner isolation, `[]`, 512/513 cap, literal XSS, IDOR/delete statuses).
- `red-team-audit.md`, independent reviewer verdict `pass` (0 critical/high).
- `canary-run.sh E1868`: OK, 3 canaries detected.
- test2 lease `ec5910c9…` active (E1868).
