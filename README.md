# Deploy

Репозиторий хранит локальную инфраструктуру, общий Helm chart и GitOps-описание Portable Agent.
Здесь нет бизнес-кода, секретов и настроек реального production.

## Текущий пакет

Платформа разработки включает:

- Compose-профиль `core`: PostgreSQL, Redpanda, Keycloak, Temporal и OPA;
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

Файл `.env` локальный и не коммитится. Значения `dev` и `stage` должны приходить из secret
manager, а не из Git.

Локальный Keycloak импортирует realm `portable-agent`. Публичный тестовый client
`portable-agent-local` и пользователь `local-user` с паролем `local-user-change-me` существуют только
в Compose fixture. JWT содержит тестовый `tenant_id`. PostgreSQL создаёт отдельную БД `actions` для
Action Service.

Если Docker Desktop на Windows принимает обычный TCP по имени `temporal`, но gRPC-клиенты получают
`context deadline exceeded`, добавь в локальный `.env`:

```dotenv
TEMPORAL_ADDRESS=host.docker.internal:7233
```

Это только локальное переопределение. В CI и Linux Compose остаётся стандартный адрес
`temporal:7233`; IP-адрес контейнера нигде не фиксируется.

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
