# Deploy

Репозиторий содержит инженерный полигон Portable Agent. Compose поднимает инфраструктуру и локальный
execution slice `Action Service → MCP Gateway → Calendar MCP`. Минимальный Helm chart устанавливается
и проверяется в одноразовом k3d-кластере.

Следующие пакеты после execution slice:

1. acceptance-тест backend-пути в `test-lab`;
2. values трёх приложений для `local`, `dev` и `stage` без секретов;
3. Agent Runtime и полный пользовательский путь;
4. preview namespace для pull request.
