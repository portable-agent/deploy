# Архитектура

```text
репа сервиса -> общий CI -> container + SBOM + signature
                              |
services/catalog.json -> environments/<env>/services/<name>/values.yaml
                              |
                      Argo CD ApplicationSet
                              |
                       charts/service -> Kubernetes
                              |
                  OpenTelemetry -> metrics/logs/traces
```

`services/catalog.json` — реестр сервисов, `environments` — различия окружений, а
`charts/service` — единые правила запуска. В values нет секретов: указываются только ссылки на
ключи Kubernetes Secret. Production намеренно не создан до отдельного ADR и выбора облака.

Локальная среда работает через Compose и использует те же классы зависимостей, что будущий
кластер. Полный smoke создаёт только временный k3d-кластер и всегда удаляет лишь созданный им
кластер.

## Локальный execution slice

```mermaid
sequenceDiagram
    participant User as Пользователь
    participant Agent as Agent Runtime
    participant Action as Action Service
    participant Keycloak
    participant Gateway as MCP Gateway
    participant Calendar as Calendar MCP

    User->>Keycloak: логин
    Keycloak-->>User: tenant + audience agent-runtime и action-service
    User->>Agent: текст + безопасный context + JWT
    Agent->>Agent: JWT + подготовка ActionPlan
    Agent-->>User: proposal требует подтверждения
    User->>Action: создать и подтвердить действие
    Action->>Action: JWT issuer + audience + tenant
    Action->>Keycloak: client_credentials
    Keycloak-->>Action: tenant + две audience + два scope
    Action->>Gateway: POST /api/v1/calls
    Gateway->>Gateway: JWT + allowlist
    Gateway->>Calendar: tools/call + тот же JWT
    Calendar->>Calendar: JWT + tenant + request_key
    Calendar-->>Action: eventId
```

Canonical issuer локального realm доступен хосту через `localhost`. Контейнеры загружают JWKS по
внутреннему имени `keycloak`, поэтому проверка токена не зависит от DNS хоста. `start-local -Apps`
сначала поднимает зависимости и создаёт Temporal namespace, затем собирает и запускает приложения.
Agent Runtime не исполняет и не сохраняет действие. Он создаёт предложение по контракту `2.1.0`;
после подтверждения Action Service становится источником состояния, аудита и Temporal workflow.
