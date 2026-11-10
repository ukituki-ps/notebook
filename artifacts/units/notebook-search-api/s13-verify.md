# s13 independent verification — notebook-search-api

- Execution: E6636 (E6636-s20.sde_5fexecution-u01), unit `notebook-search-api`
- Branch: `orc-exec-E6636-s20.sde_5fexecution-u01`
- Verified HEAD: `8e9fee2f39febccba35e26f4c83bba20898d4ec0` (s12)
- Baseline step: s12.unit_check
- Verified by: `architect` — independent verifier (session `ses_e3b38ba39ffe7063QvD0d1xGxK`), ≠ executor (`agent:s11.sde-backend`)
- Mode: own re-read of `main.go` + fresh build/test; executor claims not relied on
- Evidence: PR-138b2d929ed4, exit 0 (sha256:a8a5d2bc2cb758dcd55048bb909afc00fa739cae7063e44282c01c29203c52a0)

## Verdict: PASS

## Проверенные критерии (независимо)

1. **`q` trim / empty / whitespace / case-insensitive / `[]` not null** — `main.go:546`
   `strings.ToLower(strings.TrimSpace(rawQuery))`; фильтр исполняется только при
   `query != ""`; `ListNotes` → `make([]Note, 0)`, filtered → `make([]Note, 0, len(notes))`;
   `TestNotesSearch*` (12) PASS.
2. **owner predicate before text predicate; UserID not serialized** — порядок доказан
   статически: requireAuth (531) < cap (542) < `ListNotes(session.UserID)` (547);
   фильтр идёт по уже owner-scoped срезу, расширить scope не может.
   `Note.UserID` = `json:"-"`; leak-scan в `TestNotesSearchIsolation`.
3. **512-byte cap before scan; >512 → 400 `query too long`; ровно 512 — принято** —
   `maxQueryBytes = 512` (line 33), проверка `len(rawQuery) > maxQueryBytes` до `ListNotes`,
   `writeErr(..., "query too long")`; тесты: 513→400, 512→200, 256 двухбайтных рун (512 B)→200,
   257 рун (514 B)→400, whitespace-only >512→400.
4. **auth 401 before query handling** — `requireAuth` первым в `handleNotes` (531) до
   switch/cap; oversized `q` без токена → 401 (`TestNotesSearchAuthRequired`).
5. **verify base contract, add only missing Go tests** — `git diff 1722a1e..HEAD -- main.go`
   пуст (продуктовый код не менялся); дельта юнита — `main_test.go` (+3 теста) и артефакты.

## Прогон

| Check | Result |
|---|---|
| `GOWORK=off go build ./...` | PASS |
| `GOWORK=off go test -count=1 ./...` | ok, 8.771s |
| main.go unchanged vs base | yes (test-only change) |
| `t.Skip` в тестах | 0 |
| порядок auth < cap < ListNotes (awk) | подтверждён |
| `UserID json:"-"`, `make([]Note,0)`, `query too long` | присутствуют |

## Ограничения

- `go test -race` недоступен в окружении (CGO_ENABLED=0); вне плана верификации, не дефект.
- Findings CR-1..CR-3/RT-1/RT-2 относятся к unit `notebook.delete-note`, не к этому юниту.

Verdict: **pass**.
