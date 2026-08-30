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
