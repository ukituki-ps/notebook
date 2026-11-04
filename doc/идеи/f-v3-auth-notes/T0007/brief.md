# T0007 — brief

- unit_id: **notebook-deploy-e2e**
- domain: **notebook-deploy**
- sde: **sde-infra**
- change_class: **security**
- task: Dockerfile build-stage с `web/` + `.dockerignore`
- files: `deploy/Dockerfile`, `.dockerignore`
- depends_on: —

## Scope

1. **`deploy/Dockerfile` (build stage).** В `FROM golang:1.23-alpine AS build`:
   - копировать все Go-файлы сборки (`COPY *.go ./` вместо только `main.go`),
     чтобы новые тесты/файлы не ломали сборку;
   - добавить `COPY web/ ./web/` **до** `go build`, иначе `go:embed` не
     соберётся (embed-паттерны `web/index.html web/app.js web/app.css`);
   - порядок: `go.mod` → `*.go` → `web/` → `go build`.
2. **Runtime-stage не менять:** `alpine:3.20`, `COPY --from=build
   /out/notebook /notebook`, `EXPOSE 8080`, `ENTRYPOINT ["/notebook"]`,
   build-args/env (`NEXUS_BUILD_*`) сохраняются; никаких volume/`WORKDIR` для
   `web/` (статика в бинаре).
3. **`.dockerignore`.** Добавить `web/e2e/`, `web/node_modules/` (spec и
   зависимости не нужны в образе), сохранить существующие правила
   (`/notebook`, `*.log`, `deploy/stands/.runtime/`, `data/`). Не игнорировать
   `web/index.html`, `web/app.js`, `web/app.css`.
4. **`deploy/path1/preview-deploy.sh` не редактируется** (path10 adapter;
   `docker build -f deploy/Dockerfile` уже используется).
5. Локальный `docker build`/preview deploy — s20b (нужен смерженный `web/`);
   здесь статическая проверка порядка COPY и неизменности runtime.

## Acceptance / оракулы

```sh
grep -n 'COPY web/ ./web/' deploy/Dockerfile
grep -n 'COPY \*.go ./' deploy/Dockerfile
awk '/COPY web\/ \.\/web\//{w=NR} /go build/{b=NR} END{exit !(w && b && w<b)}' deploy/Dockerfile
grep -q 'web/e2e/' .dockerignore
grep -q 'web/node_modules/' .dockerignore
git diff --exit-code deploy/path1/preview-deploy.sh
```

- `COPY web/ ./web/` присутствует и стоит **до** `go build`.
- `COPY *.go ./` присутствует; build-stage содержит `web/`.
- Runtime-stage/`ENTRYPOINT`/`EXPOSE`/build-args не изменены относительно базы.
- `.dockerignore` содержит `web/e2e/` и `web/node_modules/`, но не исключает
  три embed-файла.
- `deploy/path1/preview-deploy.sh` без diff.

## Зависимости

- Нет для правки. Реальная сборка/выкат — s20b после merge U01+U02;
  **T0008** опирается на этот образ (e2e-прогон на стенде).

## Что НЕ делать

- Не менять runtime-stage, `ENTRYPOINT`, `EXPOSE`, build-args/env.
- Не копировать `web/` в runtime-образ и не добавлять volume/`WORKDIR`.
- Не редактировать `deploy/path1/preview-deploy.sh` и другие path10-скрипты.
- Не собирать `docker build` здесь (отложено до s20b) и не деплоить.
- Не менять `web/*`, `main.go`, `main_test.go`, adapter-файлы.
- Не добавлять `.dockerignore`-правила, исключающие `web/index.html`,
  `web/app.js`, `web/app.css`.
- Не трогать prod/canary rollout, `s45/s46`.
