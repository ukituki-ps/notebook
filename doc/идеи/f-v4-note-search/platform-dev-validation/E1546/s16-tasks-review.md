# Task briefs — f-v4-note-search (s16.brief_tasks, E1546)

- **Step:** `s16.brief_tasks`
- **Execution:** `E1546`
- **Artifacts:** `doc/идеи/f-v4-note-search/T0001/brief.md`, `T0002/brief.md`, `T0003/brief.md`

## Verdict

**PASS** — three task briefs exist, one per unit, with files, oracles and
out-of-scope consistent with M01 and the plan:

| Task | Unit | Scope | Oracle |
|---|---|---|---|
| T0001 | notebook-search-api | search helper/handler/owner scope/tests | TestNotesSearch* |
| T0002 | notebook-search-ui | search markup, filter/clear/empty, UI semantics | TestUISemantics |
| T0003 | notebook-search-deploy-e2e | Playwright scenarios, adapter, UI graph | 6 E2E + s21 |

The unit briefs are bound to the plan (T0001–T0010 map) and leave auth/
persistence untouched. No task broadens scope beyond the approved
change-definition.
