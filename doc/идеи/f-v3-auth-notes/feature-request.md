# Сырой запрос человека — f-v3-auth-notes

Источник: постановка team-lead (2026-11-04). Документ неизменяем и используется
s07.requirements_reconcile как источник сверки «просил человек ↔ делаем».

## Цель

Удалить прямой prototype-бранч и заново сделать фичу «логин + заметки» строго
через path-10 / ORC. Новая v3-фича, не продолжение E1320.

## Scope (только backend + простой UI, in-memory, без БД)

API:

- `POST /api/register` body `{"username":"...","password":"..."}` -> 201
- `POST /api/login` body `{"username":"...","password":"..."}` -> 200 `{"token":"..."}`;
  401 при неверных данных
- `GET /api/notes` `Authorization: Bearer <token>` -> список заметок ТОЛЬКО
  текущего пользователя
- `POST /api/notes` `Authorization: Bearer <token>` body `{"text":"..."}` ->
  создать заметку текущего пользователя
- `DELETE /api/notes/{id}` `Authorization: Bearer <token>` -> удалить только свою
  заметку

Требования:

- users, sessions, notes — in-memory;
- пароли не хранить в открытом виде: соль + hash;
- bearer-токен;
- user A не видит и не удаляет заметки user B;
- без авторизации — 401;
- без утечки паролей/хэшей;
- данные живут в рамках процесса (рестарт = очистка, это ок для dev).

UI:

- статическая страница;
- регистрация;
- логин;
- список заметок;
- добавление;
- удаление;
- токен в памяти/localStorage;
- ошибки 401/400 показывать пользователю;
- без React/Vue, минимальный HTML/JS/CSS или Go embed.

## UI / E2E / Project contract

- Не ломать существующий path10 adapter.
- Обновить `path1.project.json`: `e2e.frontend_dir: web`,
  `e2e.command` — команда Playwright или штатный runner,
  `deploy.stand_command` — существующий path10 adapter, не archkit fallback,
  `audit.mode: app`, `audit.database: false`, `canaries.require_dsn: false`.
- Обновить `path1.ui.json`: `platform: web`.
- Добавить UI-граф: `arch/structure/ui-pages/...` или `UI-GRAPH.yaml`.
  Страницы: login, register, notes.
- Добавить Playwright `web/e2e/auth-notes.spec.js`.
  Сценарии: регистрация; логин; создание заметки; reload — заметка видна;
  удаление; user B не видит заметку user A; неавторизованный GET /api/notes -> 401.
- s21 gate-graph-actualized не скипать.

## Ограничения

- prod не деплоить; main/stage не менять; push в primary не делать.
- s45.push_primary и s46.post_deploy_verify не выполнять; canary rollout не
  запускать; audit-canary можно.
- E2495/f002.5, lk-agena-v2, kh_pg не трогать; E1320 не трогать.
- force/skip/waiver не применять.
- direct-код вне ORC-шагов не писать.
