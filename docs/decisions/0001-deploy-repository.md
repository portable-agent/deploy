# ADR-0001: отдельный deploy-репозиторий

Статус: принято.

## Контекст

Portable Agent использует polyrepo. Helm и GitOps влияют на несколько сервисов и не принадлежат одному
из них.

## Решение

Хранить общие Helm charts, локальный k3d smoke и будущие Argo CD applications в отдельной репе
`portable-agent/deploy`.

## Последствия

- сервисы остаются независимыми;
- изменения доставки получают отдельное ревью;
- совместимость image и chart должна проверяться contract/end-to-end тестами;
- production-настройки потребуют отдельных ADR и security review.
