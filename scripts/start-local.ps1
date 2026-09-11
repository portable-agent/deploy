param([switch]$Observe, [switch]$Apps)
$ErrorActionPreference = "Stop"
$envFiles = @("--env-file", ".env.example", "--env-file", "config/versions.env")
if (Test-Path .env) { $envFiles += @("--env-file", ".env") }
$composeFiles = @("-f", "compose/compose.yaml")
if ($IsWindows) { $composeFiles += @("-f", "compose/windows.local.yaml") }
function Get-LocalSetting([string]$Name) {
    $value = [Environment]::GetEnvironmentVariable($Name)
    foreach ($path in @(".env", ".env.example")) {
        if ($value -or -not (Test-Path -LiteralPath $path)) { continue }
        $line = Get-Content -LiteralPath $path | Where-Object { $_ -match "^$([regex]::Escape($Name))=" } | Select-Object -Last 1
        if ($line) { $value = $line.Substring($line.IndexOf('=') + 1) }
    }
    if (-not $value) { throw "Не задан $Name." }
    return $value
}
$coreProfiles = @("--profile", "core")
if ($Observe) { $coreProfiles += @("--profile", "observe") }
& docker compose @envFiles @composeFiles @coreProfiles run --rm postgres-bootstrap
if ($LASTEXITCODE -ne 0) { throw "Не удалось подготовить PostgreSQL databases и users." }
& docker compose @envFiles @composeFiles @coreProfiles up -d --wait --scale temporal-namespace=0
if ($LASTEXITCODE -ne 0) { throw "Локальная инфраструктура не запустилась." }
& docker compose @envFiles @composeFiles @coreProfiles run --rm --no-deps temporal-namespace
if ($LASTEXITCODE -ne 0) { throw "Не удалось подготовить Temporal namespace." }
$keycloakAddress = & docker compose @envFiles @composeFiles port keycloak 8080
if ($LASTEXITCODE -ne 0 -or -not $keycloakAddress) { throw "Не удалось определить адрес Keycloak." }
$keycloakPort = $keycloakAddress.Trim().Split(':')[-1]
$serviceSecret = Get-LocalSetting "ACTION_SERVICE_CLIENT_SECRET"
$tenantId = Get-LocalSetting "ACTION_SERVICE_TENANT_ID"
if ($tenantId -notmatch '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89aAbB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$') {
    throw "ACTION_SERVICE_TENANT_ID должен быть RFC-совместимым UUID."
}
& ./scripts/check-keycloak.ps1 `
    -BaseUrl "http://localhost:$keycloakPort" `
    -ServiceSecret $serviceSecret `
    -ExpectedTenant $tenantId
if ($LASTEXITCODE -ne 0) { throw "Локальный Keycloak не прошёл runtime-проверку." }
if ($Apps) {
    $appProfiles = @($coreProfiles + @("--profile", "apps"))
    & docker compose @envFiles @composeFiles -f compose/apps.local.yaml `
        @appProfiles up -d --build --wait --scale temporal-namespace=0
    if ($LASTEXITCODE -ne 0) { throw "Приложения локального среза не запустились." }
}
Write-Host "Локальная инфраструктура готова. Для остановки: pwsh ./scripts/stop-local.ps1"
