# Deploy

Репозиторий содержит инженерный полигон Portable Agent. Compose поднимает инфраструктуру и локальный
slice `Telegram Adapter → Channel Gateway → Conversation Service → Agent Runtime → Action Service → MCP Gateway → Calendar MCP`. Минимальный
Helm chart устанавливается и проверяется в одноразовом k3d-кластере.

Текущий результат:

1. запуск acceptance-теста полного backend-пути из отдельного `test-lab`;
2. единый локальный JWT с отдельными audience сервисов, включая Conversation Service;
3. общий Channel Gateway с маршрутом Conversation и публичным контрактом `2.4.0`;
4. воспроизводимый Compose с локальной сборкой всех приложений;
5. отдельная БД и Conversation Service, создающий Action и виджет подтверждения;
6. изолированный ephemeral preview namespace для инфраструктурных pull request;
7. Telegram Adapter, Keycloak Device Flow и локальный fake Telegram API без настоящего bot token.

Первый переносимый виджет подтверждения входит в системный acceptance-путь. Публичный preview URL
появится после подключения общего Kubernetes-кластера и контроллера жизненного цикла окружений.
