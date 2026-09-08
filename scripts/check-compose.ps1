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
$calendarScope = $realm.clientScopes | Where-Object name -eq "calendar:write"
if (-not $calendarScope -or $localClient.defaultClientScopes -notcontains "calendar:write") {
    throw "Локальный JWT не получает scope calendar:write."
}
$audienceMapper = $localClient.protocolMappers | Where-Object { $_.config.'included.client.audience' -eq "calendar-mcp" }
if (-not $audienceMapper) {
    throw "Локальный JWT не получает audience calendar-mcp."
}
$tenantMapper = $localClient.protocolMappers | Where-Object { $_.config.'claim.name' -eq "tenant_id" }
if (-not $tenantMapper) {
    throw "Локальный JWT не содержит tenant_id mapper."
}
$localUser = $realm.users | Where-Object username -eq "local-user"
if (-not $localUser.email -or -not $localUser.emailVerified) {
    throw "Профиль local-user не готов для входа."
}
$composeText = Get-Content -Raw -LiteralPath "compose/compose.yaml"
if ($composeText -notmatch '(?ms)^  keycloak:.*?^    healthcheck:') {
    throw "У Keycloak нет readiness healthcheck."
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
$keycloakCheck = Get-Content -Raw -LiteralPath "scripts/check-keycloak.ps1"
if ($keycloakCheck -notmatch 'portable-agent-realm.json' `
    -or $keycloakCheck -notmatch 'tenant_id' `
    -or $keycloakCheck -notmatch 'calendar-mcp' `
    -or $keycloakCheck -notmatch 'calendar:write') {
    throw "Runtime-проверка Keycloak должна сверять JWT с realm fixture."
}
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    throw "Docker не найден. Запусти проверку в CI или установи Docker Desktop."
}
& docker compose --env-file .env.example --env-file config/versions.env -f compose/compose.yaml --profile core --profile observe config --quiet
if ($LASTEXITCODE -ne 0) { throw "Compose config содержит ошибку." }
Write-Host "Compose config прошёл проверку."

