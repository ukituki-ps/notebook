# s20a — блокер preview: host stand-runner hash-pin (E4312)

- execution: E4312
- step: s20a.unit_integrate (gate-l2-integration)
- stand: test2 (https://test2.nexus.ukituki.tech), lease `d9ae763b-1499-4558-b89a-6c5a5521b709`
- branch: dev/f-v3-auth-notes
- evaluated_sha: `fb47b3e778dadb72392b18b537a639e663915467`

## Симптом 1 — на стенде старый build

`gate-l2-integration` (`bash tools/check-integration-on-stand.sh E4312`) упал:

```
e2e-preview: health build_ref=be5a077 commit=be5a077098402cf4347f6331b99a16c84f624604
e2e-preview: FAIL unauth GET /api/notes: ожидался HTTP 401, получен 200
gate-l2-integration: FAIL — integration.command (stand test2)
```

Стенд отдаёт build `be5a077` (старый, без auth), а не `fb47b3e`.

## Симптом 2 — штатный deploy отклонён runner'ом

`preview-deploy.sh` в ORC-контейнере недоступен (`docker: command not found`).
Штатный путь — `tools/stand-runner-client.sh` (очередь → host-runner на pr01).

Попытка:

```
stand-runner-client.sh E4312 deploy-preview
  -> reject: eval-worktree-missing: .../.orc-eval/E4312/fb47b3e...
```

Worktree создан вручную и запрос повторён:

```
stand-runner: reject: hash-pin: manifest-mismatch: tools/check-evidence-authentic.sh
```

## Причина

Host-runner (`/home/ukituki/lkfl-runner/stand-runner.sh`) проверяет свой
CODE_ROOT по `/home/ukituki/lkfl-runner/manifest.sha256`. Манифест не совпадает
с текущим `tools/check-evidence-authentic.sh`:

- actual sha256: `e7ffb342fb62208b3af2ebf20a959c7e57195388ff0cc98f24b51f54fb416525`
- manifest ожидает другой хеш (mismatch).

Это drift host-runner code ↔ manifest, не связанный с кодом notebook.
Из ORC-контейнера `/home/ukituki` недоступен, исправить нельзя.

## Что не делалось

- prod/main/stage не трогались;
- canary rollout не запускался;
- s45/s46 не выполнялись;
- gate не обходился (никаких skip/waiver/force);
- e2e-preview.sh не ослаблялся.

## Unblock

На pr01 (host runner):

1. Пересобрать манифест под текущий runner code:
   `cd /home/ukituki/lkfl-runner && find tools deploy -type f -print0 | sort -z | xargs -0 sha256sum > manifest.sha256`
   (или атомарно передеплоить runner code + manifest).
2. Проверить: `stand-runner.sh --once <queue>` принимает запрос без `hash-pin`.
3. Выкатить E4312 на test2:
   `STAND_RUNNER_PROJECT_ID=f41f0adb-67d9-4ddf-8ba9-0efd9c6e50a9 STAND_RUNNER_TRANSPORT=git STAND_RUNNER_COMMIT=<HEAD> tools/stand-runner-client.sh E4312 deploy-preview`
4. Повторить s20a accept (gate-l2-integration), затем s20b/s20c.

Текущий HEAD ветки содержит blocker-артефакт; код и adapter не изменены.
