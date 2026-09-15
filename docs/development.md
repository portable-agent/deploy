# Разработка

## Обычный цикл

Taskfile — единая точка входа. Внутренние PowerShell-скрипты остаются короткой реализацией команд,
но разработчику не нужно помнить Compose-файлы, profiles и env-файлы.
После установки Task выполни `task doctor`: команда заранее проверит Docker Engine и Docker Compose.

Для работы над сервисом:

1. Выполни `task infra:up`, чтобы поднять PostgreSQL, Redpanda, Keycloak, Temporal и OPA.
2. Запусти нужный сервис командой `task service:up SERVICE=<name>` либо запусти его из IDE против
   опубликованных локальных портов инфраструктуры.
3. После изменения кода выполни `task service:restart SERVICE=<name>`.
4. Посмотри состояние через `task status`, логи — через `task service:logs SERVICE=<name>`.
5. Перед pull request выполни `task test:e2e`.

Допустимые имена: `channel-gateway`, `agent-runtime`, `action-service`, `mcp-gateway` и
`calendar-mcp`. Неизвестное имя отклоняется до вызова Docker.

`task test:e2e` поднимает полный локальный срез, ждёт healthchecks и проверяет путь от текста до
сохранённого события. Следующий пакет передаст запуск black-box сценариев репозиторию `test-lab`.

`task down` не удаляет данные. `task reset` предназначен для явного пересоздания тестового состояния
и запрашивает подтверждение.

Работа идёт по TDD:

1. проверка описывает ожидаемый Kubernetes-ресурс;
2. проверка падает без ресурса;
3. добавляется минимальный Helm template;
4. выполняются lint, render и k3d smoke;
5. документация обновляется в том же коммите.

Не добавляй новый chart и новое окружение в одном пакете.
