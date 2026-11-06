# Red-team attack log — f-v4-note-search (E8895)

- Stand: https://test2.nexus.ukituki.tech, build **2210238** (commit `22102389…`)
- Author sessions: unit sessions `ses_e4d6a864…`, `ses_e4d6a811…`, `ses_e4d6a7b0…`
- Reviewer session: `ses_e4de2edbeffePR726UuM1uWKKA` (independent of unit authors)
- Model policy: reviewer runs on the same configured model family as the
  orchestrator; no V4 Pro. (Cross-model enforcement is on s22c
  `gate-code-review`; this step's gates are canary/fault-catalog/invariants.)

## Adversarial probes (live, test2)

| Probe | Expectation | Result |
|---|---|---|
| `GET /api/notes` without bearer | 401 + `WWW-Authenticate` | PASS (401) |
| `GET /api/notes?q=<B-only text>` as user A | 200 `[]`, no cross-user rows | PASS |
| `GET /api/notes?q=` / `q=%20%20` | all own notes, `[]` not null | PASS |
| `GET /api/notes?q=<mixed case>` | case-insensitive substring | PASS |
| `PATCH /api/notes` (unsupported verb) | 405, no mutation | PASS |
| `DELETE /api/notes/abc` | 400 invalid id | PASS |
| `DELETE /api/notes/<missing>` | 404 | PASS |
| `POST /api/notes` with empty text | documented status/envelope | PASS |
| Error bodies | no stack/SQL/secret | PASS |

## Canary (machine proof)

`tools/canary-run.sh E8895` executed 3 seeded mutations in a detached
worktree and all were **detected** (`detector_exit=1` for each):

- `CANARY-DELETE-STATUS` (204 → 200) — caught
- `sec-rls-predicate-drop` (`==` → `!=` owner predicate) — caught
- `sec-skip-tagged` (integration build tag hiding tests) — caught

Results: `data/audit/runs/E8895/canary.json` + `findings.json`.

## Verdict

No new critical/high findings. Search is owner-scoped, auth-first, and does not
widen scope; error envelopes do not leak. The existing medium/low findings
(CR-1..3, RT-1..2) remain unrelated to this feature, 0 critical/high.
