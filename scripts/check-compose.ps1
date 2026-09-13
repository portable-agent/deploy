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
$gatewayClient = $realm.clients | Where-Object clientId -eq "mcp-gateway"
if (-not $gatewayClient -or -not $gatewayClient.bearerOnly) {
    throw "Нет resource server client mcp-gateway."
}
$actionClient = $realm.clients | Where-Object clientId -eq "action-service"
if (-not $actionClient -or -not $actionClient.serviceAccountsEnabled -or $actionClient.publicClient) {
    throw "Нет confidential service account client action-service."
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
if ($localAudiences -notcontains "agent-runtime" -or $localAudiences -notcontains "action-service" `
    -or $localAudiences -notcontains "calendar-mcp") {
    throw "Локальный JWT не получает audience agent-runtime, action-service и calendar-mcp."
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
foreach ($service in @("agent-runtime", "action-service", "mcp-gateway", "calendar-mcp")) {
    if ($composeText -notmatch "(?m)^  $([regex]::Escape($service)):") {
        throw "В Compose нет приложения $service."
    }
}
if ($composeText -notmatch '(?ms)^  agent-runtime:.*?AGENT_OIDC_AUDIENCE: agent-runtime' `
    -or $composeText -notmatch '(?ms)^  agent-runtime:.*?AGENT_DOCS_ENABLED: "false"' `
    -or $composeText -notmatch '(?ms)^  action-service:.*?MCP_GATEWAY_URL: http://mcp-gateway:8080' `
    -or $composeText -notmatch '(?ms)^  action-service:.*?OIDC_AUDIENCE: action-service' `
    -or $composeText -notmatch '(?ms)^  mcp-gateway:.*?http://calendar-mcp:8080/mcp') {
    throw "Compose не связывает Agent Runtime, Action Service, MCP Gateway и Calendar MCP."
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
if ($startScript -notmatch 'scripts/check-keycloak.ps1') {
    throw "После запуска нужна runtime-проверка Keycloak fixture."
}
if ($startScript -notmatch '\[switch\]\$Apps' -or $startScript -notmatch '"apps"') {
    throw "start-local должен уметь запускать приложения через -Apps."
}
if ($startScript -notmatch 'compose/apps.local.yaml' -or $startScript -notmatch 'up -d --build --wait') {
    throw "Локальные приложения должны собираться из соседних репозиториев."
}
$appsOverride = Get-Content -Raw -LiteralPath "compose/apps.local.yaml"
foreach ($image in @("portable-agent/agent-runtime:local", "portable-agent/action-service:local", "portable-agent/mcp-gateway:local", "portable-agent/calendar-mcp:local")) {
    if ($appsOverride -notmatch [regex]::Escape($image)) {
        throw "Local override не задаёт отдельный image tag $image."
    }
}
$keycloakCheck = Get-Content -Raw -LiteralPath "scripts/check-keycloak.ps1"
if ($keycloakCheck -notmatch 'portable-agent-realm.json' `
    -or $keycloakCheck -notmatch 'tenant_id' `
    -or $keycloakCheck -notmatch 'agent-runtime' `
    -or $keycloakCheck -notmatch 'calendar-mcp' `
    -or $keycloakCheck -notmatch 'calendar:write') {
    throw "Runtime-проверка Keycloak должна сверять JWT с realm fixture."
}
$appCheck = Get-Content -Raw -LiteralPath "scripts/check-apps.ps1"
foreach ($required in @("AGENT_RUNTIME_PORT", "/api/v1/proposals", "availableConnectors", "requiresApproval", "proposalId")) {
    if ($appCheck -notmatch [regex]::Escape($required)) {
        throw "Сквозная проверка приложений не использует Agent Runtime: нет $required."
    }
}
$versions = Get-Content -Raw -LiteralPath "config/versions.env"
if ($versions -notmatch '(?m)^AGENT_RUNTIME_IMAGE=ghcr\.io/portable-agent/agent-runtime:[0-9a-f]{40}$') {
    throw "Agent Runtime image должен быть закреплён полным Git SHA."
}
foreach ($oldName in @("utterance", "actor_id", "available_connectors", "requires_approval")) {
    if ($appCheck -match [regex]::Escape($oldName)) {
        throw "Сквозная проверка приложений содержит старое поле $oldName."
    }
}
$appWorkflowPath = ".github/workflows/app-smoke.yml"
if (-not (Test-Path -LiteralPath $appWorkflowPath)) {
    throw "Нет CI-проверки полного Compose-среза."
}
$appWorkflow = Get-Content -Raw -LiteralPath $appWorkflowPath
foreach ($required in @("versions.env", "agent-runtime", "start-local.ps1 -Apps", "check-apps.ps1", "stop-local.ps1 -DeleteData", "if: always()")) {
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

