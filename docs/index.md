# Deploy

Репозиторий содержит инженерный полигон Portable Agent. Compose поднимает инфраструктуру и локальный
полный локальный slice `Agent Runtime → Action Service → MCP Gateway → Calendar MCP`. Минимальный
Helm chart устанавливается и проверяется в одноразовом k3d-кластере.

Текущий результат:

1. acceptance-тест полного backend-пути в `test-lab`;
2. единый локальный JWT с отдельными audience сервисов;
3. Agent Runtime с закрытым API и контрактом `2.1.0`;
4. воспроизводимый Compose с локальной сборкой всех приложений.

Следующий инфраструктурный пакет — preview namespace для pull request. Бизнес-этап после него —
Channel Gateway и первый переносимый виджет.
