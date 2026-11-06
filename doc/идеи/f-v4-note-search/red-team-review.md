# Red-team review — f-v4-note-search (E8895, s22b)

- Verdict: **pass** (0 critical/high; 3 low/info)
- Reviewer: independent session `ses_e4d4a251effeuxr3rfiLT6kFg2`,
  model `qwen3.8-fast` / provider `llama-proxy` (cross-pair vs author
  `deepseek/deepseek-flash` / `deepseek`).
- Author session: `ses_e4d6a864dffepgOfSV1MMhaRS4` (api unit).
- Stand: test2 build `2210238`.

## Findings (low/info only)

1. **RT-NEW-1 (low):** `notebook.search` sessionStorage is not cleared on the
   no-token path, so a previous user's query text can persist across a later
   login in the same tab. Cosmetic only; notes stay owner-scoped. Also the
   clear button shows for whitespace-only queries.
2. **RT-NEW-2 (info):** no length cap on `q`; cost is bounded by the user's own
   note count, no DoS or panic.
3. **RT-NEW-3 (low):** `data/audit/runs/E8895/canary.json` is a gitignored
   runner artifact; the reviewer independently re-ran the 3 canaries and all
   were detected.

## Verification

- Owner scope, auth-first, empty/whitespace, case-insensitivity, `[]` not null,
  `UserID` hidden, 400/404/405 envelopes, no leaks: PASS.
- UI search state machine / single render path: PASS.
- `go build/vet/test`: PASS (32/32; targeted 8/8).
- Canary 3/3 detected.

Full machine-readable result: `red-team-review.json`.
