# Red-team attack log — E0809 s22b (f-v4-note-search)

- Target: https://test2.nexus.ukituki.tech, build_ref 5785dc0, image sha256:1990befb…
- Reviewer: qwen3.8-fast / llama-proxy (independent; author deepseek-flash/deepseek, sde session ses_e4433e6faffeDGXVi4lKO4t3W8)
- Reviewer session: ses_e43ffd54effeHrVF3ImMEt3vkf
- Mode: live HTTP attacks + local static/test checks; read-only product code.

## Results (all product-level attacks blocked)

| # | Attack | Result |
|---|---|---|
| 1a | unauth GET /api/notes | 401 unauthorized, WWW-Authenticate: Bearer |
| 1b | wrong/malformed token (3 forms) | 401 |
| 1c | q before auth | 401 (auth precedes query) |
| 1d | q 513 bytes / 512 bytes | 400 query too long / 200 |
| 1e | q multibyte 513B / 512B | 400 / 200 (byte cap) |
| 2a | cross-owner read incl. q | B sees only own notes; q=alpha -> [] |
| 2b | cross-owner delete | 404 not found; A notes intact |
| 2c | duplicate register | 409 username taken |
| 3 | XSS `<img onerror>` / `<script>` | GET exact text; UI textContent only; no exec |
| 4a | malformed ids | 400 invalid id / 404 not found; no leak |
| 4b | method reject | 405 + Allow |
| 4c | bad/oversize bodies | 400; no 500 |
| 5 | q edge (%00, unicode, 10KB) | 200 / empty; no 5xx; nginx 414 for 10KB |
| 8 | 5xx / dead-end sweep | none; go test ./... ok |

## Findings

- **RT-E0809-F1 (high, FIXED)**: `tools/canary-run.sh` substitutes `{worktree}` in `seed` only; the project `detect` strings also contained `cd {worktree} &&`, so detectors died on the literal path (false-positive "canaries detected"). Fixed in `path1.project.json` by removing `cd {worktree} &&` from detect (the runner already cd's into the worktree). Re-ran `CANARY_FORCE=1 bash tools/canary-run.sh E0809`: all 3 detectors now fail on seeded defects with real Go/grep output, `proof-execute.json ok=true`, 16/16 catalog ok. No tools/ edit.
- RT-F2 (low): feature-dir ambiguity without ORC_FEATURE_DIR; ORC sets it (gate OK covered=9). Fail-close by design.
- RT-F3 (low): nginx HTML 400 for malformed percent-escapes; app envelopes JSON; no client path.
- RT-F4/F5/F6 (info, accepted): register enumeration trade-off; invalid UTF-8 sanitized; no CSP (textContent-only, no HTML sink).

## Verdict

PASS. 0 confirmed product critical/high. The only high was audit-evidence integrity in the canary harness, now fixed and re-proven.
