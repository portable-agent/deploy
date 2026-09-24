$ErrorActionPreference = "Stop"
$linuxFiles = Get-ChildItem -Recurse -File -Filter "*.sh" | ForEach-Object { $_.FullName }
foreach ($file in $linuxFiles) {
    $bytes = [System.IO.File]::ReadAllBytes($file)
    if ($bytes -contains 13) {
        throw "Linux-скрипт содержит CRLF: $file"
    }
}
$realmPath = "compose/keycloak/portable-agent-realm.json"
if (-not (Test-Path -LiteralPath $realmPath)) {
    throw "Нет локального Keycloak realm: $realmPath"
}
$realm = Get-Content -Raw -LiteralPath $realmPath | ConvertFrom-Json
if ($realm.realm -ne "portable-agent" -or -not $realm.enabled) {
    throw "Keycloak realm portable-agent не включён."
}
$localClient = $realm.clients | Where-Object clientId -eq "portable-agent-local"
if (-not $localClient -or -not $localClient.directAccessGrantsEnabled) {
    throw "Нет локального OIDC client portable-agent-local."
}
$calendarClient = $realm.clients | Where-Object clientId -eq "calendar-mcp"
if (-not $calendarClient -or -not $calendarClient.bearerOnly) {
    throw "Нет resource server client calendar-mcp."
}
$agentClient = $realm.clients | Where-Object clientId -eq "agent-runtime"
if (-not $agentClient -or -not $agentClient.bearerOnly) {
    throw "Нет resource server client agent-runtime."
}
$channelClient = $realm.clients | Where-Object clientId -eq "channel-gateway"
if (-not $channelClient -or -not $channelClient.bearerOnly) {
    throw "Нет resource server client channel-gateway."
}
$gatewayClient = $realm.clients | Where-Object clientId -eq "mcp-gateway"
if (-not $gatewayClient -or -not $gatewayClient.bearerOnly) {
    throw "Нет resource server client mcp-gateway."
}
$conversationClient = $realm.clients | Where-Object clientId -eq "conversation-service"
if (-not $conversationClient -or -not $conversationClient.bearerOnly) {
    throw "Нет resource server client conversation-service."
}
$actionClient = $realm.clients | Where-Object clientId -eq "action-service"
if (-not $actionClient -or -not $actionClient.serviceAccountsEnabled -or $actionClient.publicClient) {
    throw "Нет confidential service account client action-service."
}
$telegramClient = $realm.clients | Where-Object clientId -eq "telegram-adapter"
if (-not $telegramClient -or $telegramClient.publicClient `
    -or $telegramClient.attributes.'oauth2.device.authorization.grant.enabled' -ne "true") {
    throw "Нет confidential Device Flow client telegram-adapter."
}
$telegramAudiences = @($telegramClient.protocolMappers | ForEach-Object { $_.config.'included.client.audience' })
$telegramTenantMapper = $telegramClient.protocolMappers | Where-Object { $_.config.'claim.name' -eq "tenant_id" }
if (-not $telegramTenantMapper -or $telegramAudiences -notcontains "channel-gateway" `
    -or $telegramAudiences -notcontains "conversation-service" `
    -or $telegramAudiences -notcontains "agent-runtime" `
    -or $telegramAudiences -notcontains "action-service") {
    throw "Device Flow token не содержит tenant_id и audience пользовательского пути."
}
$exampleTenant = (Get-Content -LiteralPath ".env.example" | Where-Object { $_ -match '^ACTION_SERVICE_TENANT_ID=' }).Split('=', 2)[1]
if ($exampleTenant -notmatch '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89aAbB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$') {
    throw "Локальный tenant должен быть RFC-совместимым UUID."
}
$calendarScope = $realm.clientScopes | Where-Object name -eq "calendar:write"
if (-not $calendarScope -or $localClient.defaultClientScopes -notcontains "calendar:write") {
    throw "Локальный JWT не получает scope calendar:write."
}
$gatewayScope = $realm.clientScopes | Where-Object name -eq "mcp:call"
if (-not $gatewayScope -or $actionClient.defaultClientScopes -notcontains "mcp:call" `
    -or $actionClient.defaultClientScopes -notcontains "calendar:write") {
    throw "Service token action-service не получает нужные scopes."
}
$localAudiences = @($localClient.protocolMappers | ForEach-Object { $_.config.'included.client.audience' })
if ($localAudiences -notcontains "channel-gateway" -or $localAudiences -notcontains "agent-runtime" `
    -or $localAudiences -notcontains "action-service" `
    -or $localAudiences -notcontains "conversation-service" `
    -or $localAudiences -notcontains "calendar-mcp") {
    throw "Локальный JWT не получает audience всех пользовательских сервисов."
}
$tenantMapper = $localClient.protocolMappers | Where-Object { $_.config.'claim.name' -eq "tenant_id" }
if (-not $tenantMapper) {
    throw "Локальный JWT не содержит tenant_id mapper."
}
$actionTenantMapper = $actionClient.protocolMappers | Where-Object { $_.config.'claim.name' -eq "tenant_id" }
$actionAudiences = @($actionClient.protocolMappers | ForEach-Object { $_.config.'included.client.audience' })
if (-not $actionTenantMapper -or $actionAudiences -notcontains "mcp-gateway" `
    -or $actionAudiences -notcontains "calendar-mcp") {
    throw "Service token action-service не содержит tenant_id и обе audience."
}
$localUser = $realm.users | Where-Object username -eq "local-user"
if (-not $localUser.email -or -not $localUser.emailVerified) {
    throw "Профиль local-user не готов для входа."
}
$composeText = Get-Content -Raw -LiteralPath "compose/compose.yaml"
if ($composeText -notmatch '(?ms)^  keycloak:.*?^    healthcheck:') {
    throw "У Keycloak нет readiness healthcheck."
}
foreach ($service in @("channel-gateway", "agent-runtime", "action-service", "conversation-service", "mcp-gateway", "calendar-mcp")) {
    if ($composeText -notmatch "(?m)^  $([regex]::Escape($service)):") {
        throw "В Compose нет приложения $service."
    }
}
foreach ($service in @("telegram-adapter", "fake-telegram")) {
    if ($composeText -notmatch "(?m)^  $([regex]::Escape($service)):") {
        throw "В Compose нет Telegram-компонента $service."
    }
}
if ($composeText -notmatch '(?ms)^  telegram-adapter:.*?TELEGRAM_API_URL: http://fake-telegram:8080' `
    -or $composeText -notmatch '(?ms)^  telegram-adapter:.*?CHANNEL_GATEWAY_URL: http://channel-gateway:8080' `
    -or $composeText -notmatch '(?ms)^  telegram-adapter:.*?DATABASE_URL: postgres://.*@postgres:5432/telegram_adapter' `
    -or $composeText -notmatch '(?ms)^  telegram-adapter:.*?^    healthcheck:') {
    throw "Compose не связывает Telegram Adapter с локальными зависимостями."
}
$telegramMappingPath = "compose/telegram/mappings/bot-api.json"
if (-not (Test-Path -LiteralPath $telegramMappingPath)) {
    throw "Нет безопасной заглушки Telegram Bot API."
}
$telegramMapping = Get-Content -Raw -LiteralPath $telegramMappingPath | ConvertFrom-Json
if ($telegramMapping.request.method -ne "POST" `
    -or $telegramMapping.request.urlPathPattern -notmatch 'sendMessage' `
    -or $telegramMapping.request.urlPathPattern -notmatch 'answerCallbackQuery') {
    throw "Fake Telegram API не поддерживает ответы адаптера."
}
if ($composeText -notmatch '(?ms)^  channel-gateway:.*?OIDC_AUDIENCE: channel-gateway' `
    -or $composeText -notmatch '(?ms)^  channel-gateway:.*?AGENT_URL: http://agent-runtime:8080' `
    -or $composeText -notmatch '(?ms)^  channel-gateway:.*?CONVERSATION_URL: http://conversation-service:8080' `
    -or $composeText -notmatch '(?ms)^  channel-gateway:.*?CONVERSATION_TIMEOUT_MS: 10000' `
    -or $composeText -notmatch '(?ms)^  channel-gateway:.*?ACTION_URL: http://action-service:8080' `
    -or $composeText -notmatch '(?ms)^  channel-gateway:.*?ACTION_TIMEOUT_MS: 10000' `
    -or $composeText -notmatch '(?ms)^  channel-gateway:.*?^    depends_on:.*?^      conversation-service:\s*\r?\n        condition: service_healthy' `
    -or $composeText -notmatch '(?ms)^  channel-gateway:.*?^    depends_on:.*?^      action-service:\s*\r?\n        condition: service_healthy' `
    -or $composeText -notmatch '(?ms)^  agent-runtime:.*?AGENT_OIDC_AUDIENCE: agent-runtime' `
    -or $composeText -notmatch '(?ms)^  agent-runtime:.*?AGENT_DOCS_ENABLED: "false"' `
    -or $composeText -notmatch '(?ms)^  action-service:.*?MCP_GATEWAY_URL: http://mcp-gateway:8080' `
    -or $composeText -notmatch '(?ms)^  action-service:.*?OIDC_AUDIENCE: action-service' `
    -or $composeText -notmatch '(?ms)^  conversation-service:.*?OIDC_AUDIENCE: conversation-service' `
    -or $composeText -notmatch '(?ms)^  conversation-service:.*?AGENT_URL: http://agent-runtime:8080' `
    -or $composeText -notmatch '(?ms)^  conversation-service:.*?ACTION_URL: http://action-service:8080' `
    -or $composeText -notmatch '(?ms)^  conversation-service:.*?DB_URL: jdbc:postgresql://postgres:5432/conversations' `
    -or $composeText -notmatch '(?ms)^  conversation-service:.*?^    healthcheck:' `
    -or $composeText -notmatch '(?ms)^  mcp-gateway:.*?http://calendar-mcp:8080/mcp') {
    throw "Compose не связывает Channel Gateway, Conversation Service, Agent Runtime и Action Service."
}
if ($composeText -notmatch 'TEMPORAL_ADMIN_ADDRESS:-temporal:7233') {
    throw "Portable Compose должен обращаться к Temporal по имени сервиса."
}
$windowsOverride = Get-Content -Raw -LiteralPath "compose/windows.local.yaml"
if ($windowsOverride -notmatch 'host.docker.internal:\$\{TEMPORAL_PORT:-7233\}' `
    -or $windowsOverride -notmatch 'host.docker.internal:host-gateway') {
    throw "Windows override должен обращаться к опубликованному Temporal port."
}
$startScript = Get-Content -Raw -LiteralPath "scripts/start-local.ps1"
if ($startScript -notmatch 'scale temporal-namespace=0' -or $startScript -notmatch 'run --rm --no-deps temporal-namespace') {
    throw "Temporal namespace должен запускаться отдельно от compose --wait."
}
if ($startScript -notmatch 'run --rm postgres-bootstrap') {
    throw "PostgreSQL bootstrap должен выполняться и для существующего volume."
}
$postgresBootstrap = Get-Content -Raw -LiteralPath "compose/postgres/bootstrap.sh"
if ($postgresBootstrap -notmatch 'exec /bin/sh /scripts/init/01-users\.sh') {
    throw "PostgreSQL init должен запускаться через shell и не зависеть от executable bit."
}
$postgresInit = Get-Content -Raw -LiteralPath "compose/postgres/init/01-users.sh"
if ($postgresInit -notmatch 'CONVERSATION_DB_USER' `
    -or $postgresInit -notmatch 'CONVERSATION_DB_PASSWORD' `
    -or $postgresInit -notmatch 'CREATE DATABASE conversations' `
    -or $postgresInit -notmatch 'TELEGRAM_DB_USER' `
    -or $postgresInit -notmatch 'CREATE DATABASE telegram_adapter') {
    throw "PostgreSQL bootstrap не создаёт отдельные БД приложений."
}
if ($startScript -notmatch 'scripts/check-keycloak.ps1') {
    throw "После запуска нужна runtime-проверка Keycloak fixture."
}
if ($startScript -notmatch '\[switch\]\$Apps' -or $startScript -notmatch '"apps"') {
    throw "start-local должен уметь запускать приложения через -Apps."
}
if ($startScript -notmatch 'compose/apps.local.yaml' -or $startScript -notmatch 'up -d --build --wait') {
    throw "Локальные приложения должны собираться из соседних репозиториев."
}
$localSettings = Get-Content -Raw -LiteralPath "scripts/local-settings.ps1"
if ($localSettings -notmatch 'SHA256' -or $localSettings -notmatch 'TELEGRAM_TOKEN_KEY_BASE64' `
    -or $localSettings -notmatch 'TELEGRAM_WEBHOOK_SECRET') {
    throw "Локальный encryption key Telegram Adapter должен создаваться вне Git."
}
$taskfilePath = "Taskfile.yml"
if (-not (Test-Path -LiteralPath $taskfilePath)) {
    throw "Нет единой точки входа Taskfile.yml для локальной разработки."
}
$taskfile = Get-Content -Raw -LiteralPath $taskfilePath
foreach ($taskName in @(
    "infra:up",
    "services:up",
    "service:up",
    "service:stop",
    "service:restart",
    "service:logs",
    "doctor",
    "status",
    "test:e2e",
    "down",
    "reset"
)) {
    if ($taskfile -notmatch "(?m)^  $([regex]::Escape($taskName)):") {
        throw "В Taskfile нет команды $taskName."
    }
}
if ($taskfile -notmatch 'scripts/start-local\.ps1' `
    -or $taskfile -notmatch 'scripts/service-local\.ps1' `
    -or $taskfile -notmatch 'scripts/run-test-lab\.ps1' `
    -or $taskfile -notmatch '(?m)^    prompt:') {
    throw "Taskfile не связывает команды запуска, управления, E2E и безопасного reset."
}
if ($startScript -notmatch '\[string\]\$Service' -or $startScript -notmatch '\$Service') {
    throw "start-local должен уметь запускать один выбранный сервис."
}
$serviceScriptPath = "scripts/service-local.ps1"
if (-not (Test-Path -LiteralPath $serviceScriptPath)) {
    throw "Нет безопасного управления отдельным локальным сервисом."
}
$serviceScript = Get-Content -Raw -LiteralPath $serviceScriptPath
foreach ($action in @("Status", "Stop", "Restart", "Logs")) {
    if ($serviceScript -notmatch [regex]::Escape('"' + $action + '"')) {
        throw "service-local не поддерживает команду $action."
    }
}
$appsOverride = Get-Content -Raw -LiteralPath "compose/apps.local.yaml"
foreach ($image in @("portable-agent/channel-gateway:local", "portable-agent/agent-runtime:local", "portable-agent/action-service:local", "portable-agent/conversation-service:local", "portable-agent/mcp-gateway:local", "portable-agent/calendar-mcp:local", "portable-agent/telegram-adapter:local")) {
    if ($appsOverride -notmatch [regex]::Escape($image)) {
        throw "Local override не задаёт отдельный image tag $image."
    }
}
$keycloakCheck = Get-Content -Raw -LiteralPath "scripts/check-keycloak.ps1"
if ($keycloakCheck -notmatch 'portable-agent-realm.json' `
    -or $keycloakCheck -notmatch 'tenant_id' `
    -or $keycloakCheck -notmatch 'channel-gateway' `
    -or $keycloakCheck -notmatch 'agent-runtime' `
    -or $keycloakCheck -notmatch 'conversation-service' `
    -or $keycloakCheck -notmatch 'calendar-mcp' `
    -or $keycloakCheck -notmatch 'calendar:write') {
    throw "Runtime-проверка Keycloak должна сверять JWT с realm fixture."
}
$testLabRunnerPath = "scripts/run-test-lab.ps1"
if (-not (Test-Path -LiteralPath $testLabRunnerPath)) {
    throw "Нет адаптера запуска сценариев из test-lab."
}
if (Test-Path -LiteralPath "scripts/check-apps.ps1") {
    throw "Продуктовый E2E не должен дублироваться в deploy."
}
$testLabRunner = Get-Content -Raw -LiteralPath $testLabRunnerPath
if ($testLabRunner -notmatch '\$containerIds\s*=\s*@\(\s*\r?\n\s*\(& docker ps') {
    throw "Результат docker ps должен сохраняться массивом до обращения по индексу."
}
foreach ($required in @("TEST_LAB_PATH", "portable-agent-realm.json", "CALENDAR_TEST_API_KEY", "DOCKER_NETWORK", "docker inspect", "com.docker.compose.service=channel-gateway", "http://channel-gateway:8080", "http://action-service:8080", "http://calendar-mcp:8080", "task", "test:e2e")) {
    if ($testLabRunner -notmatch [regex]::Escape($required)) {
        throw "Адаптер test-lab не содержит $required."
    }
}
$versions = Get-Content -Raw -LiteralPath "config/versions.env"
if ($versions -notmatch '(?m)^AGENT_RUNTIME_IMAGE=ghcr\.io/portable-agent/agent-runtime:[0-9a-f]{40}\r?$') {
    throw "Agent Runtime image должен быть закреплён полным Git SHA."
}
if ($versions -notmatch '(?m)^CHANNEL_GATEWAY_IMAGE=ghcr\.io/portable-agent/channel-gateway:[0-9a-f]{40}\r?$') {
    throw "Channel Gateway image должен быть закреплён полным Git SHA."
}
if ($versions -notmatch '(?m)^TELEGRAM_ADAPTER_IMAGE=ghcr\.io/portable-agent/telegram-adapter:[0-9a-f]{40}\r?$') {
    throw "Telegram Adapter image должен быть закреплён полным Git SHA."
}
if ($versions -notmatch '(?m)^TEST_LAB_REF=[0-9a-f]{40}\r?$') {
    throw "Test Lab должен быть закреплён полным Git SHA."
}
$appWorkflowPath = ".github/workflows/app-smoke.yml"
if (-not (Test-Path -LiteralPath $appWorkflowPath)) {
    throw "Нет CI-проверки полного Compose-среза."
}
$appWorkflow = Get-Content -Raw -LiteralPath $appWorkflowPath
foreach ($required in @("versions.env", "channel-gateway", "agent-runtime", "CONVERSATION_SERVICE_CONTEXT", "repository: portable-agent/conversation-service", 'ref: ${{ steps.versions.outputs.conversation }}', "TELEGRAM_ADAPTER_CONTEXT", "repository: portable-agent/telegram-adapter", 'ref: ${{ steps.versions.outputs.telegram }}', "repository: portable-agent/test-lab", 'ref: ${{ steps.versions.outputs.test_lab }}', "start-local.ps1 -Apps", "run-test-lab.ps1", "stop-local.ps1 -DeleteData", "if: always()")) {
    if ($appWorkflow -notmatch [regex]::Escape($required)) {
        throw "CI-проверка полного среза не содержит $required."
    }
}
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    throw "Docker не найден. Запусти проверку в CI или установи Docker Desktop."
}
& docker compose --env-file .env.example --env-file config/versions.env -f compose/compose.yaml `
    -f compose/apps.local.yaml --profile core --profile observe --profile apps config --quiet
if ($LASTEXITCODE -ne 0) { throw "Compose config содержит ошибку." }
Write-Host "Compose config прошёл проверку."

