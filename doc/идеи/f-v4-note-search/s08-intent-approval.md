# s08 intent approval — f-v4-note-search (E9294)

Owner approval was obtained through the real Nexus approval authority
(`@nuxus_dev_bot`), not self-signed.

| field | value |
|---|---|
| request_id | `apr_51f1a2eee06fdf52df84569763ad0428` |
| subject_type | `brief` |
| subject_ref | `doc/идеи/f-v4-note-search/intent-brief.md` |
| branch | `dev/f-v4-note-search` |
| binding_profile | `blob` |
| payload_sha256 | `sha256:9b7dc2b752c221b69e0cece952fc5b3ad5d60cd58aa7560d68af0d562ad274c1` |
| policy | `notebook/brief` v2 |
| decision | `approved` |
| owner_id | `owner` |
| issued_at | `2026-11-05T10:05:20.916336985Z` |
| expires_at | `2026-11-05T10:18:43.58827Z` |

The signed assertion (`nexus.approval-signature/v1`) is stored outside the
repository in the ORC approvals store
(`.orc-approvals/apr_51f1a2eee06fdf52df84569763ad0428.json`), as in E4312. It is
not committed (per-run platform artifact; no secrets in the repo).

Platform note: `orc_human_request` could not read the artifact from its
execution worktree after the dev ORC restart (`read artifact ... no such file or
directory`), so the same real Nexus request was created via
`POST /api/v1/approvals` with the exact artifact bytes and digest. The owner
approved that request in `@nuxus_dev_bot`; no approval was fabricated or reused.
