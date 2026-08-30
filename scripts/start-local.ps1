param([switch]$Observe)
$ErrorActionPreference = "Stop"
$envFiles = @("--env-file", ".env.example", "--env-file", "config/versions.env")
if (Test-Path .env) { $envFiles += @("--env-file", ".env") }
$profiles = @("--profile", "core")
if ($Observe) { $profiles += @("--profile", "observe") }
& docker compose @envFiles -f compose/compose.yaml @profiles up -d --wait
if ($LASTEXITCODE -ne 0) { throw "Локальная инфраструктура не запустилась." }
Write-Host "Локальная инфраструктура готова. Для остановки: pwsh ./scripts/stop-local.ps1"
