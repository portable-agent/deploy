# Deploy

Репозиторий содержит инженерный полигон Portable Agent. Compose поднимает инфраструктуру и локальный
slice `Channel Gateway → Agent Runtime → Action Service → MCP Gateway → Calendar MCP`. Минимальный
Helm chart устанавливается и проверяется в одноразовом k3d-кластере.

Текущий результат:

1. запуск acceptance-теста полного backend-пути из отдельного `test-lab`;
2. единый локальный JWT с отдельными audience сервисов;
3. общий Channel Gateway и Agent Runtime с закрытыми API и контрактом `2.2.0`;
4. воспроизводимый Compose с локальной сборкой всех приложений.
5. изолированный ephemeral preview namespace для инфраструктурных pull request.

Следующий продуктовый этап — первый переносимый виджет подтверждения. Публичный preview URL появится
после подключения общего Kubernetes-кластера и контроллера жизненного цикла окружений.
