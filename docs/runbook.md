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

1. Выполни `pwsh ./scripts/check-compose.ps1`.
2. Проверь, что рядом лежат репозитории `portable-agent-action-service`,
   `portable-agent-mcp-gateway` и `portable-agent-calendar-mcp`, либо задай их `*_CONTEXT` в `.env`.
3. Если Keycloak сообщает о старом fixture, локально выполни
   `pwsh ./scripts/stop-local.ps1 -DeleteData`. Команда удаляет только volumes этого Compose project.
4. Проверь `/actuator/health/readiness` Action Service и `/health` двух MCP-сервисов.
5. Не включай Calendar test API вне локального профиля `apps`.

После запуска проверь весь backend-путь одной командой:

```powershell
pwsh ./scripts/check-apps.ps1
```

Она создаёт действие со случайным `requestKey`, подтверждает его и сверяет результат Action Service
с событием в тестовом календарном коннекторе.

Первый Docker build скачивает Gradle и Python packages и может быть заметно медленнее повторных
запусков. BuildKit сохраняет слои для следующих сборок.
