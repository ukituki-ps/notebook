# s20 session fan-out blocker — f-v4-note-search (E9294)

**Status: STOP / paused.** Session fan-out did not create separate child
sessions; all three child executions fall back to the parent session. Per the
run contract, no unit was executed in the parent session and no gate was
bypassed.

## Execution

- Parent execution: `E9294`
- Process: `path-1.feature@3.2.2`, entry `default`, transport `git`
- Work branch: `dev/f-v4-note-search`
- Base: `406fa965480025f452781ca864f7b1c44491ed28`
- Parent session: `ses_e54e710ecffecdgw6dBBoKJqbO`
- Parent status: `paused` at `s20.sde_execution` (`last_seq=18`)
- Stand: `test2` lease `46c08a4f-dde4-4fb8-8cbd-17286130ae4a` was **released**
  after the STOP (no units ran).

## Fan-out result (actual)

| Unit | Child execution | Child session_id | Steps | last_seq |
|---|---|---|---|---|
| `notebook-search-api` | `E9294-s20.sde_5fexecution-u01` | `ses_e54e710ecffecdgw6dBBoKJqbO` | all `pending` | 0 |
| `notebook-search-ui` | `E9294-s20.sde_5fexecution-u02` | `ses_e54e710ecffecdgw6dBBoKJqbO` | all `pending` | 0 |
| `notebook-search-deploy-e2e` | `E9294-s20.sde_5fexecution-u03` | `ses_e54e710ecffecdgw6dBBoKJqbO` | all `pending` | 0 |

Expected by the run contract:

1. 3 child executions — **OK**;
2. 3 different child session_ids — **FAIL** (all equal to the parent);
3. parent session_id differs from every child — **FAIL**;
4. parent receives only summary/diff/verdict — only the fan-out dispatch
   summary was received (`total=3`, unit ids), but the session separation that
   makes this meaningful is absent;
5. token usage per session — **not applicable/0 for children**: no child
   sessions were created; the parent session carries all usage. ORC status does
   not expose a token counter;
6. no fallback to the parent session — **FAIL** (fallback is exactly what
   happened).

Fixture contrast (same dev ORC/Nexus): `SESFAN-1793828602-p` and its three
children had four distinct sessions (`ses_e577bb73…`, `ses_e577b91a5…`,
`ses_e577b6d66…`, `ses_e577b486d…`). The real execution did not reproduce that
behaviour.

## Evidence

- `orc_orc_next(E9294)` returned `fanout.dispatch` with three child executions;
- `orc_orc_status` for each child returned `session_id = ses_e54e710ecffecdgw6dBBoKJqbO`
  (parent), `last_seq=0`, all unit steps `pending`;
- re-check after 20 s produced the same result (not an async race);
- `orc_orc_watch(E9294)` shows `fanout_materialized` (`total=3`) and three
  `unit_started` events, with no child session assignment;
- parent status still `running` at `s20.sde_execution`, `last_seq=18`, then
  paused.

## Actions taken at STOP

- parent `E9294` paused;
- children `…-u01`, `…-u02`, `…-u03` paused (`unit_paused=true`);
- no unit step was executed, no `orc_accept` for s20 or downstream;
- `test2` lease released;
- no prod/main/stage, no canary, no s45/s46; `E4312`/`E1320` untouched;
- `f-v3-auth-notes` untouched;
- no force/skip/waiver.

## Resume condition

Platform must assign a distinct session to each child execution (as in the
fixture). Then:

1. re-lease `test2` for `E9294`;
2. resume `E9294` (and the children, if the platform resumes them);
3. re-run the fan-out check (3 distinct child sessions, parent distinct);
4. only then execute the three units, s20a, s20b, s20c, s21, s22*, s23, s24.

Accepted before the blocker: `s01`–`s19` (see execution E9294). Latest accepted
commit: `a8e460f885cafcaa5e4dd34db6935da46bbb0aa2` (s19 lease record).
