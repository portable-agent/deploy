# Deploy

Репозиторий хранит локальную инфраструктуру, общий Helm chart и GitOps-описание Portable Agent.
Здесь нет бизнес-кода, секретов и настроек реального production.

## Текущий пакет

Платформа разработки включает:

- Compose-профиль `core`: PostgreSQL, Redpanda, Keycloak, Temporal и OPA;
- Compose-профиль `apps`: Channel Gateway, Agent Runtime, Action Service, MCP Gateway и Calendar MCP;
- Compose-профиль `observe`: OpenTelemetry, Prometheus, Grafana, Tempo и Loki;
- безопасный общий chart `charts/service`;
- Argo CD bootstrap `charts/gitops`;
- каталог окружений и генератор нового сервиса;
- быстрые проверки в каждом PR и полный k3d smoke по расписанию.

## Требования

- Docker Desktop;
- Helm 4.2.4;
- k3d 5.9.0;
- kubectl;
- PowerShell 7.

Создай локальный файл настроек и запусти инфраструктуру:

```powershell
Copy-Item .env.example .env
pwsh ./scripts/start-local.ps1 -Observe
```

Чтобы поднять проверяемый путь `Channel → Agent → Action → Gateway → Calendar`, используй:

```powershell
pwsh ./scripts/start-local.ps1 -Apps
pwsh ./scripts/check-apps.ps1
```

`check-apps.ps1` отправляет demo-команду в Channel Gateway, проверяет предложение, создаёт и
подтверждает действие, ждёт Temporal workflow и проверяет, что Calendar MCP сохранил ровно одно
событие с тем же `eventId`.

Та же проверка выполняется workflow `Full application smoke` при изменениях Compose-пути. Workflow
читает полные Git SHA из `config/versions.env`, собирает именно эти версии сервисов в отдельном
Compose project и всегда удаляет только созданные им контейнеры и volumes.

`-Apps` собирает образы из соседних локальных репозиториев через `compose/apps.local.yaml`. Пути можно
переопределить переменными `CHANNEL_GATEWAY_CONTEXT`, `AGENT_RUNTIME_CONTEXT`, `ACTION_SERVICE_CONTEXT`,
`MCP_GATEWAY_CONTEXT` и `CALENDAR_MCP_CONTEXT`; вход в GHCR для локального запуска не нужен. По
умолчанию Channel Gateway доступен на `http://localhost:18084`, Agent Runtime — на
`http://localhost:18080`, Action API — на
`http://localhost:18081`, MCP Gateway — на `http://localhost:18083`, а Calendar MCP — на
`http://localhost:18082`.

Файл `.env` локальный и не коммитится. Значения `dev` и `stage` должны приходить из secret
manager, а не из Git.

Локальный Keycloak импортирует realm `portable-agent`. Публичный тестовый client
`portable-agent-local` и пользователь `local-user` с паролем `local-user-change-me` существуют только
в Compose fixture. Отдельный confidential client `action-service` выдаёт worker служебный токен с
`tenant_id`, audience `mcp-gateway` и `calendar-mcp`, scopes `mcp:call` и `calendar:write`. Значения
локального секрета и tenant приходят из `.env`, а не зашиты в image. PostgreSQL создаёт отдельную БД
`actions` для Action Service.

Проверочный API Calendar MCP включён только в локальном профиле `apps`, привязан к loopback-порту и
защищён `CALENDAR_TEST_API_KEY`. Хранилище fake-calendar пока находится в памяти: перезапуск контейнера
очищает созданные тестовые встречи.

После запуска скрипт получает настоящий JWT и сверяет пользователя, `tenant_id` и audience
`channel-gateway`, `agent-runtime`, `action-service` и `calendar-mcp` с realm fixture. Один
пользовательский токен проходит независимую проверку в Channel Gateway, Agent Runtime и Action API.
Если Keycloak volume создан старой версией fixture, запуск остановится с командой для явного
пересоздания локальных данных.

Worker, Temporal UI и Linux Compose используют внутренний адрес `temporal:7233`. На Windows скрипт
подключает `compose/windows.local.yaml`: CLI создания namespace идёт через опубликованный порт,
потому что Docker Desktop иногда не проводит этот gRPC по имени сервиса. Адрес можно переопределить
переменной `TEMPORAL_ADMIN_ADDRESS`.

Все быстрые проверки:

```powershell
pwsh ./scripts/check-config.ps1
```

Полная проверка:

```powershell
pwsh ./scripts/smoke-k3d.ps1
```

Подготовить delivery-файлы нового сервиса:

```powershell
pwsh ./scripts/new-service.ps1 -Name sample-api -Image ghcr.io/portable-agent/sample-api -Port 8080
```

Архитектура и следующий шаг описаны в [docs/index.md](docs/index.md). Правила для разработчиков и
AI-агентов находятся в [AGENTS.md](AGENTS.md).
