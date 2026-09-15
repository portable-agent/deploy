# Диагностика

## Docker недоступен

Запусти Docker Desktop и проверь `docker version`. Без Docker полный k3d smoke невозможен, но
`check-chart.ps1` всё ещё может проверить Helm.

## Кластер уже существует

Скрипт останавливается и не меняет найденный кластер. Передай другое имя через `-ClusterName` либо
удали свой тестовый кластер вручную.

## Проверка упала в CI

Сначала смотри шаг `Проверить Helm chart`, затем `Проверить установку в k3d`. Не отключай cleanup ради
повторного запуска: для диагностики воспроизведи команду локально с уникальным именем кластера.

## Приложения не запускаются

1. Выполни `task status`, затем `task verify`.
2. Проверь, что рядом лежат репозитории `portable-agent-channel-gateway`, `portable-agent-agent-runtime`,
   `portable-agent-action-service`, `portable-agent-mcp-gateway` и `portable-agent-calendar-mcp`,
   либо задай их `*_CONTEXT` в `.env`.
3. Если Keycloak сообщает о старом fixture, локально выполни
   `task reset`. Команда запрашивает подтверждение и удаляет только volumes этого Compose project.
4. Проверь `/health/live` Channel Gateway и Agent Runtime, `/actuator/health/readiness` Action Service и `/health`
   двух MCP-сервисов.
5. Не включай Calendar test API вне локального профиля `apps`.

После запуска проверь весь backend-путь одной командой:

```powershell
task test:e2e
```

Команда поднимает окружение и запускает сценарий из соседнего `test-lab`. Он отправляет текст через
Channel Gateway, создаёт действие со случайным `requestKey`, подтверждает его и сверяет результат
Action Service с событием в тестовом календарном коннекторе. Если `test-lab` лежит в другой папке,
задай `TEST_LAB_PATH` в `.env`.

Первый Docker build скачивает Gradle и Python packages и может быть заметно медленнее повторных
запусков. BuildKit сохраняет слои для следующих сборок.

## Preview smoke не запускается

1. Выполни `task doctor`, затем проверь `helm version`, `kubectl version --client` и `k3d version`.
2. Используй положительный номер PR: `task preview:smoke PR=123`.
3. Если кластер `pa-preview-123` уже существует, скрипт намеренно его не меняет. Удали свой старый
   тестовый кластер вручную либо передай другое имя напрямую в `smoke-preview.ps1`.
4. В CI namespace и кластер удаляются в `finally`, даже если установка сервиса завершилась ошибкой.
