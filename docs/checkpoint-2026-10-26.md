# Точка продолжения: Google Calendar через Telegram

Дата проверки: 26 октября 2026 года, часовой пояс `Europe/Moscow`.

## Проверенный результат

1. В отдельном Google Cloud проекте Portable Agent включён Calendar API. OAuth-приложение
   `Portable Agent Local` работает в режиме Testing с одним тестовым пользователем.
2. Web OAuth client использует redirect URI
   `http://localhost:18088/api/v1/connections/callback`. Client ID и Client Secret находятся
   только в игнорируемом `portable-agent-deploy/.env`. В Git и в этом документе секретов нет.
3. Локальный `connection-service` получил Google OAuth-доступ. `channel-gateway` и
   `conversation-service` в режиме настоящего Telegram предлагают `google-calendar`.
4. Через настоящий Telegram были отправлены команда и подтверждение встречи
   «Portable Agent E2E Google» на 27 октября 2026 года, 17:00–17:30 МСК.
   В `action-service` действие стало `SUCCEEDED`. Отдельный GET к Google Calendar API подтвердил
   событие со статусом `confirmed`. Диагностические встречи удалены.

Временный Cloudflare Quick Tunnel отвечал локально, но Telegram отверг его новый hostname с
`Failed to resolve host`. Для проверки входящие обновления получали официальным Telegram
`getUpdates` после `deleteWebhook` и передавали в локальный
`http://localhost:18086/webhooks/telegram` с тем же секретным заголовком. Сейчас webhook удалён:
бот не обрабатывает новые сообщения автоматически, пока не заработает туннель или локальный
polling mode. Это ограничение тестового транспорта; реальный Google API и остальная цепочка
проверены.

## Pull requests

| Репозиторий | PR | Суть |
| --- | --- | --- |
| `calendar-mcp` | [#23](https://github.com/portable-agent/calendar-mcp/pull/23) | RFC3339-время с секундами для Google API и регрессионный тест |
| `agent-runtime` | [#22](https://github.com/portable-agent/agent-runtime/pull/22) | Понятные уточнения вместо ложного `AGENT_UNAVAILABLE` |
| `conversation-service` | [#13](https://github.com/portable-agent/conversation-service/pull/13) | Новый разговор после закрытой сессии |
| `telegram-adapter` | [#5](https://github.com/portable-agent/telegram-adapter/pull/5) | `/start` без привязки и обновление уязвимой зависимости |
| `deploy` | [#25](https://github.com/portable-agent/deploy/pull/25) | Реальный маршрут Google, команды переключения и лимит соединений PostgreSQL |

Смотри актуальные GitHub checks в PR: их состояние меняется после каждого push. Локальные проверки
Java, Python, Node и Compose проходили перед публикацией. Pull requests оставлены открытыми
для ревью.

## Что делать дальше

1. Довести CI всех пяти PR до зелёного состояния и выполнить ревью.
2. После мержа обновить локальные `main` и версии образов в `deploy/config/versions.env`,
   если менялись публикуемые образы.
3. Сделать официальный локальный polling mode Telegram Adapter или стабильный туннель,
   чтобы реальная проверка не требовала ручной передачи обновлений.
4. После выполнения Action отправлять в чат итог «встреча создана» либо понятную ошибку:
   сейчас `answerCallbackQuery` показывает только краткий ответ на нажатие кнопки.
5. Повторить end-to-end проверку из чистого локального запуска и занести её в test-lab.

Не добавляй OAuth credentials, access/refresh tokens, Telegram bot token или полные HTTP-ответы
Google в Git и логи.
