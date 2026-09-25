# Deploy

Репозиторий хранит локальную инфраструктуру, общий Helm chart и GitOps-описание Portable Agent.
Здесь нет бизнес-кода, секретов и настроек реального production.

## Текущий пакет

Платформа разработки включает:

- Compose-профиль `core`: PostgreSQL, Redpanda, Keycloak, Temporal и OPA;
- Compose-профиль `apps`: Telegram Adapter, fake Telegram API, Channel Gateway, Conversation Service, Agent Runtime, Action Service, MCP Gateway и Calendar MCP;
- Compose-профиль `observe`: OpenTelemetry, Prometheus, Grafana, Tempo и Loki;
- безопасный общий chart `charts/service`;
- изолированный PR preview namespace с quota, limits и default-deny сетью;
- Argo CD bootstrap `charts/gitops`;
- каталог окружений и генератор нового сервиса;
- быстрые проверки в каждом PR и полный k3d smoke по расписанию.

## Требования

- Docker Desktop;
- Helm 4.2.4;
- k3d 5.9.0;
- kubectl;
- Task 3.53.1;
- Windows PowerShell 5.1 или PowerShell 7.

На Windows установи Task один раз:

```powershell
winget install --id Task.Task --exact --version 3.53.1
```

Открой новый терминал и выполни `task doctor`, чтобы проверить Docker Engine и Docker Compose.

Создай локальный файл настроек и запусти только инфраструктуру без приложений:

```powershell
Copy-Item .env.example .env
task infra:up
```

Поднять один сервис из соседней локальной репы вместе с обязательными зависимостями:

```powershell
task service:up SERVICE=action-service
```

После изменения кода пересобери только нужный сервис:

```powershell
task service:restart SERVICE=action-service
```

Чтобы поднять и проверить путь `Channel → Conversation → Agent → Action → Gateway → Calendar`, используй:

```powershell
task services:up
task test:e2e
```

`task status` показывает состояние, `task service:logs SERVICE=action-service` — логи. `task down`
сохраняет локальные данные. `task reset` удаляет только volumes текущего Compose project и всегда
требует явного подтверждения.

`deploy` поднимает окружение, затем `run-test-lab.ps1` передаёт локальную тестовую конфигурацию в
соседний репозиторий `portable-agent-test-lab`. Сам black-box сценарий принадлежит `test-lab`: он
отправляет demo-команду в Channel Gateway, подтверждает действие, ждёт Temporal workflow и проверяет,
что Calendar MCP сохранил ровно одно событие с тем же `eventId`.

Та же проверка выполняется workflow `Full application smoke` при изменениях Compose-пути. Workflow
читает полные Git SHA из `config/versions.env`, собирает именно эти версии сервисов в отдельном
Compose project и всегда удаляет только созданные им контейнеры и volumes.

`-Apps` собирает образы из соседних локальных репозиториев через `compose/apps.local.yaml`. Пути можно
переопределить переменными `CHANNEL_GATEWAY_CONTEXT`, `AGENT_RUNTIME_CONTEXT`, `ACTION_SERVICE_CONTEXT`,
`CONVERSATION_SERVICE_CONTEXT`, `MCP_GATEWAY_CONTEXT`, `CALENDAR_MCP_CONTEXT` и
`TELEGRAM_ADAPTER_CONTEXT`; вход в GHCR для локального запуска не нужен. Fake Telegram API отвечает
локально и не требует настоящего bot token.
Если в `.env` оставлен placeholder `derive-from-local-webhook-secret`, команда запуска получает
стабильный локальный encryption key из webhook secret только в памяти процесса. Для любого общего
окружения `TELEGRAM_TOKEN_KEY_BASE64` должен приходить отдельным случайным секретом.

### Настоящий Telegram локально

Создай тестового бота через BotFather и добавь только в локальный `.env`:

```dotenv
TELEGRAM_REAL_BOT_TOKEN=<token BotFather>
TELEGRAM_REAL_WEBHOOK_SECRET=<случайная строка длиной от 32 символов>
```

Подключить настоящий Bot API через временный HTTPS URL:

```powershell
task telegram:real:up
```

После проверки обязательно удали временный webhook и верни локальный fake API:

```powershell
task telegram:real:down
```

Quick Tunnel предназначен только для ручной локальной проверки. Команда не печатает bot token и
не сохраняет его в Compose-файлах. После живого прогона в тесты переносятся только обезличенные формы
Telegram Update и Bot API response.

`TEST_LAB_PATH` по умолчанию указывает на соседний `../portable-agent-test-lab`; путь можно
переопределить в `.env`. Channel Gateway доступен на `http://localhost:18084`, Agent Runtime — на
`http://localhost:18080`, Action API — на
`http://localhost:18081`, MCP Gateway — на `http://localhost:18083`, а Calendar MCP — на
`http://localhost:18082`. Conversation Service доступен на `http://localhost:18085`. Новый маршрут
`/api/v1/conversations/messages` в Channel Gateway передаёт сообщения в него; старый маршрут
`/api/v1/messages` временно сохранён для обратной совместимости. Решение confirmation-виджета
отправляется в `/api/v1/actions/{actionId}/decisions` того же Gateway и только затем попадает в Action
Service.

Файл `.env` локальный и не коммитится. Значения `dev` и `stage` должны приходить из secret
manager, а не из Git.

Локальный Keycloak импортирует realm `portable-agent`. Публичный тестовый client
`portable-agent-local` и пользователь `local-user` с паролем `local-user-change-me` существуют только
в Compose fixture. Отдельный confidential client `action-service` выдаёт worker служебный токен с
`tenant_id`, audience `mcp-gateway` и `calendar-mcp`, scopes `mcp:call` и `calendar:write`. Значения
локального секрета и tenant приходят из `.env`, а не зашиты в image. Отдельный confidential client
`telegram-adapter` включает OAuth Device Authorization Grant и выдаёт пользовательский токен с теми
же `tenant_id` и audience backend-пути. PostgreSQL создаёт отдельные БД `actions`, `conversations` и
`telegram_adapter`.

Проверочный API Calendar MCP включён только в локальном профиле `apps`, привязан к loopback-порту и
защищён `CALENDAR_TEST_API_KEY`. Хранилище fake-calendar пока находится в памяти: перезапуск контейнера
очищает созданные тестовые встречи.

После запуска скрипт получает настоящий JWT и сверяет пользователя, `tenant_id` и audience
`channel-gateway`, `conversation-service`, `agent-runtime`, `action-service` и `calendar-mcp` с realm fixture.
Один пользовательский токен проходит независимую проверку во всех пользовательских API.
Если Keycloak volume создан старой версией fixture, запуск остановится с командой для явного
пересоздания локальных данных.

Worker, Temporal UI и Linux Compose используют внутренний адрес `temporal:7233`. На Windows скрипт
подключает `compose/windows.local.yaml`: CLI создания namespace идёт через опубликованный порт,
потому что Docker Desktop иногда не проводит этот gRPC по имени сервиса. Адрес можно переопределить
переменной `TEMPORAL_ADMIN_ADDRESS`.

Все быстрые проверки:

```powershell
task verify
```

Полная проверка:

```powershell
./scripts/smoke-k3d.ps1
```

Проверить модель временного окружения для номера pull request:

```powershell
task preview:smoke PR=123
```

Команда создаёт отдельный k3d-кластер и namespace `portable-agent-pr-123`, применяет guardrails,
устанавливает тестовый сервис и всегда удаляет только созданный кластер. Сейчас это ephemeral
CI-preview без публичного URL. После подключения общего Kubernetes-кластера тот же `charts/preview`
будет создавать долгоживущий namespace, а ingress и DNS останутся ответственностью платформы.

Подготовить delivery-файлы нового сервиса:

```powershell
./scripts/new-service.ps1 -Name sample-api -Image ghcr.io/portable-agent/sample-api -Port 8080
```

Архитектура и следующий шаг описаны в [docs/index.md](docs/index.md). Правила для разработчиков и
AI-агентов находятся в [AGENTS.md](AGENTS.md).
