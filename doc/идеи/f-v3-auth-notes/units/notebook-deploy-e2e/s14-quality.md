# s14 — QUALITY: notebook-deploy-e2e (U03)

- quality_score: **9/10**
- crutch_density: **low**
- commit: 6df49a2184ef307bbf4e936c75d9eb1eb9be9179

## Оценка

- Dockerfile: минимальный diff (COPY *.go, COPY web/), runtime не изменён.
- .dockerignore сохраняет embed-файлы, исключает e2e/node_modules.
- e2e-preview.sh: health + auth-smoke + A/B isolation + негативы + Playwright,
  fail-close без браузеров; без python3-зависимости.
- adapter меняет только целевые поля; preview-deploy.sh и stand_command не
  тронуты; canary сохранён.
- Скрипт проверен на mock-стенде и fail-close сценариях.

## Crutches

Не обнаружено.
