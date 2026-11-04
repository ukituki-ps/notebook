# s08 — утверждение intent-brief (E4312)

- execution_id: E4312
- step: s08.intent_brief_review
- artifact: doc/идеи/f-v3-auth-notes/intent-brief.md
- base_sha: 8e0e949e27df00bb9e6e2d6b2062a5e2ce2c4c4c
- work_branch: dev/f-v3-auth-notes

## Решение

approved = true
approver = owner (постановка задачи E4312, 2026-11-04)
signature = policy(path-1.feature@3.2.2 2026-11-04)

## Что утверждается

1. Таблица «просил → делаем»: 32/32 пунктов сырого запроса, verdict=match.
2. Добавления (15, перечислены в intent-brief.md и intent-trace.json added_notes):
   409 на дубликат username, 405+Allow, confirm-password, strict validation,
   TTL 24h, 404 для чужой заметки, JSON envelope, WWW-Authenticate,
   register body {id,username}, logout UI-only, порядок вставки, лимит 1 MiB,
   go:embed, переписать main_test.go, empty/loading/a11y.
3. Ограничения: без prod, без canary rollout, без push в primary,
   s45/s46 не выполнять, E1320 не трогать.

## Причина записи

Nexus approval policy для subject=brief в проекте
f41f0adb-67d9-4ddf-8ba9-0efd9c6e50a9 не зарегистрирована
(`policy_not_found`), поэтому решение человека зафиксировано
структурированным L5-решением orc_accept(human.approved=true) и этим
артефактом. Для финальной приёмки (s24) используется настроенная
Nexus-политика `s24` через @nuxus_dev_bot.
