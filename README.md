# Deploy

Репозиторий хранит Helm charts и локальный k3d smoke-тест Portable Agent. Здесь нет бизнес-кода,
секретов и настроек реального production.

## Текущий пакет

Первый пакет проверяет только путь `Helm -> Kubernetes`:

- `helm lint` проверяет chart;
- `helm template` проверяет render;
- временный k3d-кластер устанавливает chart;
- smoke-тест читает контрольный ConfigMap;
- созданный тестом кластер всегда удаляется.

## Требования

- Docker Desktop;
- Helm 4.2.4;
- k3d 5.9.0;
- kubectl;
- PowerShell 7.

Проверка chart без кластера:

```powershell
pwsh ./scripts/check-chart.ps1
```

Полная проверка:

```powershell
pwsh ./scripts/smoke-k3d.ps1
```

Архитектура и следующий шаг описаны в [docs/index.md](docs/index.md). Правила для разработчиков и
AI-агентов находятся в [AGENTS.md](AGENTS.md).
