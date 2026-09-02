param([switch]$Observe)
$ErrorActionPreference = "Stop"
$envFiles = @("--env-file", ".env.example", "--env-file", "config/versions.env")
if (Test-Path .env) { $envFiles += @("--env-file", ".env") }
$profiles = @("--profile", "core")
if ($Observe) { $profiles += @("--profile", "observe") }
& docker compose @envFiles -f compose/compose.yaml @profiles run --rm postgres-bootstrap
if ($LASTEXITCODE -ne 0) { throw "Не удалось подготовить PostgreSQL databases и users." }
& docker compose @envFiles -f compose/compose.yaml @profiles up -d --wait --scale temporal-namespace=0
if ($LASTEXITCODE -ne 0) { throw "Локальная инфраструктура не запустилась." }
& docker compose @envFiles -f compose/compose.yaml @profiles run --rm --no-deps temporal-namespace
if ($LASTEXITCODE -ne 0) { throw "Не удалось подготовить Temporal namespace." }
Write-Host "Локальная инфраструктура готова. Для остановки: pwsh ./scripts/stop-local.ps1"
