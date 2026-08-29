# Архитектура

```text
check-chart.ps1 -> helm lint/template
smoke-k3d.ps1  -> temporary k3d -> helm install -> ConfigMap check -> delete cluster
```

Chart `platform-base` пока не разворачивает сервисы. Он доказывает, что базовый путь доставки работает.
Это оставляет первый тест быстрым и не связывает deploy с незавершённой бизнес-архитектурой.
